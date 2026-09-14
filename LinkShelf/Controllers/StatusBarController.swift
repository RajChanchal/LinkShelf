//
//  StatusBarController.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject, ObservableObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var linkManager: LinkManager
    private var outsideClickMonitor: Any?

    init(linkManager: LinkManager) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Create popover
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        // Store link manager reference
        self.linkManager = linkManager

        super.init()

        popover.delegate = self

        // Setup status bar button
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "link", accessibilityDescription: String(localized: .appName))
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = String(localized: .shortcutTooltip)
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

    /// Shows the popover if it is not already visible
    func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        // .transient only auto-dismisses on clicks inside this app; catch clicks
        // that land in other apps' windows too, since LinkShelf runs as an
        // accessory (menu bar only) app.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }
    
    func showMenu(_ sender: AnyObject?) {
        let menu = NSMenu()
        
        // Quit menu item
        let quitItem = NSMenuItem(title: String(localized: .menuQuitLinkshelf), action: #selector(quitApp), keyEquivalent: "q")
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
