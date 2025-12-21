//
//  StatusBarController.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import AppKit
import SwiftUI
import Combine

class StatusBarController: ObservableObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var linkManager: LinkManager
    
    init(linkManager: LinkManager) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        
        // Store link manager reference
        self.linkManager = linkManager
        
        // Setup status bar button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "link", accessibilityDescription: "LinkShelf")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Setup popover content
        let contentView = LinkListView()
            .environmentObject(linkManager)
        popover.contentViewController = NSHostingController(rootView: contentView)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        
        // Check if right-click (control-click)
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showMenu(sender)
            return
        }
        
        // Left click - toggle popover
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            // Activate app to bring popover to front
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        
        // Quit menu item
        let quitItem = NSMenuItem(title: L.quitLinkShelf.localized, action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        // Show menu
        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        }
    }
    
    @objc func quitApp(_ sender: AnyObject?) {
        NSApplication.shared.terminate(nil)
    }
}

