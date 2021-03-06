import UIKit

class ChannelsViewController: UIViewController {

  let searchController = UISearchController(searchResultsController: nil)
  
  lazy var tableView: UITableView = {
    let tableView = UITableView(frame: self.view.frame)
    tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tableView.dataSource = self
    tableView.delegate = self
    tableView.backgroundColor = .clear
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: Identifiers.ChannelCell)
    
    return tableView
  }()
  
  var navbarTitle: String? = "Channels"
  var channelDecks = [Section]()
  var filteredDecks: [Section]?
  var foundItems = Section()
  var teamId: String?
  private var sessionToken: String?
  private var serverURL: String?
  private var store = StoreManager.shared() as StoreManager
  weak var delegate: ChannelsViewControllerDelegate?

  var footerFrame = UIView()
  var footerLabel = UILabel()
  var indicator = UIActivityIndicatorView()
  var dispatchGroup = DispatchGroup()
  var indicatorShown = false
  private var channelService = ChannelService()
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if #available(iOS 11.0, *) {
      navigationItem.hidesSearchBarWhenScrolling = false
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    if #available(iOS 11.0, *) {
      navigationItem.hidesSearchBarWhenScrolling = true
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    filteredDecks = channelDecks
    title = navbarTitle
    configureSearchBar()
    view.addSubview(tableView)
    
    sessionToken = store.getToken()
    serverURL = store.getServerUrl()
    
    channelService.serverURL = serverURL
    channelService.sessionToken = sessionToken
  }
 
  func configureSearchBar() {
    searchController.searchResultsUpdater = self
    searchController.hidesNavigationBarDuringPresentation = false
    searchController.dimsBackgroundDuringPresentation = false
    searchController.searchBar.searchBarStyle = .minimal
    searchController.searchBar.autocapitalizationType = .none
    searchController.searchBar.delegate = self

    self.definesPresentationContext = true
    
    if #available(iOS 11.0, *) {
      // For iOS 11 and later, place the search bar in the navigation bar.
      
      // Give space at the top so provide a better look and feel
      let offset = UIOffset(horizontal: 0.0, vertical: 6.0)
      searchController.searchBar.searchFieldBackgroundPositionAdjustment = offset
      
      
      navigationItem.searchController = searchController
    } else {
      // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
      tableView.tableHeaderView = searchController.searchBar
    }
  }
  
  func showActivityIndicator() {
    footerFrame = UIView(frame: CGRect(x: 0, y: view.frame.midY - 25, width: 250, height: 50))
    footerFrame.center.x = view.center.x

    footerLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    footerLabel.textColor = UIColor.systemGray
    footerLabel.text = "Searching for Channels..."

    indicator.frame = CGRect(x: 200, y: 0, width: 50, height: 50)
    indicator.startAnimating()

    footerFrame.addSubview(footerLabel)
    footerFrame.addSubview(indicator)

    tableView.tableFooterView = footerFrame
    indicatorShown = true
  }

  func hideActivityIndicator() {
    tableView.tableFooterView = nil
    indicatorShown = false
    self.tableView.reloadData()
  }

  func leaveDispatchGroup() {
    dispatchGroup.leave()
  }
  
  var foundChannels : [String: NSDictionary]?
  var foundUsers : [String: NSDictionary]?
  
  func finishSearch() {
    self.dispatchGroup.notify(queue: .main) {
      
      var allFoundChannels = [String: NSDictionary]()
      
      if let foundUsers = self.foundUsers {
        for (k, v) in foundUsers {
          allFoundChannels[k] = v
        }
      }
      
      if let foundChannels = self.foundChannels {
        for (k, v) in foundChannels {
          allFoundChannels[k] = v
        }
      }
      
      if let channelsInTeamBySections = self.store.getSectionsWithChannels(allFoundChannels, excludeArchived: true, forTeamId: self.teamId) {

        var channelDecks = [Section]()
        
        channelDecks.append(Section.buildChannelSection(
          channels: channelsInTeamBySections["public"] as? NSArray ?? NSArray(),
          currentChannelId: "",
          key: "public",
          title: "Public Channels",
          selectedChannelHandler: nil
        ))

        channelDecks.append(Section.buildChannelSection(
          channels: channelsInTeamBySections["private"] as? NSArray ?? NSArray(),
          currentChannelId: "",
          key: "private",
          title: "Private Channels",
          selectedChannelHandler: nil
        ))

        channelDecks.append(Section.buildChannelSection(
          channels: channelsInTeamBySections["direct"] as? NSArray ?? NSArray(),
          currentChannelId: "",
          key: "direct",
          title: "Direct Channels",
          selectedChannelHandler: nil
        ))
        
        self.filteredDecks = channelDecks
      }
      
      self.hideActivityIndicator()
      self.tableView.reloadData()
    }
    
    self.dispatchGroup.leave()
  }
  
  func searchChannels(forTeamId: String, term: String) {
    dispatchGroup.enter()
    showActivityIndicator()
    
    channelService.searchUsers(withTerm: term) { users in
      self.foundUsers = (users as! [NSDictionary]).reduce(into: [String: NSDictionary](), { (a0, a1) in
        a0[a1.object(forKey: "id") as! String] = [
          "id" : a1.object(forKey: "id")!,
          "display_name": "\(a1.object(forKey: "first_name") ?? "") \(a1.object(forKey: "last_name") ?? "")",
          "type": "D",
          "delete_at": a1.object(forKey: "delete_at") ?? 0,
          "name": a1.object(forKey: "username") ?? ""
        ]
      })
      self.finishSearch()
    }
    
    channelService.searchChannels(on: forTeamId, withTerm: term) { channels in
      self.foundChannels = (channels as! [NSDictionary]).reduce(into: [String: NSDictionary]()) {
        $0[$1.object(forKey: "id") as! String] = $1
      }
      self.finishSearch()
    }
  }
  
}

