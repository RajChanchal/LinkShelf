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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("LinkShelf")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button(action: {
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
            
            // Links list
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
            } else {
                List {
                    ForEach(linkManager.links) { link in
                        LinkRowView(
                            link: link,
                            isCopied: copiedLinkId == link.id,
                            onCopy: {
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
                                linkManager.openInBrowser(link)
                            },
                            onEdit: {
                                editingLink = link
                            },
                            onDelete: {
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Link icon
            Image(systemName: "link")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)
            
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

