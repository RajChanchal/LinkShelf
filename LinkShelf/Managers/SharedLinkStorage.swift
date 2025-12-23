//
//  SharedLinkStorage.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation

class SharedLinkStorage {
    static let shared = SharedLinkStorage()
    
    private let appGroupID = "group.com.chanchalgeek.LinkShelf"
    private let linksKey = "LinkShelf_Links"
    
    private var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }
    
    private init() {}
    
    /// Load all links from shared storage
    func loadLinks() -> [Link] {
        guard let userDefaults = userDefaults,
              let data = userDefaults.data(forKey: linksKey),
              let decoded = try? JSONDecoder().decode([Link].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.order < $1.order }
    }
    
    /// Save links to shared storage
    func saveLinks(_ links: [Link]) {
        guard let userDefaults = userDefaults,
              let encoded = try? JSONEncoder().encode(links) else {
            return
        }
        userDefaults.set(encoded, forKey: linksKey)
        userDefaults.synchronize()
    }
    
    /// Add a new link to shared storage
    func addLink(title: String, url: String) {
        var links = loadLinks()
        let newOrder = links.count
        let newLink = Link(title: title, url: url, order: newOrder)
        links.append(newLink)
        saveLinks(links)
    }
    
    /// Check if a URL already exists in the links
    func linkExists(url: String) -> Bool {
        let normalizedURL = normalizeURL(url)
        let links = loadLinks()
        return links.contains { link in
            normalizeURL(link.url) == normalizedURL
        }
    }
    
    /// Normalize URL for comparison (lowercase, add https:// if missing)
    private func normalizeURL(_ urlString: String) -> String {
        var url = urlString.trimmingCharacters(in: .whitespaces)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        return url.lowercased()
    }
}


