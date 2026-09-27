import Foundation

/// Immutable link value passed across actor and process boundaries.
public struct LinkSnapshot: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var url: String
    public var comparisonKey: String
    public var rank: Int64
    public var folderID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, title: String, url: String, comparisonKey: String, rank: Int64,
                folderID: UUID?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.url = url
        self.comparisonKey = comparisonKey
        self.rank = rank
        self.folderID = folderID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Immutable folder value. Identity is the UUID, never the name or path.
public struct FolderSnapshot: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var rank: Int64
    public var parentID: UUID?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, name: String, rank: Int64, parentID: UUID?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.rank = rank
        self.parentID = parentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Unvalidated user input from an add/edit form or share sheet.
public struct LinkDraft: Hashable, Sendable {
    public var title: String
    public var url: String
    public var folderID: UUID?

    public init(title: String, url: String, folderID: UUID? = nil) {
        self.title = title
        self.url = url
        self.folderID = folderID
    }

    public func validated() throws -> ValidatedLink {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw LinkShelfError.emptyTitle }
        return ValidatedLink(title: title, url: try LinkURL(validating: url), folderID: folderID)
    }
}

public struct ValidatedLink: Hashable, Sendable {
    public let title: String
    public let url: LinkURL
    public let folderID: UUID?
}

public enum FolderName {
    /// Separator used when a folder's ancestry is displayed or typed as a path.
    public static let pathSeparator = " / "

    /// Trims the name and rejects empty names, newlines, and the path
    /// separator. A bare `/` is allowed, as in imported bookmark folders.
    public static func validate(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(pathSeparator),
              trimmed.rangeOfCharacter(from: .newlines) == nil else {
            throw LinkShelfError.invalidFolderName
        }
        return trimmed
    }
}
