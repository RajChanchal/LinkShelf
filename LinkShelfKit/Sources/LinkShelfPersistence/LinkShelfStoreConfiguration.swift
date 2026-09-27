import Foundation
import SwiftData

/// Where the store lives and whether it syncs. Apps own the entitlements that
/// make each option valid; tests use `.inMemory` or a temporary file.
public struct LinkShelfStoreConfiguration: Sendable {
    public enum Location: Sendable {
        case inMemory
        case file(URL)
        /// Shared by a host app and its extensions on one device.
        case appGroup(String)
    }

    public enum Sync: Sendable {
        case localOnly
        /// Private database of the given CloudKit container.
        case cloudKit(containerIdentifier: String)
    }

    /// Kept stable across releases so the same store is reopened.
    public static let defaultName = "LinkShelf"

    public var name: String
    public var location: Location
    public var sync: Sync

    public init(name: String = defaultName, location: Location, sync: Sync = .localOnly) {
        self.name = name
        self.location = location
        self.sync = sync
    }

    public static let inMemory = LinkShelfStoreConfiguration(location: .inMemory)
}

public enum LinkShelfContainerFactory {
    public static var schema: Schema { Schema(versionedSchema: LinkShelfSchemaV1.self) }

    public static func makeContainer(_ configuration: LinkShelfStoreConfiguration) throws -> ModelContainer {
        let cloudKitDatabase: ModelConfiguration.CloudKitDatabase
        switch configuration.sync {
        case .localOnly: cloudKitDatabase = .none
        case .cloudKit(let identifier): cloudKitDatabase = .private(identifier)
        }

        let modelConfiguration: ModelConfiguration
        switch configuration.location {
        case .inMemory:
            modelConfiguration = ModelConfiguration(configuration.name, schema: schema,
                                                    isStoredInMemoryOnly: true,
                                                    groupContainer: .none,
                                                    cloudKitDatabase: cloudKitDatabase)
        case .file(let url):
            modelConfiguration = ModelConfiguration(configuration.name, schema: schema, url: url,
                                                    cloudKitDatabase: cloudKitDatabase)
        case .appGroup(let identifier):
            modelConfiguration = ModelConfiguration(configuration.name, schema: schema,
                                                    groupContainer: .identifier(identifier),
                                                    cloudKitDatabase: cloudKitDatabase)
        }

        return try ModelContainer(for: schema,
                                  migrationPlan: LinkShelfMigrationPlan.self,
                                  configurations: [modelConfiguration])
    }
}
