import SwiftUI

struct ImportBookmarksView: View {
    @EnvironmentObject private var linkManager: LinkManager
    @Environment(\.dismiss) private var dismiss
    let bookmarks: [ImportedBookmark]
    @State private var selectedIDs: Set<UUID>

    init(bookmarks: [ImportedBookmark]) {
        self.bookmarks = bookmarks
        _selectedIDs = State(initialValue: Set(bookmarks.map(\.id)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Import Bookmarks").font(.headline)
            Text("Choose the bookmarks you want to add to LinkShelf.").foregroundStyle(.secondary)
            List(bookmarks) { bookmark in
                Button {
                    if selectedIDs.contains(bookmark.id) { selectedIDs.remove(bookmark.id) } else { selectedIDs.insert(bookmark.id) }
                } label: {
                    HStack { Image(systemName: selectedIDs.contains(bookmark.id) ? "checkmark.circle.fill" : "circle"); VStack(alignment: .leading) { Text(bookmark.title); Text(bookmark.url).font(.caption).foregroundStyle(.secondary).lineLimit(1) } }
                }.buttonStyle(.plain)
            }.frame(minHeight: 220)
            HStack { Button("Cancel") { dismiss() }; Spacer(); Button("Add Selected") { linkManager.importLinks(bookmarks.filter { selectedIDs.contains($0.id) }); dismiss() }.buttonStyle(.borderedProminent).disabled(selectedIDs.isEmpty) }
        }.padding(20).frame(width: 520, height: 430)
    }
}
