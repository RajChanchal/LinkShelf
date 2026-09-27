//
//  LinkStore.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation

protocol LinkStore {
    var userDefaults: UserDefaults { get }
    func loadLinks() -> [Link]
    func saveLinks(_ links: [Link])
    func loadFolders() -> [String]
    func saveFolders(_ folders: [String])
}

final class AppGroupLinkStore: LinkStore {
    private let appGroupID = "group.com.chanchalgeek.LinkShelf"
    private let linksKey = "LinkShelf_Links"
    
    let userDefaults: UserDefaults
    
    init() {
        if let appGroupDefaults = UserDefaults(suiteName: appGroupID) {
            self.userDefaults = appGroupDefaults
        } else {
            self.userDefaults = UserDefaults.standard
        }
    }
    
    func loadLinks() -> [Link] {
        guard let data = userDefaults.data(forKey: linksKey),
              let decoded = try? JSONDecoder().decode([Link].self, from: data) else {
            return []
        }
        return decoded
    }
    
    func saveLinks(_ links: [Link]) {
        guard let encoded = try? JSONEncoder().encode(links) else { return }
        userDefaults.set(encoded, forKey: linksKey)
        userDefaults.synchronize() // Ensure data is written immediately for Share Extension
        
        // Post Darwin notification to notify other processes
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let name = CFNotificationName(SharedLinkStorage.linksChangedNotification as CFString)
        CFNotificationCenterPostNotification(center, name, nil, nil, true)
    }

    func loadFolders() -> [String] {
        userDefaults.stringArray(forKey: "LinkShelf_Folders") ?? []
    }

    func saveFolders(_ folders: [String]) {
        userDefaults.set(folders, forKey: "LinkShelf_Folders")
        userDefaults.synchronize()
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(SharedLinkStorage.linksChangedNotification as CFString), nil, nil, true)
    }
}
