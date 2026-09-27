import Foundation
import LinkShelfDomain
import LinkShelfPersistence
import SwiftData
import Testing

func makeRepository(_ configuration: LinkShelfStoreConfiguration = .inMemory) throws -> LinkRepository {
    LinkRepository(modelContainer: try LinkShelfContainerFactory.makeContainer(configuration))
}

struct LinkRepositoryTests {
    @Test func addsValidatedLinksInOrder() async throws {
        let repository = try makeRepository()
        let first = try await repository.addLink(LinkDraft(title: " Docs ", url: "Example.com/Guide"))
        let second = try await repository.addLink(LinkDraft(title: "News", url: "news.example.com"))
        #expect(first.title == "Docs")
        #expect(first.url == "https://example.com/Guide")
        #expect(try await repository.links().map(\.id) == [first.id, second.id])
        #expect(try await repository.links(in: .unfiled, limit: 1).map(\.id) == [first.id])
    }

    @Test func rejectsInvalidAndDuplicateLinks() async throws {
        let repository = try makeRepository()
        let saved = try await repository.addLink(LinkDraft(title: "A", url: "https://a.com/x"))
        await #expect(throws: LinkShelfError.duplicateLink(existingID: saved.id)) {
            try await repository.addLink(LinkDraft(title: "B", url: "A.COM/x"))
        }
        await #expect(throws: LinkShelfError.unsupportedScheme("javascript")) {
            try await repository.addLink(LinkDraft(title: "B", url: "javascript:alert(1)"))
        }
        #expect(try await repository.existingLink(matching: "https://a.com:443/x")?.id == saved.id)
        _ = try await repository.addLink(LinkDraft(title: "B", url: "a.com/X"))
        #expect(try await repository.links().count == 2)
    }

    @Test func updatesAndMovesLinks() async throws {
        let repository = try makeRepository()
        let folder = try await repository.createFolder(named: "Work", inside: nil)
        let one = try await repository.addLink(LinkDraft(title: "One", url: "one.com", folderID: folder.id))
        let two = try await repository.addLink(LinkDraft(title: "Two", url: "two.com", folderID: folder.id))
        let loose = try await repository.addLink(LinkDraft(title: "Loose", url: "loose.com"))

        try await repository.moveLink(id: two.id, toFolder: folder.id, at: 0)
        #expect(try await repository.links(in: .folder(folder.id)).map(\.id) == [two.id, one.id])

        let updated = try await repository.updateLink(
            id: loose.id, with: LinkDraft(title: "Renamed", url: "loose.com/new", folderID: folder.id))
        #expect(updated.folderID == folder.id)
        #expect(try await repository.links(in: .folder(folder.id)).map(\.id) == [two.id, one.id, loose.id])
        #expect(try await repository.links(in: .unfiled).isEmpty)
    }

    @Test func searchesTitleURLAndFolder() async throws {
        let repository = try makeRepository()
        let recipes = try await repository.createFolder(named: "Recipes", inside: nil)
        let byTitle = try await repository.addLink(LinkDraft(title: "Swift Guide", url: "docs.example.com"))
        let byURL = try await repository.addLink(LinkDraft(title: "Home", url: "swift.org"))
        let byFolder = try await repository.addLink(LinkDraft(title: "Soup", url: "soup.com", folderID: recipes.id))
        _ = try await repository.addLink(LinkDraft(title: "Other", url: "other.com"))

        #expect(Set(try await repository.search("SWIFT").map(\.id)) == [byTitle.id, byURL.id])
        #expect(try await repository.search("recip").map(\.id) == [byFolder.id])
        #expect(try await repository.search("  ").count == 4)
    }

    @Test func manageNestedFolders() async throws {
        let repository = try makeRepository()
        let work = try await repository.createFolder(named: "Work", inside: nil)
        let docs = try await repository.createFolder(named: "Docs", inside: work.id)
        let deep = try await repository.createFolder(named: "Deep", inside: docs.id)
        _ = try await repository.addLink(LinkDraft(title: "Keep", url: "keep.com"))
        _ = try await repository.addLink(LinkDraft(title: "Gone", url: "gone.com", folderID: deep.id))

        await #expect(throws: LinkShelfError.duplicateFolderName) {
            try await repository.createFolder(named: "docs", inside: work.id)
        }
        await #expect(throws: LinkShelfError.folderCycle) {
            try await repository.moveFolder(id: work.id, inside: deep.id)
        }

        try await repository.renameFolder(id: docs.id, to: "Documents")
        let renamed = try await repository.folders().first { $0.id == docs.id }
        #expect(renamed?.name == "Documents")
        #expect(renamed?.parentID == work.id)

        try await repository.deleteFolder(id: docs.id)
        #expect(try await repository.folders().map(\.id) == [work.id])
        #expect(try await repository.links().map(\.title) == ["Keep"])
    }

    @Test func emptyFoldersPersistAcrossReopen() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = LinkShelfStoreConfiguration(location: .file(directory.appendingPathComponent("test.store")))

        let folderID: UUID
        let linkID: UUID
        do {
            let repository = try makeRepository(configuration)
            folderID = try await repository.createFolder(named: "Empty", inside: nil).id
            linkID = try await repository.addLink(LinkDraft(title: "A", url: "a.com")).id
        }
        let reopened = try makeRepository(configuration)
        #expect(try await reopened.folders().map(\.id) == [folderID])
        #expect(try await reopened.links().map(\.id) == [linkID])
    }

    @Test func reconcilesDuplicatesAddedElsewhere() async throws {
        let repository = try makeRepository()
        let one = try await repository.addLink(LinkDraft(title: "Same", url: "a.com"))
        let two = try await repository.addLink(LinkDraft(title: "Same", url: "a.com"), allowingDuplicate: true)
        let divergent = try await repository.addLink(LinkDraft(title: "Other", url: "a.com"), allowingDuplicate: true)

        let resolution = try await repository.reconcileDuplicates()
        let survivor = [one.id, two.id].min { $0.uuidString < $1.uuidString }
        #expect(resolution.redundantIDs.count == 1)
        #expect(Set(try await repository.links().map(\.id)) == Set([survivor, divergent.id].compactMap { $0 }))
        #expect(resolution.reviewGroups.count == 1)
        #expect(try await repository.reconcileDuplicates().redundantIDs.isEmpty)
    }
}
