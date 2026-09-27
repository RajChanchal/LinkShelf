import Foundation
import LinkShelfDomain
import LinkShelfPersistence
import Testing

struct LegacyMigrationTests {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    var checkpoints: MigrationCheckpointStore {
        MigrationCheckpointStore(fileURL: directory.appendingPathComponent("migration.json"))
    }

    func makePlan(linkCount: Int = 5) throws -> LegacyImportPlan {
        let entries = (0..<linkCount).map { index in
            let id = DeterministicUUID.make(name: "legacy-link-\(index)").uuidString
            let folder = index.isMultiple(of: 2) ? ",\"folder\":\"Work / Docs\"" : ""
            return "{\"id\":\"\(id)\",\"title\":\"Link \(index)\",\"url\":\"https://e.com/\(index)\","
                + "\"order\":\(index)\(folder)}"
        }
        let source = LegacySource(linksData: Data(("[" + entries.joined(separator: ",") + "]").utf8),
                                  folderPaths: ["Empty"])
        return try LegacyImportPlanner.plan(from: source, importedAt: Date(timeIntervalSince1970: 0))
    }

    @Test func importsVerifiesAndDoesNotRepeat() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try makeRepository()
        let plan = try makePlan()

        let outcome = try await repository.importLegacy(plan, checkpoints: checkpoints, batchSize: 2)
        #expect(outcome == .migrated(links: 5, folders: 3, issues: []))
        #expect(try checkpoints.load()?.status == .verified)
        #expect(try await repository.importLegacy(plan, checkpoints: checkpoints) == .alreadyComplete)

        let links = try await repository.links()
        #expect(Set(links.map(\.id)) == Set(plan.links.map(\.id)))
        let folders = try await repository.folders()
        #expect(Set(folders.map(\.name)) == ["Empty", "Work", "Docs"])
        let docs = try #require(folders.first { $0.name == "Docs" })
        #expect(try await repository.links(in: .folder(docs.id)).map(\.title) == ["Link 0", "Link 2", "Link 4"])
    }

    @Test func resumesInterruptedImportWithoutDuplicates() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try makeRepository()
        let plan = try makePlan()

        // Simulate a crash after the first batch: records exist but the
        // checkpoint was never marked verified.
        _ = try await repository.importLegacy(plan, checkpoints: checkpoints, batchSize: 2)
        try checkpoints.save(MigrationCheckpoint(sourceFingerprint: plan.sourceFingerprint, completedLinkBatches: 1))

        let outcome = try await repository.importLegacy(plan, checkpoints: checkpoints, batchSize: 2)
        #expect(outcome == .migrated(links: 5, folders: 3, issues: []))
        #expect(try await repository.links().count == 5)
        #expect(try await repository.folders().count == 3)
    }

    @Test func rerunningWithLostCheckpointIsIdempotent() async throws {
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try makeRepository()
        let plan = try makePlan()
        _ = try await repository.importLegacy(plan, checkpoints: checkpoints)
        try FileManager.default.removeItem(at: checkpoints.fileURL)

        _ = try await repository.importLegacy(plan, checkpoints: checkpoints)
        #expect(try await repository.links().count == 5)
        #expect(try await repository.folders().count == 3)
    }
}
