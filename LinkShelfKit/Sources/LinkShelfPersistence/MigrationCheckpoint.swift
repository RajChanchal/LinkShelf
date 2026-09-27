import Foundation
import LinkShelfDomain

/// Durable, device-local migration progress. It lives beside the store in a
/// file rather than in the synced schema.
public struct MigrationCheckpoint: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case inProgress
        case verified
    }

    public static let currentVersion = 1

    public var migrationVersion: Int
    public var sourceFingerprint: String
    public var completedLinkBatches: Int
    public var status: Status

    public init(migrationVersion: Int = currentVersion, sourceFingerprint: String,
                completedLinkBatches: Int = 0, status: Status = .inProgress) {
        self.migrationVersion = migrationVersion
        self.sourceFingerprint = sourceFingerprint
        self.completedLinkBatches = completedLinkBatches
        self.status = status
    }
}

public struct MigrationCheckpointStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() throws -> MigrationCheckpoint? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try JSONDecoder().decode(MigrationCheckpoint.self, from: Data(contentsOf: fileURL))
        } catch {
            throw Self.failure(error)
        }
    }

    public func save(_ checkpoint: MigrationCheckpoint) throws {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(checkpoint).write(to: fileURL, options: .atomic)
        } catch {
            throw Self.failure(error)
        }
    }

    private static func failure(_ error: Error) -> LinkShelfError {
        let nsError = error as NSError
        return .persistenceFailed(.checkpoint, domain: nsError.domain, code: nsError.code)
    }
}

public enum LegacyMigrationOutcome: Equatable, Sendable {
    case alreadyComplete
    case migrated(links: Int, folders: Int, issues: [LegacyImportIssue])
}
