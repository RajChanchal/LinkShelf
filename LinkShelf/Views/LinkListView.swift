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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LinkShelf")
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
                .help("Add new link")
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
                
                TextField("Search links...", text: $searchText)
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
                    .help("Clear search")
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
            
            // Links list (with tap gesture to unfocus search)
            if linkManager.links.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "link")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No links yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Click + to add your first link")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else if filteredLinks.isEmpty && !searchText.isEmpty {
                // No search results
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No results found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Try a different search term")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                List {
                    ForEach(filteredLinks) { link in
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
                    .onMove(perform: linkManager.moveLink)
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
                    Text("Quit LinkShelf")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 300, height: 400)
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
            .help(isCopied ? "Copied!" : "Copy to clipboard")
            
            // Open button
            Button(action: onOpen) {
                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in browser")
            
            // Menu button
            Menu {
                Button("Edit", action: onEdit)
                Divider()
                Button("Delete", role: .destructive, action: onDelete)
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

