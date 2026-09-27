//
//  LinkShelfApp.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import SwiftUI
import Carbon.HIToolbox
import ServiceManagement

enum GlobalShortcut: String, CaseIterable, Identifiable {
    case controlOptionL
    case optionCommandL
    case disabled

    var id: String { rawValue }
    var label: String {
        switch self {
        case .controlOptionL: return "⌃⌥L"
        case .optionCommandL: return "⌥⌘L"
        case .disabled: return String(localized: "shortcut.off", defaultValue: "Off")
        }
    }

    var modifiers: UInt32? {
        switch self {
        case .controlOptionL: return UInt32(controlKey | optionKey)
        case .optionCommandL: return UInt32(optionKey | cmdKey)
        case .disabled: return nil
        }
    }
}

extension Notification.Name {
    static let linkShelfShortcutChanged = Notification.Name("LinkShelfShortcutChanged")
}

@main
struct LinkShelfApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    var linkManager: LinkManager?
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var shortcutObserver: NSObjectProtocol?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Create shared link manager
        linkManager = LinkManager()
        
        // Initialize status bar with shared link manager
        if let linkManager = linkManager {
            statusBarController = StatusBarController(linkManager: linkManager)
        }
        
        // Register the user's global shortcut to show the popover.
        registerHotKey()

        shortcutObserver = NotificationCenter.default.addObserver(
            forName: .linkShelfShortcutChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.registerHotKey()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        unregisterHotKey()
        if let shortcutObserver { NotificationCenter.default.removeObserver(shortcutObserver) }
    }
    
    private func registerHotKey() {
        unregisterHotKey()
        let savedValue = UserDefaults.standard.string(forKey: "globalShortcut") ?? GlobalShortcut.controlOptionL.rawValue
        guard let shortcut = GlobalShortcut(rawValue: savedValue), let modifiers = shortcut.modifiers else {
            UserDefaults.standard.set(true, forKey: "shortcutRegistrationSucceeded")
            return
        }
        let hotKeyID = EventHotKeyID(signature: "LShf".fourCharCodeValue, id: 1)
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
        
        guard status == noErr else {
            UserDefaults.standard.set(false, forKey: "shortcutRegistrationSucceeded")
            return
        }
        let registrationStatus = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        UserDefaults.standard.set(registrationStatus == noErr, forKey: "shortcutRegistrationSucceeded")
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
}

struct SettingsView: View {
    @AppStorage("globalShortcut") private var shortcut = GlobalShortcut.controlOptionL.rawValue
    @AppStorage("shortcutRegistrationSucceeded") private var shortcutRegistrationSucceeded = true
    @AppStorage("defaultLinkAction") private var defaultLinkAction = "copy"
    @AppStorage("closeAfterAction") private var closeAfterAction = true
    @AppStorage("fetchFavicons") private var fetchFavicons = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch LinkShelf at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: updateLaunchAtLogin
                ))

                Picker("Global shortcut", selection: $shortcut) {
                    ForEach(GlobalShortcut.allCases) { option in
                        Text(option.label).tag(option.rawValue)
                    }
                }
                .onChange(of: shortcut) { _, _ in
                    NotificationCenter.default.post(name: .linkShelfShortcutChanged, object: nil)
                }

                if !shortcutRegistrationSucceeded && shortcut != GlobalShortcut.disabled.rawValue {
                    Label("That shortcut is already used by another app.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let launchAtLoginError {
                    Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Behavior") {
                Picker("Clicking a link", selection: $defaultLinkAction) {
                    Text("Copies it").tag("copy")
                    Text("Opens it").tag("open")
                }
                Toggle("Close after copying or opening", isOn: $closeAfterAction)
                Toggle("Fetch website icons", isOn: $fetchFavicons)
            }

            Section {
                Text("Website icons are fetched directly from the websites you save. Your links otherwise stay on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 360)
        .padding(.top, 8)
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            launchAtLogin = enabled
            launchAtLoginError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = error.localizedDescription
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
