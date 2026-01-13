//
//  LinkManager.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation
import Combine
import AppKit
import SwiftUI

class LinkManager: ObservableObject {
    @Published var links: [Link] = []
    
    private let store: LinkStore
    private let userDefaults: UserDefaults
    private let hasLaunchedKey = "LinkShelf_HasLaunched"
    
    init(store: LinkStore = AppGroupLinkStore()) {
        self.store = store
        self.userDefaults = store.userDefaults
        loadLinks()
        
        // Setup observer for external changes (Share Extension)
        setupNotificationObserver()
        
        // Set default links on first launch
        if !hasLaunchedBefore() {
            setDefaultLinks()
            markAsLaunched()
        } else {
            // Fetch favicons for existing links that don't have them
            fetchMissingFavicons()
        }
    }
    
    deinit {
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), 
                                         Unmanaged.passUnretained(self).toOpaque(), 
                                         CFNotificationName(SharedLinkStorage.linksChangedNotification as CFString), 
                                         nil)
    }
    
    private func setupNotificationObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let name = SharedLinkStorage.linksChangedNotification as CFString
        
        CFNotificationCenterAddObserver(center,
                                        observer,
                                        { (_, observer, _, _, _) in
                                            // Handle notification
                                            if let observer = observer {
                                                let manager = Unmanaged<LinkManager>.fromOpaque(observer).takeUnretainedValue()
                                                DispatchQueue.main.async {
                                                    manager.loadLinks()
                                                    // Also fetch favicons for new links
                                                    manager.fetchMissingFavicons()
                                                }
                                            }
                                        },
                                        name,
                                        nil,
                                        .deliverImmediately)
    }
    
    private func hasLaunchedBefore() -> Bool {
        return userDefaults.bool(forKey: hasLaunchedKey)
    }
    
    private func markAsLaunched() {
        userDefaults.set(true, forKey: hasLaunchedKey)
    }
    
    private func setDefaultLinks() {
        let defaultLinks = [
            Link(title: "LinkedIn Profile", url: "https://linkedin.com/in/yourprofile", order: 0),
            Link(title: "GitHub Profile", url: "https://github.com/yourusername", order: 1),
            Link(title: "Portfolio Website", url: "https://yourportfolio.com", order: 2)
        ]
        links = defaultLinks
        saveLinks()
    }
    
    func loadLinks() {
        let decoded = store.loadLinks()
        links = decoded.sorted { left, right in
            let leftKey = sortKey(for: left.folder)
            let rightKey = sortKey(for: right.folder)
            if leftKey != rightKey {
                return leftKey < rightKey
            }
            return left.order < right.order
        }
    }
    
    func saveLinks() {
        store.saveLinks(links)
    }
    
    func addLink(title: String, url: String, folder: String? = nil) {
        let normalizedFolder = normalizeFolder(folder)
        let newOrder = links.filter { $0.folder == normalizedFolder }.count
        let newLink = Link(title: title, url: url, order: newOrder, folder: normalizedFolder)
        links.append(newLink)
        saveLinks()
        
        // Fetch favicon asynchronously
        Task {
            if let faviconData = await FaviconManager.shared.fetchFavicon(for: url) {
                await MainActor.run {
                    if let index = links.firstIndex(where: { $0.id == newLink.id }) {
                        links[index].faviconData = faviconData
                        saveLinks()
                    }
                }
            }
        }
    }
    
    func updateLink(_ link: Link, title: String, url: String, folder: String? = nil) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            let previousFolder = links[index].folder
            let normalizedFolder = normalizeFolder(folder)
            links[index].title = title
            links[index].url = url
            links[index].folder = normalizedFolder
            // Clear old favicon - will fetch new one
            links[index].faviconData = nil
            
            if previousFolder != normalizedFolder {
                // Reindex previous folder
                reindexOrders(in: previousFolder)
                // Place updated link at the end of the new folder
                links[index].order = Int.max
                reindexOrders(in: normalizedFolder)
            }
            saveLinks()
            
            // Fetch favicon asynchronously
            Task {
                if let faviconData = await FaviconManager.shared.fetchFavicon(for: url) {
                    await MainActor.run {
                        if let currentIndex = links.firstIndex(where: { $0.id == link.id }) {
                            links[currentIndex].faviconData = faviconData
                            saveLinks()
                        }
                    }
                }
            }
        }
    }
    
    func deleteLink(_ link: Link) {
        links.removeAll { $0.id == link.id }
        reindexOrders(in: link.folder)
        saveLinks()
    }
    
    func moveLink(in folder: String?, from source: IndexSet, to destination: Int) {
        let normalizedFolder = normalizeFolder(folder)
        var folderLinks = links
            .filter { $0.folder == normalizedFolder }
            .sorted { $0.order < $1.order }
        
        folderLinks.move(fromOffsets: source, toOffset: destination)
        
        for (index, link) in folderLinks.enumerated() {
            if let globalIndex = links.firstIndex(where: { $0.id == link.id }) {
                links[globalIndex].order = index
            }
        }
        saveLinks()
    }
    
    func copyToClipboard(_ link: Link) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link.url, forType: .string)
    }
    
    func openInBrowser(_ link: Link) {
        guard let url = URL(string: link.url) else { return }
        NSWorkspace.shared.open(url)
    }
    
    /// Check if a URL already exists in the links
    func linkExists(url: String) -> Bool {
        let normalizedURL = normalizeURL(url)
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
    
    private func normalizeFolder(_ folder: String?) -> String? {
        let trimmed = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
    
    private func sortKey(for folder: String?) -> String {
        return normalizeFolder(folder)?.lowercased() ?? ""
    }
    
    private func reindexOrders(in folder: String?) {
        let normalizedFolder = normalizeFolder(folder)
        let sorted = links
            .filter { $0.folder == normalizedFolder }
            .sorted { $0.order < $1.order }
        
        for (index, link) in sorted.enumerated() {
            if let globalIndex = links.firstIndex(where: { $0.id == link.id }) {
                links[globalIndex].order = index
            }
        }
    }
    
    /// Fetches favicons for all links that don't have one yet
    func fetchMissingFavicons() {
        let linksWithoutFavicons = links.filter { $0.faviconData == nil }
        
        // Fetch favicons with a small delay between requests to avoid overwhelming servers
        for (index, link) in linksWithoutFavicons.enumerated() {
            Task {
                // Add small delay to stagger requests
                if index > 0 {
                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                }
                
                if let faviconData = await FaviconManager.shared.fetchFavicon(for: link.url) {
                    await MainActor.run {
                        if let linkIndex = links.firstIndex(where: { $0.id == link.id }) {
                            links[linkIndex].faviconData = faviconData
                            saveLinks()
                        }
                    }
                }
            }
        }
    }
    
    var folderNames: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for name in links.compactMap({ normalizeFolder($0.folder) }) {
            let key = name.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                result.append(name)
            }
        }
        return result.sorted { $0.lowercased() < $1.lowercased() }
    }
}