private extension ChannelsViewController {
  struct Identifiers {
    static let ChannelCell = "channelCell"
  }
}

extension ChannelsViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return filteredDecks?.count ?? 0
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let sec = filteredDecks?[section]
    if (sec?.items.count)! > 0 {
      return sec?.title
    }
    
    return nil
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return filteredDecks?[section].items.count ?? 0
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let section = filteredDecks?[indexPath.section]
    let cell = tableView.dequeueReusableCell(withIdentifier: Identifiers.ChannelCell, for: indexPath)
    let item = section?.items[indexPath.row]
    cell.textLabel?.text = item?.title
    if item?.selected ?? false {
      cell.accessoryType = .checkmark
    } else {
      cell.accessoryType = .none
    }
    cell.backgroundColor = .clear
    return cell
  }
}

protocol ChannelsViewControllerDelegate: class {
  func selectedChannel(deck: Item)
}

extension ChannelsViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let section = filteredDecks?[indexPath.section]
    if (section?.items != nil) {
      delegate?.selectedChannel(deck: (section?.items[indexPath.row])!)
    }
  }
}

extension ChannelsViewController: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    if let searchText = searchController.searchBar.text, !searchText.isEmpty {
      self.filteredDecks = self.channelDecks.map {section in
        let s = section.copy() as! Section
        let items = section.items.filter{($0.title?.lowercased().contains(searchText.lowercased()))!}
        s.items = items
        return s
      }
      
      if let teamId = self.teamId {
        searchChannels(forTeamId: teamId, term: searchText)
      }
    } else {
      filteredDecks = channelDecks
    }
    
    tableView.reloadData()
  }
}

extension ChannelsViewController: UISearchBarDelegate {
  func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
    searchBar.showsCancelButton = false
    searchBar.text = ""
    searchBar.resignFirstResponder()
    tableView.reloadData()
  }
  
  func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
    searchBar.showsCancelButton = true
    
    // Center the Cancel Button
    if #available(iOS 11.0, *) {
      searchBar.cancelButton?.titleEdgeInsets = UIEdgeInsets(top: 12.0, left: 0, bottom: 0, right: 0)
    }
  }
}

// get the cancel button of the Search Bar
extension UISearchBar {
  var cancelButton : UIButton? {
    let topView: UIView = self.subviews[0] as UIView
    
    if let pvtClass = NSClassFromString("UINavigationButton") {
      for v in topView.subviews {
        if v.isKind(of: pvtClass) {
          return v as? UIButton
        }
      }
    }
    
    return nil
  }
}
