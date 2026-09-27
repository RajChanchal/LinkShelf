import Foundation

/// Read-only view of folder relationships (FR-03). It tolerates sync states
/// where a parent is missing or a remote change introduced a cycle.
public struct FolderTree: Sendable {
    public let folders: [UUID: FolderSnapshot]

    public init(_ folders: [FolderSnapshot]) {
        self.folders = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Children in display order. Passing `nil` returns root folders, including
    /// folders whose parent has not arrived yet, so they are never hidden.
    public func children(of parentID: UUID?) -> [FolderSnapshot] {
        folders.values
            .filter { folder in
                guard let parentID else { return isEffectivelyRoot(folder) }
                return folder.parentID == parentID
            }
            .sorted { Ranking.precedes(RankedItem(id: $0.id, rank: $0.rank), RankedItem(id: $1.id, rank: $1.rank)) }
    }

    public func isEffectivelyRoot(_ folder: FolderSnapshot) -> Bool {
        guard let parentID = folder.parentID else { return true }
        return folders[parentID] == nil
    }

    public func descendants(of id: UUID) -> Set<UUID> {
        var result: Set<UUID> = []
        var pending = [id]
        while let current = pending.popLast() {
            for child in folders.values where child.parentID == current && result.insert(child.id).inserted {
                pending.append(child.id)
            }
        }
        result.remove(id)
        return result
    }

    public func wouldCreateCycle(moving id: UUID, under parentID: UUID?) -> Bool {
        var visited: Set<UUID> = []
        var current = parentID
        while let candidate = current, visited.insert(candidate).inserted {
            if candidate == id { return true }
            current = folders[candidate]?.parentID
        }
        return false
    }

    /// Root-first ancestry, stopping at a missing parent or an existing cycle.
    public func path(of id: UUID) -> [FolderSnapshot] {
        var result: [FolderSnapshot] = []
        var visited: Set<UUID> = []
        var current: UUID? = id
        while let candidate = current, visited.insert(candidate).inserted, let folder = folders[candidate] {
            result.append(folder)
            current = folder.parentID
        }
        return result.reversed()
    }

    public func hasSibling(named name: String, under parentID: UUID?, excluding id: UUID? = nil) -> Bool {
        children(of: parentID).contains {
            $0.id != id && $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
    }

    /// Folders to detach to the root so no cycles remain. Each cycle detaches
    /// its member with the lowest UUID, so every device repairs identically.
    public func cycleRepairs() -> [UUID] {
        var parents = folders.mapValues(\.parentID)
        var detached: [UUID] = []
        let orderedIDs = folders.keys.sorted { $0.uuidString < $1.uuidString }
        while let cycle = Self.firstCycle(in: parents, orderedIDs: orderedIDs),
              let victim = cycle.min(by: { $0.uuidString < $1.uuidString }) {
            parents[victim] = .some(nil)
            detached.append(victim)
        }
        return detached
    }

    private static func firstCycle(in parents: [UUID: UUID?], orderedIDs: [UUID]) -> [UUID]? {
        for start in orderedIDs {
            var chain: [UUID] = []
            var current: UUID? = start
            while let candidate = current {
                if let index = chain.firstIndex(of: candidate) {
                    return Array(chain[index...])
                }
                chain.append(candidate)
                current = parents[candidate].flatMap { $0 }
            }
        }
        return nil
    }
}
