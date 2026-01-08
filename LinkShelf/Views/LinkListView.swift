//
//  LinkListView.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import SwiftUI
import AppKit

struct LinkListView: View {
    @EnvironmentObject var linkManager: LinkManager
    @State private var showingAddLink = false
    @State private var editingLink: Link?
    @State private var copiedLinkId: UUID?
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var collapsedFolders: Set<String> = []
    
    // Filtered links based on search text
    private var filteredLinks: [Link] {
        if searchText.isEmpty {
            return linkManager.links
        }
        return linkManager.links.filter { link in
            link.title.localizedCaseInsensitiveContains(searchText) ||
            link.url.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "link.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            // Title
            VStack(spacing: 6) {
                Text(L.emptyStateTitle.localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(L.emptyStateMessage.localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
            
            // Quick action button
            Button(action: {
                isSearchFocused = false
                showingAddLink = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text(L.addFirstLink.localized)
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help(L.addFirstLink.localized)
            
            // Tips
            VStack(alignment: .leading, spacing: 8) {
                Text(L.quickTips.localized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(L.tipCopyLinks.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(L.tipOpenLinks.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text(L.tipSearchLinks.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.secondary)
            
            // Title and message
            VStack(spacing: 6) {
                Text(L.noResultsFound.localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(L.noResultsMessage.localized.replacingOccurrences(of: "%@", with: searchText))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Clear search button
            Button(action: {
                searchText = ""
                isSearchFocused = false
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                    Text(L.clearSearch.localized)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(L.clearSearch.localized)
            
            // Alternative actions
            VStack(spacing: 8) {
                Text(L.tryLabel.localized)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text(L.tryCheckSpelling.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text(L.trySearchByTitle.localized)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
    
    private func groupedLinks(_ links: [Link]) -> [(folder: String?, links: [Link])] {
        var grouped: [String?: [Link]] = [:]
        for link in links {
            let normalized = normalizeFolder(link.folder)
            grouped[normalized, default: []].append(link)
        }
        let sortedKeys = grouped.keys.sorted { left, right in
            switch (left, right) {
            case (nil, nil):
                return false
            case (nil, _):
                return true
            case (_, nil):
                return false
            case (let left?, let right?):
                return left.lowercased() < right.lowercased()
            }
        }
        
        return sortedKeys.map { key in
            let sortedLinks = (grouped[key] ?? []).sorted { $0.order < $1.order }
            return (folder: key, links: sortedLinks)
        }
    }
    
    private func normalizeFolder(_ folder: String?) -> String? {
        let trimmed = folder?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
    
    private func folderKey(_ folder: String?) -> String {
        return normalizeFolder(folder)?.lowercased() ?? "__no_folder__"
    }
    
    private func folderHeaderView(title: String, count: Int, isCollapsed: Bool, onToggle: @escaping () -> Void) -> some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 10)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(L.appName.localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
                    isSearchFocused = false
                    showingAddLink = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.plain)
                .help(L.addLink.localized)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                
                TextField(L.searchPlaceholder.localized, text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        // Unfocus when pressing Enter/Return
                        isSearchFocused = false
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help(L.clearSearch.localized)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .onTapGesture {
                // Keep focus when clicking on search bar itself
                isSearchFocused = true
            }
            
            Divider()
            
            // Links list
            if linkManager.links.isEmpty {
                emptyStateView
            } else if filteredLinks.isEmpty && !searchText.isEmpty {
                noResultsView
            } else {
                let groups = groupedLinks(filteredLinks)
                List {
                    ForEach(groups, id: \.folder) { group in
                        let key = folderKey(group.folder)
                        let isCollapsed = searchText.isEmpty ? collapsedFolders.contains(key) : false
                        
                        Section(header: folderHeaderView(
                            title: group.folder ?? L.linkNoFolder.localized,
                            count: group.links.count,
                            isCollapsed: isCollapsed,
                            onToggle: {
                                guard searchText.isEmpty else { return }
                                if isCollapsed {
                                    collapsedFolders.remove(key)
                                } else {
                                    collapsedFolders.insert(key)
                                }
                            }
                        )) {
                            if !isCollapsed {
                                ForEach(group.links) { link in
                                    LinkRowView(
                                        link: link,
                                        isCopied: copiedLinkId == link.id,
                                        onCopy: {
                                            isSearchFocused = false
                                            linkManager.copyToClipboard(link)
                                            withAnimation {
                                                copiedLinkId = link.id
                                            }
                                            // Reset copied state after 1.5 seconds
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                if copiedLinkId == link.id {
                                                    copiedLinkId = nil
                                                }
                                            }
                                        },
                                        onOpen: {
                                            isSearchFocused = false
                                            linkManager.openInBrowser(link)
                                        },
                                        onEdit: {
                                            isSearchFocused = false
                                            editingLink = link
                                        },
                                        onDelete: {
                                            isSearchFocused = false
                                            linkManager.deleteLink(link)
                                        }
                                    )
                                }
                                .onMove { source, destination in
                                    guard searchText.isEmpty else { return }
                                    linkManager.moveLink(in: group.folder, from: source, to: destination)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            
            Divider()
            
            // Footer with Quit button
            HStack {
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Text(L.quitLinkShelf.localized)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 360, height: 400)
        .background(
            // Background tap to unfocus search
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    TapGesture()
                        .onEnded { _ in
                            // Unfocus search when tapping background
                            isSearchFocused = false
                        }
                )
        )
        .onAppear {
            // Auto-focus search when popover opens
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isSearchFocused = true
            }
        }
        .onChange(of: showingAddLink) { oldValue, newValue in
            // Clear search when adding new link
            if newValue {
                searchText = ""
            }
        }
        .onChange(of: editingLink) { oldValue, newValue in
            // Clear search when editing link
            if newValue != nil {
                searchText = ""
            }
        }
        .sheet(isPresented: $showingAddLink) {
            AddEditLinkView(isPresented: $showingAddLink)
                .environmentObject(linkManager)
        }
        .sheet(item: $editingLink) { link in
            AddEditLinkView(link: link, isPresented: Binding(
                get: { editingLink != nil },
                set: { if !$0 { editingLink = nil } }
            ))
            .environmentObject(linkManager)
        }
    }
}

struct LinkRowView: View {
    let link: Link
    let isCopied: Bool
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var faviconImage: NSImage? {
        guard let faviconData = link.faviconData else { return nil }
        return FaviconManager.shared.image(from: faviconData)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Favicon or default link icon
            Group {
                if let favicon = faviconImage {
                    Image(nsImage: favicon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 20, height: 20)
            
            // Link info
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(link.url)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Copy button
            Button(action: onCopy) {
                if isCopied {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help(isCopied ? L.copied.localized : L.copyToClipboard.localized)
            
            // Open button
            Button(action: onOpen) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.openInBrowser.localized)
            
            // Menu button
            Menu {
                Button(L.edit.localized, action: onEdit)
                Divider()
                Button(L.delete.localized, role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
