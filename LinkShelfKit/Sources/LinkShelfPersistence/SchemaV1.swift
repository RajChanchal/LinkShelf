import Foundation
import SwiftData

/// Schema version 1. CloudKit-compatible: every attribute has a default,
/// relationships are optional with explicit inverses, and there are no unique
/// constraints or deny delete rules. Uniqueness and recursive deletion are
/// enforced by `LinkRepository`, not by the store.
public enum LinkShelfSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [LinkRecord.self, FolderRecord.self]
    }

    @Model
    public final class LinkRecord {
        public var uuid = UUID()
        public var title = ""
        public var urlString = ""
        public var comparisonKey = ""
        public var rank: Int64 = 0
        public var createdAt = Date.distantPast
        public var updatedAt = Date.distantPast
        public var folder: FolderRecord?

        public init(uuid: UUID, title: String, urlString: String, comparisonKey: String,
                    rank: Int64, createdAt: Date, updatedAt: Date) {
            self.uuid = uuid
            self.title = title
            self.urlString = urlString
            self.comparisonKey = comparisonKey
            self.rank = rank
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    @Model
    public final class FolderRecord {
        public var uuid = UUID()
        public var name = ""
        public var rank: Int64 = 0
        public var createdAt = Date.distantPast
        public var updatedAt = Date.distantPast
        public var parent: FolderRecord?
        @Relationship(deleteRule: .nullify, inverse: \FolderRecord.parent)
        public var children: [FolderRecord]? = []
        @Relationship(deleteRule: .nullify, inverse: \LinkRecord.folder)
        public var links: [LinkRecord]? = []

        public init(uuid: UUID, name: String, rank: Int64, createdAt: Date, updatedAt: Date) {
            self.uuid = uuid
            self.name = name
            self.rank = rank
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }
}

public typealias LinkRecord = LinkShelfSchemaV1.LinkRecord
public typealias FolderRecord = LinkShelfSchemaV1.FolderRecord

public enum LinkShelfMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [LinkShelfSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
