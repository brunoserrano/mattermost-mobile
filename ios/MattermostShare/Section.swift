import Foundation

class Section: NSObject, NSCopying {
  var title: String?
  var items: [Item] = []
  
  func copy(with zone: NSZone? = nil) -> Any {
    let copy = Section()
    copy.title = title
    copy.items = items
    return copy
  }
  
  public static func buildChannelSection(channels: NSArray, currentChannelId: String, key: String, title:String, selectedChannelHandler: ((Item) -> Void)?) -> Section {
    let section = Section()
    section.title = title
    for channel in channels as! [NSDictionary] {
      let item = Item()
      let id = channel.object(forKey: "id") as? String
      item.id = id
      item.title = channel.object(forKey: "display_name") as? String
      if id == currentChannelId {
        item.selected = true
        
        selectedChannelHandler?(item)
      }
      section.items.append(item)
    }
    return section
  }
}
