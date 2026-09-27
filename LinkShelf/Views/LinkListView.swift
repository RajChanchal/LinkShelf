import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let closeLinkShelfPopover = Notification.Name("CloseLinkShelfPopover")
}

struct LinkListView: View {
    var hidePopover: () -> Void = {}
    var showPopover: () -> Void = {}
    @EnvironmentObject private var linkManager: LinkManager
    @AppStorage("defaultLinkAction") private var defaultLinkAction = "copy"
    @AppStorage("closeAfterAction") private var closeAfterAction = true

    @State private var showingAddLink = false
    @State private var editingLink: Link?
    @State private var copiedLinkId: UUID?
    @State private var searchText = ""
    @State private var selectedLinkId: UUID?
    @State private var collapsedFolders: Set<String> = []
    @State private var deletedLink: Link?
    @State private var bookmarkImport: [ImportedBookmark]?
    @State private var isSelecting = false
    @State private var folderToRename: String?
    @State private var folderToDelete: String?
    @State private var showingNewFolder = false
    @State private var parentFolder: String?
    @State private var childFolderName = ""
    @State private var newFolderName = ""
    @State private var selectedLinkIDs: Set<UUID> = []
    @State private var undoTask: Task<Void, Never>?
    @AppStorage("collapsedFolders") private var collapsedFoldersStorage = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredLinks: [Link] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return linkManager.links }
        return linkManager.links.filter { link in
            link.title.localizedCaseInsensitiveContains(query) ||
            link.url.localizedCaseInsensitiveContains(query) ||
            (link.folder?.localizedCaseInsensitiveContains(query) ?? false) ||
            (URL(string: link.url)?.host?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var orderedVisibleLinks: [Link] {
        groupedLinks(filteredLinks).flatMap { group in
            let collapsed = searchText.isEmpty && collapsedFolders.contains(folderKey(group.folder))
            return collapsed ? [] : group.links
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider()

            Group {
                if linkManager.links.isEmpty && linkManager.folderNames.isEmpty { emptyState }
                else if filteredLinks.isEmpty && !searchText.isEmpty { noResultsState }
                else { linkList }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            keyboardHints
        }
        .frame(width: 400, height: 460)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            if let deletedLink {
                undoBanner(for: deletedLink)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 42)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(keyboardActions)
        .onAppear {
            collapsedFolders = Set(collapsedFoldersStorage.split(separator: "\n").map(String.init))
            selectFirstResult()
            DispatchQueue.main.async { isSearchFocused = true }
        }
        .onChange(of: searchText) { _, _ in selectFirstResult() }
        .onChange(of: linkManager.links) { _, _ in ensureValidSelection() }
        .onMoveCommand(perform: moveSelection)
        .onExitCommand(perform: handleEscape)
        .alert(String(localized: "folder.new.title"), isPresented: $showingNewFolder) {
            TextField(String(localized: .linkFolder), text: $childFolderName)
            Button(String(localized: .buttonCancel), role: .cancel) {}
            Button(String(localized: .buttonAdd)) {
                linkManager.addFolder(named: childFolderName, inside: parentFolder)
                if let parentFolder { collapsedFolders.remove(folderKey(parentFolder)) }
                collapsedFoldersStorage = collapsedFolders.sorted().joined(separator: "\n")
            }
            .disabled(!linkManager.canAddFolder(named: childFolderName, inside: parentFolder))
        } message: { Text(String(localized: "folder.new.hint")) }
        .alert(String(localized: "folder.rename.title"), isPresented: Binding(
            get: { folderToRename != nil },
            set: { if !$0 { folderToRename = nil } }
        )) {
            TextField(String(localized: .linkFolder), text: $newFolderName)
            Button(String(localized: .buttonCancel), role: .cancel) { folderToRename = nil }
            Button(String(localized: .buttonSave)) { renameFolder() }
                .disabled(folderToRename.map { !linkManager.canRenameFolder($0, to: newFolderName) } ?? true)
        } message: {
            Text(String(localized: "folder.rename.hint"))
        }
        .sheet(isPresented: $showingAddLink) {
            AddEditLinkView(isPresented: $showingAddLink).environmentObject(linkManager)
        }
        .alert(String(localized: "folder.delete.title"), isPresented: Binding(
            get: { folderToDelete != nil },
            set: { if !$0 { folderToDelete = nil } }
        )) {
            Button(String(localized: .buttonCancel), role: .cancel) { folderToDelete = nil }
            Button(String(localized: .buttonDelete), role: .destructive) { deleteFolder() }
        } message: {
            Text(String(localized: "folder.delete.hint"))
            if let folderToDelete { Text(verbatim: folderToDelete) }
        }
        .sheet(item: $editingLink) { link in
            AddEditLinkView(link: link, isPresented: Binding(
                get: { editingLink != nil },
                set: { if !$0 { editingLink = nil } }
            )).environmentObject(linkManager)
        }
        .sheet(isPresented: Binding(get: { bookmarkImport != nil }, set: { if !$0 { bookmarkImport = nil } })) {
            if let bookmarkImport { ImportBookmarksView(bookmarks: bookmarkImport).environmentObject(linkManager) }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(String(localized: .appName)).font(.headline)
            Spacer()
            if isSelecting {
                Button("Select All") { selectedLinkIDs = Set(filteredLinks.map(\.id)) }
                Button("Delete", role: .destructive) { deleteSelected() }.disabled(selectedLinkIDs.isEmpty)
                Button("Done") { isSelecting = false; selectedLinkIDs.removeAll() }
            } else {
                Button { isSelecting = true } label: { Image(systemName: "checklist").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).help("Select bookmarks")
            }
            Button(action: prepareToAdd) {
                Image(systemName: "plus").frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(String(localized: .linkAdd))

            Menu {
                Button(String(localized: "folder.new.title")) {
                    parentFolder = nil
                    childFolderName = ""
                    showingNewFolder = true
                }
                SettingsLink { Label("Settings…", systemImage: "gearshape") }
                Button { chooseBookmarkFile() } label: {
                    Label("Import bookmarks…", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.titleAndIcon)
                Divider()
                Button(String(localized: .menuQuitLinkshelf)) { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func chooseBookmarkFile() {
        isSearchFocused = false
        hidePopover()
        DispatchQueue.main.async {
            let panel = NSOpenPanel()
            panel.allowedContentTypes = [.html, UTType(filenameExtension: "htm") ?? .html]
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            panel.begin { response in
                guard response == .OK, let url = panel.url,
                      let bookmarks = try? BookmarkImporter().parse(file: url) else { return }
                showPopover()
                DispatchQueue.main.async { bookmarkImport = bookmarks }
            }
        }
    }

    private func toggleSelection(of link: Link) {
        if selectedLinkIDs.contains(link.id) { selectedLinkIDs.remove(link.id) }
        else { selectedLinkIDs.insert(link.id) }
    }

    private func deleteSelected() {
        guard !selectedLinkIDs.isEmpty else { return }
        linkManager.deleteLinks(withIDs: selectedLinkIDs)
        selectedLinkIDs.removeAll()
        isSelecting = false
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(String(localized: .searchPlaceholder), text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onKeyPress(keys: [.upArrow, .downArrow, .return, .escape]) { press in
                    handleSearchKeyPress(press)
                }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help(String(localized: .searchClear))
            }
            Text(verbatim: "⌘F").font(.caption2.monospaced()).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSearchFocused ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.12), lineWidth: 1)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .onTapGesture { isSearchFocused = true }
    }

    private var linkList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(groupedLinks(filteredLinks), id: \.folder) { group in
                    let key = folderKey(group.folder)
                    let isCollapsed = searchText.isEmpty && collapsedFolders.contains(key)
                    Section {
                        if !isCollapsed {
                            ForEach(group.links) { link in
                                LinkRowView(
                                    link: link,
                                    isSelected: selectedLinkId == link.id,
                                    isMultiSelecting: isSelecting,
                                    isMarked: selectedLinkIDs.contains(link.id),
                                    isCopied: copiedLinkId == link.id,
                                    onToggleSelection: { toggleSelection(of: link) },
                                    onPrimaryAction: { performDefaultAction(on: link) },
                                    onOpen: { open(link) },
                                    onEdit: { editingLink = link },
                                    onDelete: { deleteWithUndo(link) }
                                )
                                .id(link.id)
                                .padding(.leading, CGFloat(max(0, (group.folder?.components(separatedBy: " / ").count ?? 1) - 1)) * 16)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                            }
                            .onMove { source, destination in
                                guard searchText.isEmpty else { return }
                                linkManager.moveLink(in: group.folder, from: source, to: destination)
                            }
                        }
                    } header: {
                        folderHeader(group.folder, count: group.links.count, isCollapsed: isCollapsed, onSelect: {
                            let descendants = filteredLinks.filter { link in
                                link.folder == group.folder || (group.folder.map { parent in
                                    link.folder?.hasPrefix(parent + " / ") ?? false
                                } ?? false)
                            }
                            selectedLinkIDs.formUnion(descendants.map(\.id))
                        }) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if isCollapsed { collapsedFolders.remove(key) } else { collapsedFolders.insert(key) }
                                collapsedFoldersStorage = collapsedFolders.sorted().joined(separator: "\n")
                            }
                            ensureValidSelection()
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onChange(of: selectedLinkId) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func folderHeader(_ folder: String?, count: Int, isCollapsed: Bool, onSelect: @escaping () -> Void, onToggle: @escaping () -> Void) -> some View {
        Button(action: isSelecting ? onSelect : onToggle) {
            HStack(spacing: 6) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down").font(.caption2.weight(.semibold))
                                Text(folder?.components(separatedBy: " / ").last ?? String(localized: .linkNoFolder))
                Spacer()
                Text(verbatim: "\(count)").monospacedDigit()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.leading, CGFloat(max(0, (folder?.components(separatedBy: " / ").count ?? 1) - 1)) * 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!searchText.isEmpty)
        .contextMenu {
            if let folder {
                Button(String(localized: "folder.new.child")) {
                    parentFolder = folder
                    childFolderName = ""
                    showingNewFolder = true
                }
                Button(String(localized: "folder.rename.menu")) {
                    newFolderName = folder
                    folderToRename = folder
                }
                Divider()
                Button(String(localized: "folder.delete.menu"), role: .destructive) {
                    folderToDelete = folder
                }
            }
        }
    }

    private func renameFolder() {
        guard let folder = folderToRename,
              linkManager.renameFolder(folder, to: newFolderName) else { return }
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let oldKey = folderKey(folder)
        let newKey = folderKey(name)
        collapsedFolders = Set(collapsedFolders.map { key in
            key == oldKey || key.hasPrefix(oldKey + " / ")
                ? newKey + String(key.dropFirst(oldKey.count)) : key
        })
        collapsedFoldersStorage = collapsedFolders.sorted().joined(separator: "\n")
        folderToRename = nil
    }

    private func deleteFolder() {
        guard let folder = folderToDelete else { return }
        linkManager.deleteFolder(folder)
        let key = folderKey(folder)
        collapsedFolders = Set(collapsedFolders.filter { $0 != key && !$0.hasPrefix(key + " / ") })
        collapsedFoldersStorage = collapsedFolders.sorted().joined(separator: "\n")
        selectedLinkIDs.formIntersection(linkManager.links.map(\.id))
        folderToDelete = nil
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Build your shelf").font(.headline)
            Text("Keep the links you reach for every day one shortcut away.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 270)
            Button("Add your first link", action: prepareToAdd).buttonStyle(.borderedProminent)
            Text("Tip: copy a URL first and we’ll fill it in for you.").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(30)
    }

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
            Text(String(localized: .searchNoResults)).font(.headline)
            Text("No title, URL, domain, or folder matches “\(searchText)”.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(String(localized: .searchClear)) { searchText = "" }.buttonStyle(.borderless)
        }
        .padding(30)
    }

    private var keyboardHints: some View {
        HStack(spacing: 14) {
            Label("Select", systemImage: "arrow.up.arrow.down")
            Text("↩ Copy")
            Text("⌘↩ Open")
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    private var keyboardActions: some View {
        HStack {
            Button(action: prepareToAdd) { EmptyView() }.keyboardShortcut("n", modifiers: [.command])
            Button { isSearchFocused = true } label: { EmptyView() }.keyboardShortcut("f", modifiers: [.command])
            ForEach(1...9, id: \.self) { number in
                Button { activateLink(at: number - 1) } label: { EmptyView() }
                    .keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: [.command])
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func undoBanner(for link: Link) -> some View {
        HStack(spacing: 10) {
            Text("“\(link.title)” deleted").lineLimit(1)
            Spacer()
            Button("Undo") {
                undoTask?.cancel()
                linkManager.restoreLink(link)
                withAnimation { deletedLink = nil }
            }
            .buttonStyle(.borderless)
            .fontWeight(.semibold)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 9))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
    }

    private var selectedLink: Link? { orderedVisibleLinks.first { $0.id == selectedLinkId } }

    private func prepareToAdd() {
        isSearchFocused = false
        searchText = ""
        showingAddLink = true
    }

    private func performDefaultAction(on link: Link) {
        selectedLinkId = link.id
        if defaultLinkAction == "open" { open(link) } else { copy(link) }
    }

    private func activateSelected() { if let link = selectedLink { copy(link) } }

    private func activateLink(at index: Int) {
        guard orderedVisibleLinks.indices.contains(index) else { return }
        performDefaultAction(on: orderedVisibleLinks[index])
    }

    private func copy(_ link: Link) {
        linkManager.copyToClipboard(link)
        withAnimation { copiedLinkId = link.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            copiedLinkId = nil
            if closeAfterAction { NotificationCenter.default.post(name: .closeLinkShelfPopover, object: nil) }
        }
    }

    private func open(_ link: Link) {
        linkManager.openInBrowser(link)
        if closeAfterAction { NotificationCenter.default.post(name: .closeLinkShelfPopover, object: nil) }
    }

    private func deleteWithUndo(_ link: Link) {
        undoTask?.cancel()
        linkManager.deleteLink(link)
        withAnimation { deletedLink = link }
        undoTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            await MainActor.run { withAnimation { deletedLink = nil } }
        }
    }

    private func handleEscape() {
        if !searchText.isEmpty { searchText = "" }
        else { NotificationCenter.default.post(name: .closeLinkShelfPopover, object: nil) }
    }

    private func handleSearchKeyPress(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow:
            moveSelection(.up)
        case .downArrow:
            moveSelection(.down)
        case .return:
            if press.modifiers.contains(.command), let link = selectedLink { open(link) }
            else { activateSelected() }
        case .escape:
            handleEscape()
        default:
            return .ignored
        }
        return .handled
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let links = orderedVisibleLinks
        guard !links.isEmpty else { selectedLinkId = nil; return }
        let current = links.firstIndex { $0.id == selectedLinkId } ?? 0
        let next: Int
        switch direction {
        case .up: next = max(0, current - 1)
        case .down: next = min(links.count - 1, current + 1)
        default: return
        }
        selectedLinkId = links[next].id
    }

    private func selectFirstResult() { selectedLinkId = orderedVisibleLinks.first?.id }
    private func ensureValidSelection() { if selectedLink == nil { selectFirstResult() } }

    private func groupedLinks(_ links: [Link]) -> [(folder: String?, links: [Link])] {
        let groups = Dictionary(grouping: links) { normalizeFolder($0.folder) }
        var result: [(folder: String?, links: [Link])] = []
        if let unfiled = groups[nil] { result.append((nil, unfiled.sorted { $0.order < $1.order })) }
        let paths = linkManager.folderNames.sorted {
            $0.components(separatedBy: " / ").lexicographicallyPrecedes($1.components(separatedBy: " / ")) {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        }
        for path in paths {
            let parts = path.components(separatedBy: " / ")
            let ancestors = (1..<parts.count).map { parts.prefix($0).joined(separator: " / ") }
            if searchText.isEmpty && ancestors.contains(where: { collapsedFolders.contains(folderKey($0)) }) { continue }
            if !searchText.isEmpty && !links.contains(where: { $0.folder == path || ($0.folder?.hasPrefix(path + " / ") ?? false) }) { continue }
            result.append((path, (groups[path] ?? []).sorted { $0.order < $1.order }))
        }
        return result
    }

    private func normalizeFolder(_ folder: String?) -> String? {
        let value = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private func folderKey(_ folder: String?) -> String { normalizeFolder(folder)?.lowercased() ?? "__no_folder__" }
}

struct LinkRowView: View {
    let link: Link
    let isSelected: Bool
    let isMultiSelecting: Bool
    let isMarked: Bool
    let isCopied: Bool
    let onToggleSelection: () -> Void
    let onPrimaryAction: () -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    private var faviconImage: NSImage? {
        guard let data = link.faviconData else { return nil }
        return FaviconManager.shared.image(from: data)
    }

    private var displayDomain: String {
        URL(string: link.url)?.host?.replacingOccurrences(of: "www.", with: "") ?? link.url
    }

    var body: some View {
        HStack(spacing: 8) {
            if isMultiSelecting {
                Button(action: onToggleSelection) {
                    Image(systemName: isMarked ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isMarked ? Color.accentColor : Color.secondary)
                }.buttonStyle(.plain)
            }
            Button(action: onPrimaryAction) {
                HStack(spacing: 10) {
                    Group {
                        if let faviconImage {
                            Image(nsImage: faviconImage).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 3))
                        } else {
                            Image(systemName: "link").foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 20, height: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.title).font(.body.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                        Text(displayDomain).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isCopied {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).transition(.scale.combined(with: .opacity))
            } else if isHovering || isSelected {
                Button(action: onOpen) { Image(systemName: "arrow.up.right.square") }
                    .buttonStyle(.plain).help(String(localized: .actionOpenInBrowser))
                Menu {
                    Button(String(localized: .buttonEdit), action: onEdit)
                    Divider()
                    Button(String(localized: .buttonDelete), role: .destructive, action: onDelete)
                } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(isSelected ? Color.accentColor.opacity(0.13) : (isHovering ? Color.primary.opacity(0.055) : .clear), in: RoundedRectangle(cornerRadius: 7))
        .padding(.horizontal, 6)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
