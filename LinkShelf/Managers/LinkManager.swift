//
//  LinkManager.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import AppKit
import Combine
import Foundation
import LinkShelfDomain
import LinkShelfPersistence
import SwiftUI

/// Storage problems the UI reports separately from an empty collection.
enum LinkStorageIssue: Identifiable, Equatable {
    case loadFailed
    case saveFailed
    case migrationFailed

    var id: Self { self }
}

/// Observable adapter between the SwiftUI views and `LinkRepository`.
///
/// Views keep working with `Link` values and " / "-separated folder paths;
/// this type maps them to the repository's UUID-based records. Mutations run
/// in submission order on the repository actor, then the published state is
/// refetched from the store.
final class LinkManager: ObservableObject {
    @Published private(set) var links: [Link] = []
    @Published private(set) var folderNames: [String] = []
    @Published var storageIssue: LinkStorageIssue?
    /// False until the first fetch (or a reported failure), so an empty
    /// collection is never shown while the store is still opening or migrating.
    @Published private(set) var hasLoaded = false

    private let storage: LinkShelfAppGroupStorage
    private var repository: LinkRepository?
    private var pendingWork: Task<Void, Never>?
    private var snapshots: [UUID: LinkSnapshot] = [:]
    private var recentlyDeleted: [UUID: LinkSnapshot] = [:]
    private var folderIDsByPath: [String: UUID] = [:]
    private var favicons: [String: Data] = [:]
    private var faviconHostsInFlight: Set<String> = []

    init(storage: LinkShelfAppGroupStorage = LinkShelfAppGroupStorage()) {
        self.storage = storage
        setupNotificationObserver()
        start()
    }

