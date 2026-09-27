//
//  ScreenshotDemo.swift
//  LinkShelf
//
//  Created for LinkShelf
//

#if DEBUG
import AppKit
import Foundation
import LinkShelfDomain
import LinkShelfPersistence

/// Debug-only sample data for App Store screenshots. Enable by launching a
/// Debug build with `-LinkShelfScreenshotDemo YES`.
enum ScreenshotDemo {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "LinkShelfScreenshotDemo")
    }

    // Sample content is not user-facing app text and is intentionally not localized.
    private static let folders: [(path: [String], links: [(String, String)])] = [
        ([], [
            ("LinkedIn Profile", "https://www.linkedin.com"),
            ("Portfolio", "https://www.behance.net")
        ]),
        (["Projects"], [
            ("Pull Requests", "https://github.com/pulls"),
            ("Design Specs", "https://www.figma.com"),
            ("Sprint Board", "https://linear.app")
        ]),
        (["Projects", "Docs"], [
            ("SwiftUI Documentation", "https://developer.apple.com/documentation/swiftui"),
            ("Swift Evolution", "https://www.swift.org/swift-evolution/")
        ]),
        (["Reading"], [
            ("Apple Newsroom", "https://www.apple.com/newsroom/"),
            ("Hacker News", "https://news.ycombinator.com"),
            ("Wikipedia", "https://en.wikipedia.org")
        ]),
        (["Tools"], [
            ("Regex Tester", "https://regex101.com"),
            ("Color Palettes", "https://coolors.co")
        ])
    ]

    /// Posting these Darwin notifications (`notifyutil -p <name>`) copies a
    /// native-resolution PNG of an app window to the general pasteboard: the
    /// largest visible window (the popover), or the key window (a sheet).
    static let capturePopoverNotification = "com.chanchalgeek.LinkShelf.debug.capturePopover"
    static let captureKeyWindowNotification = "com.chanchalgeek.LinkShelf.debug.captureKeyWindow"

    static func installCaptureObserver() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async { ScreenshotDemo.copyToPasteboard(ScreenshotDemo.largestVisibleWindow()) }
        }, capturePopoverNotification as CFString, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(center, nil, { _, _, _, _, _ in
            DispatchQueue.main.async { ScreenshotDemo.copyToPasteboard(NSApp.keyWindow) }
        }, captureKeyWindowNotification as CFString, nil, .deliverImmediately)
    }

    static func largestVisibleWindow() -> NSWindow? {
        NSApp.windows.filter(\.isVisible).max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }
    }

    static func copyToPasteboard(_ window: NSWindow?) {
        guard let window, let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
    }

    static func seed(_ repository: LinkRepository) async throws {
        var folderIDs: [[String]: UUID] = [:]
        for entry in folders {
            var parentID: UUID?
            for depth in entry.path.indices {
                let path = Array(entry.path[...depth])
                if let existing = folderIDs[path] {
                    parentID = existing
                } else {
                    let folder = try await repository.createFolder(named: entry.path[depth], inside: parentID)
                    folderIDs[path] = folder.id
                    parentID = folder.id
                }
            }
            for (title, url) in entry.links {
                try await repository.addLink(LinkDraft(title: title, url: url, folderID: parentID))
            }
        }
    }
}
#endif
