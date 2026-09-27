import CryptoKit
import Foundation

/// Raw bytes read from the UserDefaults store used by LinkShelf 1.x.
public struct LegacySource: Codable, Equatable, Sendable {
    public static let appGroupID = "group.com.chanchalgeek.LinkShelf"
    public static let linksKey = "LinkShelf_Links"
    public static let foldersKey = "LinkShelf_Folders"

    public var linksData: Data?
    public var folderPaths: [String]

    public init(linksData: Data?, folderPaths: [String]) {
        self.linksData = linksData
        self.folderPaths = folderPaths
    }

    public var isEmpty: Bool { linksData == nil && folderPaths.isEmpty }

    public init(defaults: UserDefaults) {
        self.init(linksData: defaults.data(forKey: Self.linksKey),
                  folderPaths: defaults.stringArray(forKey: Self.foldersKey) ?? [])
    }

    /// Reads the App Group store, falling back to standard defaults, which
    /// 1.x used when the App Group suite was unavailable.
    public static func read(appGroupID: String = appGroupID, fallback: UserDefaults = .standard) -> LegacySource {
        if let shared = UserDefaults(suiteName: appGroupID) {
            let source = LegacySource(defaults: shared)
            if !source.isEmpty { return source }
        }
        return LegacySource(defaults: fallback)
    }

    /// SHA-256 over the raw source, used to tie a checkpoint and backup to the
    /// exact data they describe.
    public var fingerprint: String {
        var hasher = SHA256()
        hasher.update(data: linksData ?? Data())
        hasher.update(data: Data([0]))
        hasher.update(data: Data(folderPaths.joined(separator: "\n").utf8))
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Writes the untouched source to `directory` before any import begins and
    /// returns the backup's location. An existing backup is never overwritten.
    @discardableResult
    public func writeBackup(to directory: URL) throws -> URL {
        let fileURL = directory.appendingPathComponent("legacy-backup-\(fingerprint).json")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try JSONEncoder().encode(self).write(to: fileURL, options: .atomic)
            }
        } catch {
            let nsError = error as NSError
            throw LinkShelfError.persistenceFailed(.backup, domain: nsError.domain, code: nsError.code)
        }
        return fileURL
    }
}

public enum LegacyImportIssue: Hashable, Sendable {
    /// A record in the legacy array could not be decoded; it stays in the backup.
    case corruptLinkRecord(index: Int)
    /// Imported as-is so the person can correct it; it cannot be opened.
    case invalidURL(UUID)
    case identicalDuplicateID(UUID)
    /// A second, different record reused an ID. It is kept under a new ID.
    case conflictingDuplicateID(UUID, reassignedTo: UUID)
}

public struct LegacyImportPlan: Sendable {
    public var folders: [FolderSnapshot]
    public var links: [LinkSnapshot]
    /// Legacy favicon bytes for seeding the app's local cache; never synced.
    public var favicons: [UUID: Data]
    public var issues: [LegacyImportIssue]
    public var sourceFingerprint: String
}

/// Converts the 1.x format into records without touching any store (FR-10).
public enum LegacyImportPlanner {
    static let pathSeparator = FolderName.pathSeparator

    public static func plan(from source: LegacySource, importedAt date: Date) throws -> LegacyImportPlan {
        var issues: [LegacyImportIssue] = []
        let decoded = try decodeLinks(source.linksData, issues: &issues)
        let folders = buildFolders(explicitPaths: source.folderPaths,
                                   linkPaths: decoded.compactMap { normalizedPath($0.link.folder) },
                                   date: date)
        let folderIDs = Dictionary(uniqueKeysWithValues: folders.map { ($0.key, $0.snapshot.id) })

        var accepted: [(index: Int, id: UUID, link: LegacyLink)] = []
        var seen: [UUID: LegacyLink] = [:]
        for (index, link) in decoded {
            var id = link.id
            if let existing = seen[link.id] {
                if existing.isEquivalent(to: link) {
                    issues.append(.identicalDuplicateID(link.id))
                    continue
                }
                id = DeterministicUUID.make(name: "legacy-duplicate:\(link.id.uuidString):\(index)")
                issues.append(.conflictingDuplicateID(link.id, reassignedTo: id))
            } else {
                seen[link.id] = link
            }
            accepted.append((index, id, link))
        }

        var links: [LinkSnapshot] = []
        var favicons: [UUID: Data] = [:]
        let byFolder = Dictionary(grouping: accepted) { normalizedPath($0.link.folder)?.lowercased() }
        for (folderKey, members) in byFolder {
            let ordered = members.sorted { ($0.link.order, $0.index) < ($1.link.order, $1.index) }
            for (offset, member) in ordered.enumerated() {
                let comparisonKey = LinkURL.comparisonKey(forStored: member.link.url)
                if comparisonKey.hasPrefix("invalid:") { issues.append(.invalidURL(member.id)) }
                links.append(LinkSnapshot(id: member.id,
                                          title: member.link.title,
                                          url: member.link.url,
                                          comparisonKey: comparisonKey,
                                          rank: Int64(offset + 1) * Ranking.spacing,
                                          folderID: folderKey.flatMap { folderIDs[$0] },
                                          createdAt: date,
                                          updatedAt: date))
                if let favicon = member.link.faviconData { favicons[member.id] = favicon }
            }
        }
        links.sort { $0.id.uuidString < $1.id.uuidString }

        return LegacyImportPlan(folders: folders.map { $0.snapshot },
                                links: links,
                                favicons: favicons,
                                issues: issues,
                                sourceFingerprint: source.fingerprint)
    }

