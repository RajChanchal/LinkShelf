//
//  LinkShelfApp.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import SwiftUI

@main
struct LinkShelfApp: App {
    @StateObject private var linkManager = LinkManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var linkManager: LinkManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create shared link manager
        linkManager = LinkManager()
        
        // Initialize status bar with shared link manager
        if let linkManager = linkManager {
            statusBarController = StatusBarController(linkManager: linkManager)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}

