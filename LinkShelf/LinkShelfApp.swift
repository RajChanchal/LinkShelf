//
//  LinkShelfApp.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import SwiftUI
import Carbon.HIToolbox

@main
struct LinkShelfApp: App {
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
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let shortcutIntroKey = "LinkShelf_ShortcutIntroShown"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create shared link manager
        linkManager = LinkManager()
        
        // Initialize status bar with shared link manager
        if let linkManager = linkManager {
            statusBarController = StatusBarController(linkManager: linkManager)
        }
        
        // Register global shortcut (⌥⌘L) to show the popover
        registerHotKey()
        
        // Show one-time shortcut intro
        showShortcutIntroIfNeeded()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
    }
    
    private func registerHotKey() {
        let hotKeyID = EventHotKeyID(signature: "LShf".fourCharCodeValue, id: 1)
        let modifiers = UInt32(optionKey | cmdKey) // ⌥⌘
        let keyCode = UInt32(kVK_ANSI_L)          // L key
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // Install handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                delegate.handleHotKey(event: event)
                return noErr
            },
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
        
        if status == noErr {
            RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        }
    }
    
    private func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
    
    private func handleHotKey(event: EventRef?) {
        statusBarController?.showPopover()
    }
    
    private func showShortcutIntroIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: shortcutIntroKey) == false else { return }
        
        // Mark as shown immediately to avoid repeat prompts
        defaults.set(true, forKey: shortcutIntroKey)
        
        // Present a lightweight alert describing the shortcut
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L.shortcutIntroTitle.localized
            alert.informativeText = L.shortcutIntroMessage.localized
            alert.alertStyle = .informational
            alert.addButton(withTitle: L.shortcutIntroButton.localized)
            alert.runModal()
        }
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for scalar in unicodeScalars {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }
}