    /// Stable identity for a legacy folder path, independent of its casing.
    public static func folderID(forPath path: String) -> UUID {
        DeterministicUUID.make(name: "legacy-folder:" + path.lowercased())
    }

    private static func decodeLinks(_ data: Data?, issues: inout [LegacyImportIssue]) throws -> [(index: Int, link: LegacyLink)] {
        guard let data else { return [] }
        let elements: [LossyLegacyLink]
        do {
            elements = try JSONDecoder().decode([LossyLegacyLink].self, from: data)
        } catch {
            throw LinkShelfError.corruptLegacyLinks
        }
        var result: [(index: Int, link: LegacyLink)] = []
        for (index, element) in elements.enumerated() {
            if let link = element.value {
                result.append((index, link))
            } else {
                issues.append(.corruptLinkRecord(index: index))
            }
        }
        return result
    }

    private struct PlannedFolder {
        let key: String
        let snapshot: FolderSnapshot
    }

    private static func buildFolders(explicitPaths: [String], linkPaths: [String], date: Date) -> [PlannedFolder] {
        var displayPaths: [String: String] = [:]
        for path in (explicitPaths.compactMap(normalizedPath) + linkPaths) {
            let components = path.components(separatedBy: pathSeparator)
            for depth in 1...components.count {
                let prefix = components.prefix(depth).joined(separator: pathSeparator)
                let key = prefix.lowercased()
                if displayPaths[key] == nil { displayPaths[key] = prefix }
            }
        }

        let byParent = Dictionary(grouping: displayPaths.keys) { key -> String? in
            guard let range = key.range(of: pathSeparator, options: .backwards) else { return nil }
            return String(key[..<range.lowerBound])
        }
        var result: [PlannedFolder] = []
        for (parentKey, childKeys) in byParent {
            for (offset, key) in childKeys.sorted().enumerated() {
                guard let display = displayPaths[key] else { continue }
                let name = display.components(separatedBy: pathSeparator).last ?? display
                result.append(PlannedFolder(key: key, snapshot: FolderSnapshot(
                    id: folderID(forPath: key),
                    name: name,
                    rank: Int64(offset + 1) * Ranking.spacing,
                    parentID: parentKey.map(folderID(forPath:)),
                    createdAt: date,
                    updatedAt: date)))
            }
        }
        return result.sorted { $0.key < $1.key }
    }

    /// Matches the 1.x rules: components are separated by exactly " / " (a
    /// bare "/" can appear inside imported bookmark folder names); trim each
    /// component and drop empties.
    static func normalizedPath(_ folder: String?) -> String? {
        guard let folder else { return nil }
        let components = folder
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: pathSeparator)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return components.isEmpty ? nil : components.joined(separator: pathSeparator)
    }
}

struct LegacyLink: Decodable {
    let id: UUID
    let title: String
    let url: String
    let order: Int
    let folder: String?
    let faviconData: Data?

    func isEquivalent(to other: LegacyLink) -> Bool {
        title == other.title && url == other.url && order == other.order
            && LegacyImportPlanner.normalizedPath(folder)?.lowercased()
            == LegacyImportPlanner.normalizedPath(other.folder)?.lowercased()
    }
}

private struct LossyLegacyLink: Decodable {
    let value: LegacyLink?

    init(from decoder: Decoder) throws {
        value = try? LegacyLink(from: decoder)
    }
}
