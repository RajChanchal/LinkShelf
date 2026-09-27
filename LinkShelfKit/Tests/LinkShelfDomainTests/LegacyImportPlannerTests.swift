import Foundation
import LinkShelfDomain
import Testing

struct LegacyImportPlannerTests {
    let date = Date(timeIntervalSince1970: 1_000)

    static func linksJSON(_ entries: [String]) -> Data {
        Data(("[" + entries.joined(separator: ",") + "]").utf8)
    }

    static func entry(_ id: String, title: String, url: String, order: Int, folder: String? = nil) -> String {
        let folderJSON = folder.map { ",\"folder\":\"\($0)\"" } ?? ""
        return "{\"id\":\"\(id)\",\"title\":\"\(title)\",\"url\":\"\(url)\",\"order\":\(order)\(folderJSON)}"
    }

    let idA = "00000000-0000-0000-0000-00000000000A"
    let idB = "00000000-0000-0000-0000-00000000000B"
    let idC = "00000000-0000-0000-0000-00000000000C"

    @Test func preservesIDsFoldersAndOrder() throws {
        let data = Self.linksJSON([
            Self.entry(idA, title: "Second", url: "https://a.com", order: 1, folder: "Work / Docs"),
            Self.entry(idB, title: "First", url: "https://b.com", order: 0, folder: "work / docs"),
            Self.entry(idC, title: "Loose", url: "https://c.com", order: 0)
        ])
        let plan = try LegacyImportPlanner.plan(
            from: LegacySource(linksData: data, folderPaths: ["Empty", "Work / News/Tech"]), importedAt: date)

        let names = Set(plan.folders.map(\.name))
        #expect(names == ["Empty", "Work", "Docs", "News/Tech"])
        let docs = try #require(plan.folders.first { $0.name == "Docs" })
        let work = try #require(plan.folders.first { $0.name == "Work" })
        #expect(docs.parentID == work.id)
        #expect(docs.id == LegacyImportPlanner.folderID(forPath: "WORK / DOCS"))

        let byID = Dictionary(uniqueKeysWithValues: plan.links.map { ($0.id.uuidString, $0) })
        let second = try #require(byID[idA])
        let first = try #require(byID[idB])
        #expect(second.folderID == docs.id && first.folderID == docs.id)
        #expect(first.rank < second.rank)
        #expect(byID[idC]?.folderID == nil)
        #expect(plan.issues.isEmpty)
    }

    @Test func planningIsDeterministic() throws {
        let source = LegacySource(linksData: Self.linksJSON([
            Self.entry(idA, title: "A", url: "https://a.com", order: 0, folder: "X / Y")
        ]), folderPaths: ["Z"])
        let first = try LegacyImportPlanner.plan(from: source, importedAt: date)
        let second = try LegacyImportPlanner.plan(from: source, importedAt: date)
        #expect(first.links == second.links)
        #expect(Set(first.folders) == Set(second.folders))
        #expect(first.sourceFingerprint == second.sourceFingerprint)
    }

    @Test func reportsCorruptRecordsAndRetainsInvalidURLs() throws {
        let data = Self.linksJSON([
            Self.entry(idA, title: "Bad", url: "javascript:alert(1)", order: 0),
            "{\"title\":\"no id\"}"
        ])
        let plan = try LegacyImportPlanner.plan(from: LegacySource(linksData: data, folderPaths: []), importedAt: date)
        #expect(plan.links.count == 1)
        #expect(plan.links[0].url == "javascript:alert(1)")
        #expect(plan.issues.contains(.corruptLinkRecord(index: 1)))
        #expect(plan.issues.contains(.invalidURL(plan.links[0].id)))
    }

    @Test func nonArrayPayloadIsNotAnEmptyImport() {
        #expect(throws: LinkShelfError.corruptLegacyLinks) {
            try LegacyImportPlanner.plan(from: LegacySource(linksData: Data("{}".utf8), folderPaths: []),
                                         importedAt: date)
        }
    }

    @Test func duplicateIDsAreDetected() throws {
        let data = Self.linksJSON([
            Self.entry(idA, title: "Same", url: "https://a.com", order: 0),
            Self.entry(idA, title: "Same", url: "https://a.com", order: 0),
            Self.entry(idA, title: "Different", url: "https://b.com", order: 1)
        ])
        let plan = try LegacyImportPlanner.plan(from: LegacySource(linksData: data, folderPaths: []), importedAt: date)
        #expect(plan.links.count == 2)
        let original = try #require(UUID(uuidString: idA))
        #expect(plan.issues.contains(.identicalDuplicateID(original)))
        #expect(plan.issues.contains { issue in
            if case .conflictingDuplicateID(original, _) = issue { return true }
            return false
        })
    }

    @Test func backupIsWrittenOnceAndRoundTrips() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = LegacySource(linksData: Data("[]".utf8), folderPaths: ["A"])
        let url = try source.writeBackup(to: directory)
        #expect(try source.writeBackup(to: directory) == url)
        #expect(try JSONDecoder().decode(LegacySource.self, from: Data(contentsOf: url)) == source)
    }
}
