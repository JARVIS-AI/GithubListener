//
//  AppDelegate.swift
//  GitHubListener
//
//  Created by Daniel Apatin on 24.04.2018.
//  Copyright © 2018 Daniel Apatin. All rights reserved.
//

import Cocoa
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate {
    var statusItem : NSStatusItem!
    let defaults = UserDefaults.standard
    
    var nc: NSUserNotificationCenter!
    var repos = [Repo]()
    
    let username = "ad"
    
    private var timer: Timer!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let statusItem : NSStatusItem = {
            let item =  NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.title = "GHL"
            self.statusItem = item
            return item
        }()
        createMenu()
        
        self.nc = NSUserNotificationCenter.default
        nc.delegate = self
        
        nc.removeAllDeliveredNotifications()
        
        timer = Timer.scheduledTimer(timeInterval: 60, target: self, selector: #selector(updateData), userInfo: nil, repeats: true)
        
        updateData()
    }

    func applicationWillTerminate(_ aNotification: Notification) {

    }
    
    func createMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Update", action: #selector(updateData), keyEquivalent: "r")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }
    
    @objc func updateData() {

        self.getRepos(for: self.username) { (result) in
            switch result {
            case .success(let repos):
                self.repos = repos
                for repo in repos {
//                    let fileName = self.getDocumentsDirectory().appendingPathComponent(repo.fullName).appendingPathExtension("json")

//                    let date:String? = nil
                    let date:Date = try! self.defaults.object(forKey: "GHL.\(repo.fullName).last_commit") as! Date

                    self.getCommits(for: repo.fullName, date: "\(date)") { (result) in
                        switch result {
                        case .success(let commits):
//                            repo.commits = commits
//                            self.saveCommitsToDisk(file: fileName, commits: commits)
//                            let encoder = JSONEncoder()
//                            let data = try! encoder.encode(commits)
//                            let res = NSKeyedArchiver.archiveRootObject(data, toFile: fileName.path)
//                            do {
//                                try data.write(to: fileName)
//                            } catch {
//                                print("Couldn't write file \(fileName)")
//                            }
                            
                            let newDate:Date = (commits.first?.description.author.date)!
                            self.defaults.set(newDate, forKey: "GHL.\(repo.fullName).last_commit")
                            self.defaults.synchronize()
                            
                            for commit in commits.reversed() {
                                let testDate:Date = commit.description.author.date
                                if (date != nil && date != testDate) {
                                    self.showNotification(title: "\(commit.author.login) commited to \(repo.name)", subtitle: commit.description.message, image: commit.author.avatarUrl)
                                }
                            }
                        case .failure(let error):
                            print("commits failure: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure(let error):
                print("repos failure: \(error.localizedDescription)")
            }
        }
    }
    
//    func getDocumentsDirectory() -> URL {
//        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
//        return paths[0]
//    }
//
//    func getCommitsFromDisk(file: URL) -> [Commit] {
//        var commits:[Commit] = []
//
//        guard let stream = InputStream(fileAtPath: file.path) else {
//            print("Could not create stream for url")
//            return commits
//        }
//
//        stream.open()
//        defer { stream.close() }
//
//        let decoder = JSONDecoder()
//        do {
//            // 1. Read the JSON from our stream
//            let json = try JSONSerialization.jsonObject(with: stream, options: [])
//            // 2. Convert that JSON to Data
//            let data = try JSONSerialization.data(withJSONObject: json, options: [])
//            // 3. Use our decoder to decode an array of Post structs from that data
//            commits = try decoder.decode([Commit].self, from: data)
//        } catch {
//            print(error.localizedDescription)
//        }
//
//        return commits
//    }
//
//    func saveCommitsToDisk(file: URL, commits: [Commit]) {
//        let encoder = JSONEncoder()
//        do {
//            let data = try encoder.encode(commits)
//            // 3. Check if posts.json already exists...
//            if fileManager.fileExists(atPath: file.path) {
//                // ... and if it does, remove it
//                try fileManager.removeItem(at: file)
//            }
//            try fileManager.createDirectory(at: file.deletingLastPathComponent().absoluteURL, withIntermediateDirectories: true, attributes: nil)
//            fileManager.createFile(atPath: file.path, contents: nil)
//            try data.write(to: file, options: [.atomicWrite])
//            // 4. Now create posts.json with the data encoded from our array of Posts
////            fileManager.createFile(atPath: file.path, contents: data, attributes: nil)
//        } catch {
//            print(error.localizedDescription)
//        }
//    }
    
    func getRepos(for userName: String, completion: ((Result<[Repo]>) -> Void)?) {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.github.com"
        urlComponents.path = "/users/\(userName)/subscriptions"
        guard let url = urlComponents.url else { fatalError("Could not create URL from components") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { (responseData, response, responseError) in
            DispatchQueue.main.async {
                if let error = responseError {
                    completion?(.failure(error))
                } else if let jsonData = responseData {
                    let decoder = JSONDecoder()
                    
                    do {
                        let repos = try decoder.decode([Repo].self, from: jsonData)
                        completion?(.success(repos))
                    } catch {
                        completion?(.failure(error))
                    }
                } else {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey : "Data was not retrieved from request"]) as Error
                    completion?(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func getCommits(for repoName: String, date: String? = nil, completion: ((Result<[Commit]>) -> Void)?) {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "api.github.com"
        urlComponents.path = "/repos/\(repoName)/commits"
        
        if (date != nil) {
            let dateItem = URLQueryItem(name: "since", value: date!)
            urlComponents.queryItems = [dateItem]
        }
        
        guard let url = urlComponents.url else { fatalError("Could not create URL from components") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { (responseData, response, responseError) in
            DispatchQueue.main.async {
                if let error = responseError {
                    completion?(.failure(error))
                } else if let jsonData = responseData {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    
                    do {
                        let commits = try decoder.decode([Commit].self, from: jsonData)
                        completion?(.success(commits))
                    } catch {
                        completion?(.failure(error))
                    }
                } else {
                    let error = NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey : "Data was not retrieved from request"]) as Error
                    completion?(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func showNotification(title: String, subtitle: String, image: String? = nil) -> Void {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = subtitle
        notification.soundName = NSUserNotificationDefaultSoundName
        if image != nil {
            notification.contentImage = NSImage(contentsOf: NSURL(string: image!)! as URL)
        }
        nc.deliver(notification)
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}

enum Result<Value> {
    case success(Value)
    case failure(Error)
}

struct Repo: Codable {
    let id: Int
    let name: String
    let fullName: String
//    let description: String
//    let watchers: Int
//    let forks: Int
//    let openIssues: Int
//    let createdAt: Date
//    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "id"
        case name
        case fullName = "full_name"
//        case description
//        case watchers
//        case forks
//        case openIssues = "open_issues"
//        case createdAt = "created_at"
//        case updatedAt = "updated_at"
    }
    
    init(id: Int, name: String, fullName: String/*, description: String, watchers: Int, forks: Int, openIssues: Int*/ /*createdAt: Date, updatedAt: Date,*/) {
        self.id = id
        self.name = name
        self.fullName = fullName
//        self.description = description
//        self.watchers = watchers
//        self.forks = forks
//        self.openIssues = openIssues
//        self.createdAt = createdAt
//        self.updatedAt = updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Int.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let fullName = try container.decode(String.self, forKey: .fullName)
//        let description = try container.decode(String.self, forKey: .description)
//        let watchers = try container.decode(Int.self, forKey: .watchers)
//        let forks = try container.decode(Int.self, forKey: .forks)
//        let openIssues = try container.decode(Int.self, forKey: .openIssues)
//        let createdAt = try container.decode(Date.self, forKey: .createdAt)
//        let updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        self.init(id: id, name: name, fullName: fullName/*, description: description ?? "", watchers: watchers, forks: forks, openIssues: openIssues*/ /*createdAt: createdAt, updatedAt: updatedAt,*/)
    }
}

struct Commit: Codable {
    let id: String
    let htmlUrl: String
    let author: User
    let description: CommitDescription
    
    enum CodingKeys: String, CodingKey {
        case id = "sha"
        case htmlUrl = "html_url"
        case author
        case description = "commit"
    }
    
    init(id: String, htmlUrl: String, author: User, description: CommitDescription) {
        self.id = id
        self.htmlUrl = htmlUrl
        self.author = author
        self.description = description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let htmlUrl = try container.decode(String.self, forKey: .htmlUrl)
        let author = try container.decode(User.self, forKey: .author)
        let description = try container.decode(CommitDescription.self, forKey: .description)
        self.init(id: id, htmlUrl: htmlUrl, author: author, description: description)
    }
    

    struct User: Codable {
        let id: Int
        let login: String
        let avatarUrl: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case login
            case avatarUrl = "avatar_url"
        }
        
        init(id: Int, login: String, avatarUrl: String) {
            self.id = id
            self.login = login
            self.avatarUrl = avatarUrl
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let id = try container.decode(Int.self, forKey: .id)
            let login = try container.decode(String.self, forKey: .login)
            let avatarUrl = try container.decode(String.self, forKey: .avatarUrl)
            self.init(id: id, login: login, avatarUrl: avatarUrl)
        }
    }
    
    
    struct CommitDescription: Codable {
        let message: String
        let commentCount: Int
        let author: CommitAuthor
        
        enum CodingKeys: String, CodingKey {
            case message
            case commentCount = "comment_count"
            case author
        }
        
        init(message: String, commentCount: Int, author: CommitAuthor) {
            self.message = message
            self.commentCount = commentCount
            self.author = author
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let message = try container.decode(String.self, forKey: .message)
            let commentCount = try container.decode(Int.self, forKey: .commentCount)
            let author = try container.decode(CommitAuthor.self, forKey: .author)
            self.init(message: message, commentCount: commentCount, author: author)
        }
        
        struct CommitAuthor: Codable {
            let name: String
            let email: String
            let date: Date
            
            enum CodingKeys: String, CodingKey {
                case name
                case email
                case date
            }
            
            init(name: String, email: String, date: Date) {
                self.name = name
                self.email = email
                self.date = date
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let name = try container.decode(String.self, forKey: .name)
                let email = try container.decode(String.self, forKey: .email)
                let date = try container.decode(Date.self, forKey: .date)
                self.init(name: name, email: email, date: date)
            }
        }
    }
}