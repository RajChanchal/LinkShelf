import Foundation

public struct DuplicateResolution: Equatable, Sendable {
    /// Exact semantic duplicates that can be removed without losing anything.
    public var redundantIDs: [UUID]
    /// Links sharing a URL but with divergent titles or folders. They are kept
    /// and surfaced to the person for review.
    public var reviewGroups: [[UUID]]

    public init(redundantIDs: [UUID] = [], reviewGroups: [[UUID]] = []) {
        self.redundantIDs = redundantIDs
        self.reviewGroups = reviewGroups
    }
}

/// Deterministic duplicate reconciliation (FR-09). Running it repeatedly or on
/// different devices with the same records yields the same result.
public enum DuplicateReconciler {
    public static func resolve(_ links: [LinkSnapshot]) -> DuplicateResolution {
        var resolution = DuplicateResolution()
        let byURL = Dictionary(grouping: links, by: \.comparisonKey)

        for key in byURL.keys.sorted() {
            guard let group = byURL[key], group.count > 1 else { continue }
            let exact = Dictionary(grouping: group) { ExactKey(link: $0) }
            var survivors: [UUID] = []
            for members in exact.values {
                let ordered = members.map(\.id).sorted { $0.uuidString < $1.uuidString }
                survivors.append(ordered[0])
                resolution.redundantIDs.append(contentsOf: ordered.dropFirst())
            }
            if survivors.count > 1 {
                resolution.reviewGroups.append(survivors.sorted { $0.uuidString < $1.uuidString })
            }
        }
        resolution.redundantIDs.sort { $0.uuidString < $1.uuidString }
        return resolution
    }

    private struct ExactKey: Hashable {
        let title: String
        let folderID: UUID?

        init(link: LinkSnapshot) {
            title = link.title.trimmingCharacters(in: .whitespacesAndNewlines)
            folderID = link.folderID
        }
    }
}
