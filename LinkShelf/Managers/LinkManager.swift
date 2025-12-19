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
    
    private let userDefaults = UserDefaults.standard
    private let linksKey = "LinkShelf_Links"
    private let hasLaunchedKey = "LinkShelf_HasLaunched"
    
    init() {
        loadLinks()
        
        // Set default links on first launch
        if !hasLaunchedBefore() {
            setDefaultLinks()
            markAsLaunched()
        } else {
            // Fetch favicons for existing links that don't have them
            fetchMissingFavicons()
        }
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
        if let data = userDefaults.data(forKey: linksKey),
           let decoded = try? JSONDecoder().decode([Link].self, from: data) {
            links = decoded.sorted { $0.order < $1.order }
        }
    }
    
    func saveLinks() {
        if let encoded = try? JSONEncoder().encode(links) {
            userDefaults.set(encoded, forKey: linksKey)
        }
    }
    
    func addLink(title: String, url: String) {
        let newOrder = links.count
        let newLink = Link(title: title, url: url, order: newOrder)
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
    
    func updateLink(_ link: Link, title: String, url: String) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            links[index].title = title
            links[index].url = url
            // Clear old favicon - will fetch new one
            links[index].faviconData = nil
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
        // Reorder remaining links
        for (index, _) in links.enumerated() {
            links[index].order = index
        }
        saveLinks()
    }
    
    func moveLink(from source: IndexSet, to destination: Int) {
        links.move(fromOffsets: source, toOffset: destination)
        // Update order values
        for (index, _) in links.enumerated() {
            links[index].order = index
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
}