    deinit {
        CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                           Unmanaged.passUnretained(self).toOpaque(),
                                           CFNotificationName(LinkShelfChangeSignal.name as CFString),
                                           nil)
    }

    // MARK: Lifecycle

    private func start() {
        #if DEBUG
        if ScreenshotDemo.isEnabled {
            startScreenshotDemo()
            return
        }
        #endif
        pendingWork = Task {
            let repository: LinkRepository
            do {
                repository = try storage.makeRepository()
            } catch {
                storageIssue = .loadFailed
                hasLoaded = true
                return
            }
            do {
                let report = try await storage.migrateLegacyDataIfNeeded(into: repository)
                for (url, data) in report.faviconsByURL {
                    await FaviconCache.shared.store(data, for: url)
                }
                _ = try await repository.repairFolderCycles()
            } catch {
                // Leave the store untouched and the legacy data in place; the
                // migration is retried on the next launch.
                storageIssue = .migrationFailed
                hasLoaded = true
                return
            }
            self.repository = repository
            await refresh()
        }
    }

    #if DEBUG
    /// Sample collection in a throwaway in-memory store, for App Store
    /// screenshots. Never touches the shared store or legacy data.
    private func startScreenshotDemo() {
        ScreenshotDemo.installCaptureObserver()
        pendingWork = Task {
            do {
                let repository = LinkRepository(
                    modelContainer: try LinkShelfContainerFactory.makeContainer(.inMemory))
                try await ScreenshotDemo.seed(repository)
                self.repository = repository
            } catch {
                storageIssue = .loadFailed
            }
            await refresh()
        }
    }
    #endif

    private func setupNotificationObserver() {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        Unmanaged.passUnretained(self).toOpaque(),
                                        { _, observer, _, _, _ in
                                            guard let observer else { return }
                                            let manager = Unmanaged<LinkManager>.fromOpaque(observer).takeUnretainedValue()
                                            DispatchQueue.main.async { manager.reloadAfterExternalChange() }
                                        },
                                        LinkShelfChangeSignal.name as CFString,
                                        nil,
                                        .deliverImmediately)
    }

    /// Another process (the Share Extension) wrote to the store. A fresh
    /// context guarantees the refetch sees its changes rather than cached rows.
    func reloadAfterExternalChange() {
        let previous = pendingWork
        pendingWork = Task {
            await previous?.value
            guard let current = repository else { return }
            repository = LinkRepository(modelContainer: current.modelContainer)
            await refresh()
        }
    }

    private func enqueue(_ operation: @escaping (LinkRepository) async throws -> Void) {
        let previous = pendingWork
        pendingWork = Task {
            await previous?.value
            guard let repository else {
                storageIssue = storageIssue ?? .loadFailed
                return
            }
            do {
                try await operation(repository)
                LinkShelfChangeSignal.post()
            } catch {
                storageIssue = .saveFailed
            }
            await refresh()
        }
    }

    private func refresh() async {
        guard let repository else { return }
        do {
            let folders = try await repository.folders()
            let snapshots = try await repository.links()
            apply(folders: folders, links: snapshots)
            loadFavicons()
        } catch {
            storageIssue = .loadFailed
        }
        hasLoaded = true
    }

    private func apply(folders: [FolderSnapshot], links snapshots: [LinkSnapshot]) {
        let tree = FolderTree(folders)
        var pathsByID: [UUID: String] = [:]
        var idsByPath: [String: UUID] = [:]
        for folder in folders.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            let path = tree.path(of: folder.id).map(\.name).joined(separator: FolderName.pathSeparator)
            pathsByID[folder.id] = path
            if idsByPath[path.lowercased()] == nil { idsByPath[path.lowercased()] = folder.id }
        }
        folderIDsByPath = idsByPath
        folderNames = idsByPath.values.compactMap { pathsByID[$0] }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        self.snapshots = Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var positions: [UUID?: Int] = [:]
        links = snapshots.map { snapshot in
            let folderPath = snapshot.folderID.flatMap { pathsByID[$0] }
            let key = folderPath == nil ? nil : snapshot.folderID
            let order = positions[key, default: 0]
            positions[key] = order + 1
            return Link(id: snapshot.id, title: snapshot.title, url: snapshot.url, order: order,
                        folder: folderPath, faviconData: Self.host(of: snapshot.url).flatMap { favicons[$0] })
        }
    }

    // MARK: Links

    func addLink(title: String, url: String, folder: String? = nil) {
        enqueue { repository in
            let folderID = try await self.ensureFolder(path: folder, in: repository)
            try await repository.addLink(LinkDraft(title: title, url: url, folderID: folderID))
        }
    }

    func importLinks(_ importedLinks: [ImportedBookmark]) {
        enqueue { repository in
            for imported in importedLinks {
                let folderID = try await self.ensureFolder(path: imported.folder, in: repository)
                do {
                    try await repository.addLink(LinkDraft(title: imported.title, url: imported.url, folderID: folderID))
                } catch LinkShelfError.duplicateLink {
                    continue
                }
            }
        }
    }

    func updateLink(_ link: Link, title: String, url: String, folder: String? = nil) {
        enqueue { repository in
            let folderID = try await self.ensureFolder(path: folder, in: repository)
            try await repository.updateLink(id: link.id, with: LinkDraft(title: title, url: url, folderID: folderID))
        }
    }

    func deleteLink(_ link: Link) {
        deleteLinks(withIDs: [link.id])
    }

    func deleteLinks(withIDs ids: Set<UUID>) {
        for id in ids {
            if let snapshot = snapshots[id] { recentlyDeleted[id] = snapshot }
        }
        links.removeAll { ids.contains($0.id) }
        enqueue { try await $0.deleteLinks(ids: ids) }
    }

    func restoreLink(_ link: Link) {
        if let snapshot = recentlyDeleted.removeValue(forKey: link.id) {
            enqueue { try await $0.restoreLink(snapshot) }
        } else {
            addLink(title: link.title, url: link.url, folder: link.folder)
        }
    }

    func moveLink(in folder: String?, from source: IndexSet, to destination: Int) {
        let folderID = folder.flatMap { folderIDsByPath[$0.lowercased()] }
        guard folder == nil || folderID != nil else { return }
        var ordered = links.filter { $0.folder == folder }.sorted { $0.order < $1.order }
        let movedIDs = source.map { ordered[$0].id }
        ordered.move(fromOffsets: source, toOffset: destination)
        let orderedIDs = ordered.map(\.id)

        for (position, id) in orderedIDs.enumerated() {
            if let index = links.firstIndex(where: { $0.id == id }) { links[index].order = position }
        }

        if movedIDs.count == 1, let movedID = movedIDs.first, let index = orderedIDs.firstIndex(of: movedID) {
            enqueue { try await $0.moveLink(id: movedID, toFolder: folderID, at: index) }
        } else {
            enqueue { try await $0.reorderLinks(inFolder: folderID, orderedIDs: orderedIDs) }
        }
    }

    func copyToClipboard(_ link: Link) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(link.url, forType: .string)
    }

    /// Stored values are revalidated, so historic or synced invalid URLs
    /// cannot be opened.
    func openInBrowser(_ link: Link) {
        guard let url = LinkURL.openableURL(from: link.url) else {
            NSSound.beep()
            return
        }
        NSWorkspace.shared.open(url)
    }

    func linkExists(url: String) -> Bool {
        guard let key = try? LinkURL(validating: url).comparisonKey else { return false }
        return snapshots.values.contains { $0.comparisonKey == key }
    }

    // MARK: Folders

    func canAddFolder(named name: String, inside parent: String?) -> Bool {
        guard let name = try? FolderName.validate(name) else { return false }
        let path = parent.map { $0 + FolderName.pathSeparator + name } ?? name
        return folderIDsByPath[path.lowercased()] == nil
    }

    func addFolder(named name: String, inside parent: String?) {
        guard canAddFolder(named: name, inside: parent), let name = try? FolderName.validate(name) else { return }
        enqueue { repository in
            let parentID = try await self.ensureFolder(path: parent, in: repository)
            try await repository.createFolder(named: name, inside: parentID)
        }
    }

    /// `name` is the folder's full new path, so a rename can also move it.
    func canRenameFolder(_ folder: String, to name: String) -> Bool {
        guard let id = folderIDsByPath[folder.lowercased()],
              let components = Self.pathComponents(name),
              components.allSatisfy({ (try? FolderName.validate($0)) != nil }) else { return false }
        let newPath = components.joined(separator: FolderName.pathSeparator).lowercased()
        let oldPath = folder.lowercased()
        let parentPath = components.dropLast().joined(separator: FolderName.pathSeparator).lowercased()
        let movesInsideItself = !parentPath.isEmpty
            && (parentPath == oldPath || parentPath.hasPrefix(oldPath + FolderName.pathSeparator))
        let clashes = folderIDsByPath[newPath].map { $0 != id } ?? false
        return !movesInsideItself && !clashes
    }

    @discardableResult
    func renameFolder(_ folder: String, to name: String) -> Bool {
        guard canRenameFolder(folder, to: name),
              let id = folderIDsByPath[folder.lowercased()],
              let components = Self.pathComponents(name),
              let newName = components.last else { return false }
        let parentPath = components.dropLast().joined(separator: FolderName.pathSeparator)
        enqueue { repository in
            let parentID = try await self.ensureFolder(path: parentPath, in: repository)
            try await repository.updateFolder(id: id, name: newName, parentID: parentID)
        }
        return true
    }

    func deleteFolder(_ folder: String) {
        guard let id = folderIDsByPath[folder.lowercased()] else { return }
        let prefix = folder + FolderName.pathSeparator
        links.removeAll { $0.folder == folder || ($0.folder?.hasPrefix(prefix) ?? false) }
        folderNames.removeAll { $0 == folder || $0.hasPrefix(prefix) }
        enqueue { try await $0.deleteFolder(id: id) }
    }

    /// Resolves a " / "-separated path to a folder ID, creating any missing
    /// folders along the way. Returns `nil` for an empty path (unfiled).
    private func ensureFolder(path: String?, in repository: LinkRepository) async throws -> UUID? {
        guard let components = Self.pathComponents(path) else { return nil }
        var tree = FolderTree(try await repository.folders())
        var parentID: UUID?
        for name in components {
            if let existing = tree.children(of: parentID).first(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }) {
                parentID = existing.id
            } else {
                parentID = try await repository.createFolder(named: name, inside: parentID).id
                tree = FolderTree(try await repository.folders())
            }
        }
        return parentID
    }

    private static func pathComponents(_ path: String?) -> [String]? {
        let components = (path ?? "")
            .components(separatedBy: FolderName.pathSeparator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return components.isEmpty ? nil : components
    }

    // MARK: Favicons

    private var shouldFetchFavicons: Bool {
        UserDefaults.standard.object(forKey: "fetchFavicons") == nil || UserDefaults.standard.bool(forKey: "fetchFavicons")
    }

    /// Fills icons from the local cache and, when permitted, the network.
    /// Icons never block loading or saving links.
    private func loadFavicons() {
        let hosts = Set(links.compactMap { Self.host(of: $0.url) })
            .subtracting(favicons.keys)
            .subtracting(faviconHostsInFlight)
        guard !hosts.isEmpty else { return }
        faviconHostsInFlight.formUnion(hosts)
        let urlsByHost = Dictionary(links.compactMap { link in Self.host(of: link.url).map { ($0, link.url) } },
                                    uniquingKeysWith: { first, _ in first })
        let fetchFromNetwork = shouldFetchFavicons

        Task {
            for (index, host) in hosts.sorted().enumerated() {
                guard let url = urlsByHost[host] else { continue }
                var data = await FaviconCache.shared.data(for: url)
                if data == nil, fetchFromNetwork {
                    // Stagger requests to avoid overwhelming servers.
                    if index > 0 { try? await Task.sleep(nanoseconds: 200_000_000) }
                    data = await FaviconManager.shared.fetchFavicon(for: url)
                    if let data { await FaviconCache.shared.store(data, for: url) }
                }
                faviconHostsInFlight.remove(host)
                guard let data else { continue }
                favicons[host] = data
                for index in links.indices where Self.host(of: links[index].url) == host {
                    links[index].faviconData = data
                }
            }
        }
    }

    private static func host(of url: String) -> String? {
        URL(string: url)?.host?.lowercased()
    }
}
