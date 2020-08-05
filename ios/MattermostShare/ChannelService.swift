//
//  ChannelService.swift
//  MattermostShare
//
//  Created by Bruno Serrano dos Santos on 08/07/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

import UIKit

class ChannelService: NSObject {
  var serverURL: String?
  var sessionToken: String?
  
  var isSessionValid: Bool {
    get {
      return serverURL != nil && sessionToken != nil
    }
  }
  
  func getTeamChannels(forTeamId: String, completionHandler: @escaping ([NSArray.Element]) -> Void) {
    let urlString = "\(serverURL!)/api/v4/users/me/teams/\(forTeamId)/channels"
    let url = URL(string: urlString)
    var request = URLRequest(url: url!)
    let auth = "Bearer \(sessionToken!)" as String
    request.setValue(auth, forHTTPHeaderField: "Authorization")
    
    ChannelService.requestChannels(with: request, completionHandler: completionHandler)
  }
  
  func searchChannels(on teamId: String, withTerm term: String, completionHandler: @escaping ([NSArray.Element]) -> Void) {
    let json: [String: Any] = ["term": term]
    let jsonData = try? JSONSerialization.data(withJSONObject: json)
    
    let urlString = "\(serverURL!)/api/v4/teams/\(teamId)/channels/search"
    let url = URL(string: urlString)
    var request = URLRequest(url: url!)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    
    let auth = "Bearer \(sessionToken!)" as String
    request.setValue(auth, forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    ChannelService.requestChannels(with: request, completionHandler: completionHandler)
  }
  
  static func requestChannels(with request: URLRequest, completionHandler: @escaping ([NSArray.Element]) -> Void) {
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let dataResponse = data,
        error == nil else {
          print(error?.localizedDescription ?? "Response Error")
          return
      }
      
      do {
        let jsonArray = try JSONSerialization.jsonObject(with: dataResponse, options: []) as! NSArray
        let channels = jsonArray.filter {element in
          let channel = element as! NSDictionary
          let type = channel.object(forKey: "type") as! String
          return type == "O" || type == "P"
        }
        
        completionHandler(channels)
      }
      catch let parsingError {
        print("Error", parsingError)
      }
    }
    task.resume()
  }
  
  func searchUsers(withTerm term: String, completionHandler: @escaping ([NSArray.Element]) -> Void) {
    let json: [String: Any] = ["term": term]
    let jsonData = try? JSONSerialization.data(withJSONObject: json)
    
    let urlString = "\(serverURL!)/api/v4/users/search"
    let url = URL(string: urlString)
    var request = URLRequest(url: url!)
    request.httpMethod = "POST"
    request.httpBody = jsonData
    
    let auth = "Bearer \(sessionToken!)" as String
    request.setValue(auth, forHTTPHeaderField: "Authorization")
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("application/json", forHTTPHeaderField: "Accept")
    
    requestUsers(with: request, completionHandler: completionHandler)
  }
  
  func requestUsers(with request: URLRequest, completionHandler: @escaping ([NSArray.Element]) -> Void) {
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
      guard let dataResponse = data,
        error == nil else {
          print(error?.localizedDescription ?? "Response Error")
          return
      }
      
      do {
        let jsonArray = try JSONSerialization.jsonObject(with: dataResponse, options: []) as! NSArray
        let users = jsonArray.filter {element in
          return true
        }
        
        completionHandler(users)
      }
      catch let parsingError {
        print("Error", parsingError)
      }
    }
    task.resume()
  }
}
