import Foundation
import LinkShelfDomain
import Testing

struct RankingTests {
    let ids = (0..<4).map { DeterministicUUID.make(name: "rank-\($0)") }

    @Test func insertingBetweenTouchesOnlyTheMovedItem() {
        let siblings = [RankedItem(id: ids[0], rank: 100), RankedItem(id: ids[1], rank: 200)]
        #expect(Ranking.changes(placing: ids[2], at: 1, among: siblings) == [ids[2]: 150])
        #expect(Ranking.changes(placing: ids[2], at: 0, among: siblings) == [ids[2]: 50])
        #expect(Ranking.changes(placing: ids[2], at: 9, among: siblings) == [ids[2]: 200 + Ranking.spacing])
        #expect(Ranking.changes(placing: ids[2], at: 0, among: []) == [ids[2]: Ranking.spacing])
    }

    @Test func exhaustedGapRebalancesDeterministically() {
        let siblings = [RankedItem(id: ids[0], rank: 1), RankedItem(id: ids[1], rank: 2)]
        let changes = Ranking.changes(placing: ids[2], at: 1, among: siblings)
        let result = Ranking.sorted(siblings.map { RankedItem(id: $0.id, rank: changes[$0.id] ?? $0.rank) }
                                    + [RankedItem(id: ids[2], rank: changes[ids[2]] ?? 0)])
        #expect(result.map(\.id) == [ids[0], ids[2], ids[1]])
    }

    @Test func equalRanksBreakTiesByUUID() {
        let items = [RankedItem(id: ids[1], rank: 5), RankedItem(id: ids[0], rank: 5)]
        let expected = [ids[0], ids[1]].sorted { $0.uuidString < $1.uuidString }
        #expect(Ranking.sorted(items).map(\.id) == expected)
    }

    @Test func movingWithinSameContainerIgnoresItsOldPosition() {
        let siblings = [RankedItem(id: ids[0], rank: 100), RankedItem(id: ids[1], rank: 200),
                        RankedItem(id: ids[2], rank: 300)]
        #expect(Ranking.changes(placing: ids[0], at: 2, among: siblings) == [ids[0]: 300 + Ranking.spacing])
    }
}

struct FolderTreeTests {
    let date = Date(timeIntervalSince1970: 0)

    func folder(_ name: String, parent: String?) -> FolderSnapshot {
        FolderSnapshot(id: DeterministicUUID.make(name: name), name: name, rank: 1,
                       parentID: parent.map { DeterministicUUID.make(name: $0) },
                       createdAt: date, updatedAt: date)
    }

    func id(_ name: String) -> UUID { DeterministicUUID.make(name: name) }

    @Test func detectsCyclesAndDescendants() {
        let tree = FolderTree([folder("a", parent: nil), folder("b", parent: "a"), folder("c", parent: "b")])
        #expect(tree.wouldCreateCycle(moving: id("a"), under: id("c")))
        #expect(tree.wouldCreateCycle(moving: id("a"), under: id("a")))
        #expect(!tree.wouldCreateCycle(moving: id("c"), under: nil))
        #expect(tree.descendants(of: id("a")) == [id("b"), id("c")])
        #expect(tree.path(of: id("c")).map(\.name) == ["a", "b", "c"])
    }

    @Test func orphanedFoldersAppearAtRoot() {
        let tree = FolderTree([folder("child", parent: "missing")])
        #expect(tree.children(of: nil).map(\.name) == ["child"])
    }

    @Test func repairsRemoteCyclesDeterministically() {
        let tree = FolderTree([folder("x", parent: "y"), folder("y", parent: "x"), folder("z", parent: "x")])
        let repairs = tree.cycleRepairs()
        #expect(repairs == [[id("x"), id("y")].min { $0.uuidString < $1.uuidString }])
        #expect(FolderTree([folder("a", parent: nil)]).cycleRepairs().isEmpty)
    }

    @Test func siblingNamesAreCaseInsensitive() {
        let tree = FolderTree([folder("Work", parent: nil)])
        #expect(tree.hasSibling(named: "work", under: nil))
        #expect(!tree.hasSibling(named: "work", under: nil, excluding: id("Work")))
    }
}

struct DuplicateReconcilerTests {
    func link(_ name: String, url: String, title: String = "T", folder: UUID? = nil) -> LinkSnapshot {
        LinkSnapshot(id: DeterministicUUID.make(name: name), title: title, url: url,
                     comparisonKey: LinkURL.comparisonKey(forStored: url), rank: 1, folderID: folder,
                     createdAt: .distantPast, updatedAt: .distantPast)
    }

    @Test func exactDuplicatesKeepLowestUUID() {
        let links = [link("1", url: "https://a.com"), link("2", url: "https://A.com"), link("3", url: "https://a.com")]
        let resolution = DuplicateReconciler.resolve(links)
        let sorted = links.map(\.id).sorted { $0.uuidString < $1.uuidString }
        #expect(resolution.redundantIDs == Array(sorted.dropFirst()))
        #expect(resolution.reviewGroups.isEmpty)
        #expect(DuplicateReconciler.resolve(links.reversed()) == resolution)
    }

    @Test func divergentDuplicatesAreKeptForReview() {
        let links = [link("1", url: "https://a.com", title: "One"), link("2", url: "https://a.com", title: "Two")]
        let resolution = DuplicateReconciler.resolve(links)
        #expect(resolution.redundantIDs.isEmpty)
        #expect(resolution.reviewGroups == [links.map(\.id).sorted { $0.uuidString < $1.uuidString }])
    }
}
