import Foundation

/// Typed failures returned by the package. Apps map these to localized text;
/// the package never produces user-facing strings.
public enum LinkShelfError: Error, Equatable, Sendable {
    case emptyTitle
    case emptyURL
    case malformedURL
    case unsupportedScheme(String)
    case missingHost
    case embeddedCredentials
    case invalidFolderName
    case duplicateLink(existingID: UUID)
    case duplicateFolderName
    case linkNotFound(UUID)
    case folderNotFound(UUID)
    case folderCycle
    case corruptLegacyLinks
    case migrationVerificationFailed
    /// Carries only the error domain and code so that user content never
    /// leaks into diagnostics.
    case persistenceFailed(PersistenceOperation, domain: String, code: Int)
}

public enum PersistenceOperation: String, Sendable {
    case fetch
    case save
    case checkpoint
    case backup
}
