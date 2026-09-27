import Foundation
import LinkShelfDomain
import SwiftData

public enum LinkScope: Hashable, Sendable {
    case all
    case unfiled
    case folder(UUID)
}

/// Background persistence for links and folders. Models and the context stay
/// inside this actor; callers receive `Sendable` snapshots. Every mutation
/// updates individual records and reports save failures explicitly.
@ModelActor
public actor LinkRepository {
    // MARK: Links

    public func links(in scope: LinkScope = .all, limit: Int? = nil) throws -> [LinkSnapshot] {
        let records: [LinkRecord]
        switch scope {
        case .all:
            records = try fetch(FetchDescriptor<LinkRecord>(sortBy: [SortDescriptor(\.rank)]))
        case .unfiled:
            records = try fetch(FetchDescriptor<LinkRecord>(predicate: #Predicate { $0.folder == nil },
                                                            sortBy: [SortDescriptor(\.rank)]))
        case .folder(let id):
            records = try requireFolder(id).links ?? []
        }
        let ordered = Self.ordered(records.map(LinkSnapshot.init))
        return limit.map { Array(ordered.prefix($0)) } ?? ordered
    }

    public func link(id: UUID) throws -> LinkSnapshot? {
        try linkRecords(id).first.map(LinkSnapshot.init)
    }

    /// Case- and diacritic-insensitive search over title, URL, and folder name.
    public func search(_ query: String, limit: Int = 200) throws -> [LinkSnapshot] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return try links(limit: limit) }

        var matchDescriptor = FetchDescriptor<LinkRecord>(predicate: #Predicate {
            $0.title.localizedStandardContains(term) || $0.urlString.localizedStandardContains(term)
        })
        matchDescriptor.fetchLimit = limit
        var found = Dictionary(try fetch(matchDescriptor).map { ($0.uuid, LinkSnapshot($0)) },
                               uniquingKeysWith: { first, _ in first })

        let folders = try fetch(FetchDescriptor<FolderRecord>(predicate: #Predicate {
            $0.name.localizedStandardContains(term)
        }))
        for folder in folders {
            for record in folder.links ?? [] where found.count < limit {
                found[record.uuid] = found[record.uuid] ?? LinkSnapshot(record)
            }
        }

        return found.values.sorted {
            let order = $0.title.localizedStandardCompare($1.title)
            return order == .orderedSame ? $0.id.uuidString < $1.id.uuidString : order == .orderedAscending
        }
    }

    /// Lets share sheets warn about a duplicate before saving.
    public func existingLink(matching url: String) throws -> LinkSnapshot? {
        let key = try LinkURL(validating: url).comparisonKey
        return try linkRecords(comparisonKey: key).first.map(LinkSnapshot.init)
    }

    @discardableResult
    public func addLink(_ draft: LinkDraft, allowingDuplicate: Bool = false, now: Date = .now) throws -> LinkSnapshot {
        let valid = try draft.validated()
        if !allowingDuplicate, let existing = try linkRecords(comparisonKey: valid.url.comparisonKey).first {
            throw LinkShelfError.duplicateLink(existingID: existing.uuid)
        }
        let folder = try valid.folderID.map(requireFolder)
        let record = LinkRecord(uuid: UUID(), title: valid.title, urlString: valid.url.string,
                                comparisonKey: valid.url.comparisonKey, rank: 0,
                                createdAt: now, updatedAt: now)
        modelContext.insert(record)
        try place(record, in: folder, at: Int.max)
        try save()
        return LinkSnapshot(record)
    }

    @discardableResult
    public func updateLink(id: UUID, with draft: LinkDraft, allowingDuplicate: Bool = false,
                           now: Date = .now) throws -> LinkSnapshot {
        let valid = try draft.validated()
        guard let record = try linkRecords(id).first else { throw LinkShelfError.linkNotFound(id) }
        if !allowingDuplicate,
           let existing = try linkRecords(comparisonKey: valid.url.comparisonKey).first(where: { $0.uuid != id }) {
            throw LinkShelfError.duplicateLink(existingID: existing.uuid)
        }
        let folder = try valid.folderID.map(requireFolder)
        record.title = valid.title
        record.urlString = valid.url.string
        record.comparisonKey = valid.url.comparisonKey
        if record.folder?.uuid != folder?.uuid {
            try place(record, in: folder, at: Int.max)
        }
        record.updatedAt = now
        try save()
        return LinkSnapshot(record)
    }

    /// Moves a link to `index` within `folderID` (nil means unfiled).
    public func moveLink(id: UUID, toFolder folderID: UUID?, at index: Int, now: Date = .now) throws {
        guard let record = try linkRecords(id).first else { throw LinkShelfError.linkNotFound(id) }
        try place(record, in: folderID.map(requireFolder), at: index)
        record.updatedAt = now
        try save()
    }

    /// Rewrites the order of a container's links to match `orderedIDs`, for
    /// multi-item moves. Links not listed keep their relative order after them.
    public func reorderLinks(inFolder folderID: UUID?, orderedIDs: [UUID], now: Date = .now) throws {
        let current = try links(in: folderID.map(LinkScope.folder) ?? .unfiled)
        let listed = orderedIDs.filter { id in current.contains { $0.id == id } }
        let finalOrder = listed + current.map(\.id).filter { !listed.contains($0) }
        let ranks = Dictionary(current.map { ($0.id, $0.rank) }, uniquingKeysWith: { first, _ in first })
        for (offset, id) in finalOrder.enumerated() {
            let rank = Int64(offset + 1) * Ranking.spacing
            guard ranks[id] != rank else { continue }
            for record in try linkRecords(id) {
                record.rank = rank
                record.updatedAt = now
            }
        }
        try save()
    }

    /// Re-inserts a deleted link with its original identity, for undo. The
    /// original folder is used when it still exists; otherwise it is unfiled.
    @discardableResult
    public func restoreLink(_ snapshot: LinkSnapshot) throws -> LinkSnapshot {
        if let existing = try linkRecords(snapshot.id).first { return LinkSnapshot(existing) }
        let record = LinkRecord(uuid: snapshot.id, title: snapshot.title, urlString: snapshot.url,
                                comparisonKey: snapshot.comparisonKey, rank: snapshot.rank,
                                createdAt: snapshot.createdAt, updatedAt: snapshot.updatedAt)
        modelContext.insert(record)
        record.folder = try snapshot.folderID.flatMap { try folderRecords($0).first }
        try save()
        return LinkSnapshot(record)
    }

    public func deleteLinks(ids: Set<UUID>) throws {
        for id in ids {
            for record in try linkRecords(id) { modelContext.delete(record) }
        }
        try save()
    }

    // MARK: Folders

    public func folders() throws -> [FolderSnapshot] {
        try fetch(FetchDescriptor<FolderRecord>(sortBy: [SortDescriptor(\.rank)])).map(FolderSnapshot.init)
    }

    @discardableResult
    public func createFolder(named name: String, inside parentID: UUID?, now: Date = .now) throws -> FolderSnapshot {
        let name = try FolderName.validate(name)
        let parent = try parentID.map(requireFolder)
        let tree = FolderTree(try folders())
        guard !tree.hasSibling(named: name, under: parentID) else { throw LinkShelfError.duplicateFolderName }

        let siblings = tree.children(of: parentID).map { RankedItem(id: $0.id, rank: $0.rank) }
        let record = FolderRecord(uuid: UUID(), name: name, rank: 0, createdAt: now, updatedAt: now)
        modelContext.insert(record)
        record.parent = parent
        try applyFolderRanks(Ranking.changes(placing: record.uuid, at: siblings.count, among: siblings))
        try save()
        return FolderSnapshot(record)
    }

    /// Renames in place; identity and contents are unchanged.
    public func renameFolder(id: UUID, to name: String, now: Date = .now) throws {
        try updateFolder(id: id, name: name, parentID: try requireFolder(id).parent?.uuid, now: now)
    }

    public func moveFolder(id: UUID, inside parentID: UUID?, now: Date = .now) throws {
        try updateFolder(id: id, name: try requireFolder(id).name, parentID: parentID, now: now)
    }

    /// Renames and/or moves a folder in one save. Identity, links, and
    /// descendants are preserved; cycles and sibling name clashes are rejected.
    public func updateFolder(id: UUID, name: String, parentID: UUID?, now: Date = .now) throws {
        let name = try FolderName.validate(name)
        let record = try requireFolder(id)
        let parent = try parentID.map(requireFolder)
        let tree = FolderTree(try folders())
        guard !tree.wouldCreateCycle(moving: id, under: parentID) else { throw LinkShelfError.folderCycle }
        guard !tree.hasSibling(named: name, under: parentID, excluding: id) else {
            throw LinkShelfError.duplicateFolderName
        }
        if record.parent?.uuid != parentID {
            let siblings = tree.children(of: parentID).map { RankedItem(id: $0.id, rank: $0.rank) }
            record.parent = parent
            try applyFolderRanks(Ranking.changes(placing: id, at: siblings.count, among: siblings))
        }
        record.name = name
        record.updatedAt = now
        try save()
    }

    /// Deletes the folder, its descendants, and every link they contain. The
    /// caller confirms with the person first.
    public func deleteFolder(id: UUID) throws {
        _ = try requireFolder(id)
        let doomed = FolderTree(try folders()).descendants(of: id).union([id])
        for folderID in doomed {
            for record in try folderRecords(folderID) {
                for link in record.links ?? [] { modelContext.delete(link) }
                modelContext.delete(record)
            }
        }
        try save()
    }

    /// Detaches folders that a remote change left in a cycle. Returns the
    /// detached folder IDs so the app can show a recovery notice.
    public func repairFolderCycles(now: Date = .now) throws -> [UUID] {
        let detached = FolderTree(try folders()).cycleRepairs()
        guard !detached.isEmpty else { return [] }
        for id in detached {
            let record = try requireFolder(id)
            record.parent = nil
            record.updatedAt = now
        }
        try save()
        return detached
    }

    // MARK: Duplicates

    /// Removes exact duplicates (keeping the lowest UUID) and returns divergent
    /// groups for review. Records that share a UUID but differ are reassigned a
    /// deterministic new UUID first so they can be reasoned about separately.
    public func reconcileDuplicates() throws -> DuplicateResolution {
        let all = try fetch(FetchDescriptor<LinkRecord>())
        for (id, records) in Dictionary(grouping: all, by: \.uuid) where records.count > 1 {
            var kept: [LinkSnapshot] = []
            for record in records {
                let snapshot = LinkSnapshot(record)
                if kept.contains(where: { $0.hasSameContent(as: snapshot) }) {
                    modelContext.delete(record)
                } else {
                    if !kept.isEmpty {
                        record.uuid = DeterministicUUID.make(
                            name: "uuid-collision:\(id.uuidString):\(record.comparisonKey):\(record.title)")
                    }
                    kept.append(snapshot)
                }
            }
        }
        try save()

        let resolution = DuplicateReconciler.resolve(try links())
        if !resolution.redundantIDs.isEmpty {
            try deleteLinks(ids: Set(resolution.redundantIDs))
        }
        return resolution
    }

    // MARK: Legacy migration

    /// Imports a 1.x collection in resumable batches, verifies it, and only then
    /// marks the checkpoint verified. Safe to call again after a crash.
    public func importLegacy(_ plan: LegacyImportPlan, checkpoints: MigrationCheckpointStore,
                             batchSize: Int = 250) throws -> LegacyMigrationOutcome {
        var checkpoint = try checkpoints.load()
        if let checkpoint, checkpoint.status == .verified, checkpoint.sourceFingerprint == plan.sourceFingerprint {
            return .alreadyComplete
        }
        if checkpoint?.sourceFingerprint != plan.sourceFingerprint
            || checkpoint?.migrationVersion != MigrationCheckpoint.currentVersion {
            checkpoint = MigrationCheckpoint(sourceFingerprint: plan.sourceFingerprint)
        }
        guard var progress = checkpoint else { return .alreadyComplete }
        try checkpoints.save(progress)

        var foldersByID: [UUID: FolderRecord] = [:]
        for folder in plan.folders {
            foldersByID[folder.id] = try upsertFolder(folder)
        }
        for folder in plan.folders {
            foldersByID[folder.id]?.parent = folder.parentID.flatMap { foldersByID[$0] }
        }
        try save()

        let size = max(batchSize, 1)
        let batches = stride(from: 0, to: plan.links.count, by: size).map {
            plan.links[$0..<min($0 + size, plan.links.count)]
        }
        for (index, batch) in batches.enumerated() where index >= progress.completedLinkBatches {
            for link in batch {
                try upsertLink(link, folder: link.folderID.flatMap { foldersByID[$0] })
            }
            try save()
            progress.completedLinkBatches = index + 1
            try checkpoints.save(progress)
        }

        try verifyImport(plan)
        progress.status = .verified
        try checkpoints.save(progress)
        return .migrated(links: plan.links.count, folders: plan.folders.count, issues: plan.issues)
    }

    private func verifyImport(_ plan: LegacyImportPlan) throws {
        let folders = Dictionary(grouping: try fetch(FetchDescriptor<FolderRecord>()), by: \.uuid)
        for expected in plan.folders {
            guard let matches = folders[expected.id], matches.count == 1,
                  matches[0].name == expected.name, matches[0].parent?.uuid == expected.parentID else {
                throw LinkShelfError.migrationVerificationFailed
            }
        }
        let links = Dictionary(grouping: try fetch(FetchDescriptor<LinkRecord>()), by: \.uuid)
        for expected in plan.links {
            guard let matches = links[expected.id], matches.count == 1,
                  LinkSnapshot(matches[0]).hasSameContent(as: expected),
                  matches[0].rank == expected.rank else {
                throw LinkShelfError.migrationVerificationFailed
            }
        }
    }

    private func upsertFolder(_ snapshot: FolderSnapshot) throws -> FolderRecord {
        if let existing = try folderRecords(snapshot.id).first {
            existing.name = snapshot.name
            existing.rank = snapshot.rank
            return existing
        }
        let record = FolderRecord(uuid: snapshot.id, name: snapshot.name, rank: snapshot.rank,
                                  createdAt: snapshot.createdAt, updatedAt: snapshot.updatedAt)
        modelContext.insert(record)
        return record
    }

    private func upsertLink(_ snapshot: LinkSnapshot, folder: FolderRecord?) throws {
        let record: LinkRecord
        if let existing = try linkRecords(snapshot.id).first {
            record = existing
        } else {
            record = LinkRecord(uuid: snapshot.id, title: "", urlString: "", comparisonKey: "", rank: 0,
                                createdAt: snapshot.createdAt, updatedAt: snapshot.updatedAt)
            modelContext.insert(record)
        }
        record.title = snapshot.title
        record.urlString = snapshot.url
        record.comparisonKey = snapshot.comparisonKey
        record.rank = snapshot.rank
        record.folder = folder
    }

    // MARK: Helpers

    private func place(_ record: LinkRecord, in folder: FolderRecord?, at index: Int) throws {
        let siblingRecords: [LinkRecord]
        if let folder {
            siblingRecords = folder.links ?? []
        } else {
            siblingRecords = try fetch(FetchDescriptor<LinkRecord>(predicate: #Predicate { $0.folder == nil }))
        }
        let siblings = siblingRecords
            .filter { $0.uuid != record.uuid }
            .map { RankedItem(id: $0.uuid, rank: $0.rank) }
        let changes = Ranking.changes(placing: record.uuid, at: index, among: siblings)
        record.folder = folder
        for sibling in siblingRecords + [record] {
            if let rank = changes[sibling.uuid] { sibling.rank = rank }
        }
    }

    private func applyFolderRanks(_ changes: [UUID: Int64]) throws {
        for (id, rank) in changes {
            for record in try folderRecords(id) { record.rank = rank }
        }
    }

    private func requireFolder(_ id: UUID) throws -> FolderRecord {
        guard let record = try folderRecords(id).first else { throw LinkShelfError.folderNotFound(id) }
        return record
    }

    private func folderRecords(_ id: UUID) throws -> [FolderRecord] {
        try fetch(FetchDescriptor<FolderRecord>(predicate: #Predicate { $0.uuid == id }))
    }

    private func linkRecords(_ id: UUID) throws -> [LinkRecord] {
        try fetch(FetchDescriptor<LinkRecord>(predicate: #Predicate { $0.uuid == id }))
    }

    private func linkRecords(comparisonKey key: String) throws -> [LinkRecord] {
        try fetch(FetchDescriptor<LinkRecord>(predicate: #Predicate { $0.comparisonKey == key }))
    }

    private func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) throws -> [Model] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            let nsError = error as NSError
            throw LinkShelfError.persistenceFailed(.fetch, domain: nsError.domain, code: nsError.code)
        }
    }

    private func save() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            let nsError = error as NSError
            throw LinkShelfError.persistenceFailed(.save, domain: nsError.domain, code: nsError.code)
        }
    }

    private static func ordered(_ links: [LinkSnapshot]) -> [LinkSnapshot] {
        links.sorted { Ranking.precedes(RankedItem(id: $0.id, rank: $0.rank), RankedItem(id: $1.id, rank: $1.rank)) }
    }
}

extension LinkSnapshot {
    init(_ record: LinkRecord) {
        self.init(id: record.uuid, title: record.title, url: record.urlString,
                  comparisonKey: record.comparisonKey, rank: record.rank, folderID: record.folder?.uuid,
                  createdAt: record.createdAt, updatedAt: record.updatedAt)
    }

    func hasSameContent(as other: LinkSnapshot) -> Bool {
        title == other.title && url == other.url && folderID == other.folderID
    }
}

extension FolderSnapshot {
    init(_ record: FolderRecord) {
        self.init(id: record.uuid, name: record.name, rank: record.rank, parentID: record.parent?.uuid,
                  createdAt: record.createdAt, updatedAt: record.updatedAt)
    }
}
