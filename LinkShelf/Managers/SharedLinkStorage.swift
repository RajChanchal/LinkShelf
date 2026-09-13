//
//  SharedLinkStorage.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation

class SharedLinkStorage {
    static let shared = SharedLinkStorage()
    
    private let store: LinkStore = AppGroupLinkStore()
    
    // Notification name for inter-process communication
    static let linksChangedNotification = "com.chanchalgeek.LinkShelf.linksChanged"
    
    private init() {}
    
    /// Load all links from shared storage
    func loadLinks() -> [Link] {
        let decoded = store.loadLinks()
        return decoded.sorted { left, right in
            let leftKey = sortKey(for: left.folder)
            let rightKey = sortKey(for: right.folder)
            if leftKey != rightKey {
                return leftKey < rightKey
            }
            return left.order < right.order
        }
    }
    
    /// Save links to shared storage
    func saveLinks(_ links: [Link]) {
        store.saveLinks(links)
    }
    
    /// Add a new link to shared storage
    func addLink(title: String, url: String) {
        var links = loadLinks()
        let newOrder = links.filter { $0.folder == nil }.count
        let newLink = Link(title: title, url: url, order: newOrder, folder: nil)
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
    
    private func sortKey(for folder: String?) -> String {
        return folder?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }
}


