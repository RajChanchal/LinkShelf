import CoreFoundation
import Foundation
import LinkShelfDomain

/// The on-device storage contract shared by a host app and its extensions:
/// one SwiftData store, migration checkpoint, and legacy backup location in
/// the App Group container.
public struct LinkShelfAppGroupStorage: Sendable {
    public enum MigrationState: Equatable, Sendable {
        /// Safe to read and write the SwiftData store.
        case ready
        /// Legacy data exists that the host app has not finished importing.
        /// Extensions must not write until the app completes the migration.
        case pending
    }

    public let appGroupID: String
    public let sync: LinkShelfStoreConfiguration.Sync

    public init(appGroupID: String = LegacySource.appGroupID, sync: LinkShelfStoreConfiguration.Sync = .localOnly) {
        self.appGroupID = appGroupID
        self.sync = sync
    }

    public var storeConfiguration: LinkShelfStoreConfiguration {
        LinkShelfStoreConfiguration(location: .appGroup(appGroupID), sync: sync)
    }

    public func makeRepository() throws -> LinkRepository {
        LinkRepository(modelContainer: try LinkShelfContainerFactory.makeContainer(storeConfiguration))
    }

    /// Device-local support files, outside the synced store.
    public var supportDirectory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("Library/Application Support/LinkShelf", isDirectory: true)
    }

    public var checkpoints: MigrationCheckpointStore? {
        supportDirectory.map { MigrationCheckpointStore(fileURL: $0.appendingPathComponent("legacy-migration.json")) }
    }

    public var backupDirectory: URL? {
        supportDirectory?.appendingPathComponent("Legacy Backups", isDirectory: true)
    }

    public func migrationState() -> MigrationState {
        if (try? checkpoints?.load())??.status == .verified { return .ready }
        return LegacySource.read(appGroupID: appGroupID).isEmpty ? .ready : .pending
    }

    /// Imports the 1.x UserDefaults collection once. The untouched source is
    /// backed up first; once a migration is verified it is never re-run, even
    /// if an older app version later changes the legacy data.
    public func migrateLegacyDataIfNeeded(into repository: LinkRepository,
                                          now: Date = .now) async throws -> LegacyMigrationReport {
        guard let checkpoints, let backupDirectory else {
            throw LinkShelfError.persistenceFailed(.checkpoint, domain: NSCocoaErrorDomain,
                                                   code: CocoaError.fileNoSuchFile.rawValue)
        }
        if try checkpoints.load()?.status == .verified {
            return LegacyMigrationReport(outcome: .alreadyComplete, faviconsByURL: [:])
        }

        let source = LegacySource.read(appGroupID: appGroupID)
        if source.isEmpty {
            try checkpoints.save(MigrationCheckpoint(sourceFingerprint: source.fingerprint, status: .verified))
            return LegacyMigrationReport(outcome: .migrated(links: 0, folders: 0, issues: []), faviconsByURL: [:])
        }

        try source.writeBackup(to: backupDirectory)
        let plan = try LegacyImportPlanner.plan(from: source, importedAt: now)
        let outcome = try await repository.importLegacy(plan, checkpoints: checkpoints)
        var favicons: [String: Data] = [:]
        for link in plan.links {
            if let data = plan.favicons[link.id] { favicons[link.url] = data }
        }
        return LegacyMigrationReport(outcome: outcome, faviconsByURL: favicons)
    }
}

public struct LegacyMigrationReport: Sendable {
    public let outcome: LegacyMigrationOutcome
    /// Legacy favicon bytes keyed by link URL, for seeding the app's cache.
    public let faviconsByURL: [String: Data]
}

/// Cross-process hint that the shared store changed. It carries no data and
/// is not a durable ledger; observers refetch when they receive it.
public enum LinkShelfChangeSignal {
    public static let name = "com.chanchalgeek.LinkShelf.linksChanged"

    public static func post() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(name as CFString), nil, nil, true)
    }
}
