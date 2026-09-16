//
//  AddEditLinkView.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import SwiftUI

struct AddEditLinkView: View {
    @EnvironmentObject var linkManager: LinkManager
    
    let link: Link?
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var url: String = ""
    @State private var folder: String = ""
    @State private var errorMessage: String?
    @State private var titleWasEdited = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case title, url, folder
    }
    
    init(link: Link? = nil, isPresented: Binding<Bool>) {
        self.link = link
        self._isPresented = isPresented
        if let link = link {
            _title = State(initialValue: link.title)
            _url = State(initialValue: link.url)
            _folder = State(initialValue: link.folder ?? "")
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(String(localized: link == nil ? .linkAdd : .linkEdit))
                    .font(.headline)
                Spacer()
                Button(action: {
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: .linkTitle))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField(String(localized: .linkTitlePlaceholder), text: $title)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .title)
                        .onChange(of: title) { _, _ in titleWasEdited = true }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: .linkUrl))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField(String(localized: .linkUrlPlaceholder), text: $url)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .url)
                        .onChange(of: url) { _, newValue in
                            guard link == nil, !titleWasEdited, let suggestedTitle = suggestedTitle(from: newValue) else { return }
                            title = suggestedTitle
                            titleWasEdited = false
                        }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: .linkFolder))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField(String(localized: .linkFolderPlaceholder), text: $folder)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .folder)
                    
                    if !linkManager.folderNames.isEmpty {
                        Menu {
                            Button(String(localized: .linkNoFolder)) {
                                folder = ""
                            }
                            ForEach(linkManager.folderNames, id: \.self) { name in
                                Button(name) {
                                    folder = name
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder")
                                Text(String(localized: .linkFolderChoose))
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: .linkFolderChoose))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                Button(String(localized: .buttonCancel)) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(String(localized: link == nil ? .buttonAdd : .buttonSave)) {
                    saveLink()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || url.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        // Let longer localized labels grow vertically instead of being clipped.
        .frame(width: 400)
        .onAppear {
            titleWasEdited = link != nil
            if link == nil, url.isEmpty,
               let clipboardValue = NSPasteboard.general.string(forType: .string),
               normalizedURL(from: clipboardValue) != nil {
                url = clipboardValue.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            focusedField = title.isEmpty ? .title : .url
        }
    }
    
    private func saveLink() {
        // Validate URL
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedFolder = folder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: .errorTitleRequired)
            return
        }

        guard let finalURL = normalizedURL(from: url) else {
            errorMessage = String(localized: .errorInvalidUrl)
            return
        }

        if linkManager.linkExists(url: finalURL), link?.url.caseInsensitiveCompare(finalURL) != .orderedSame {
            errorMessage = String(localized: "error.duplicate.url", defaultValue: "This link is already on your shelf.")
            return
        }
        
        errorMessage = nil
        
        if let existingLink = link {
            linkManager.updateLink(existingLink, title: trimmedTitle, url: finalURL, folder: trimmedFolder)
        } else {
            linkManager.addLink(title: trimmedTitle, url: finalURL, folder: trimmedFolder)
        }
        
        isPresented = false
    }

    private func normalizedURL(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false,
              let result = components.url else { return nil }
        return result.absoluteString
    }

    private func suggestedTitle(from value: String) -> String? {
        guard let normalized = normalizedURL(from: value),
              let host = URL(string: normalized)?.host else { return nil }
        return host
            .replacingOccurrences(of: "www.", with: "")
            .split(separator: ".")
            .first
            .map { String($0).replacingOccurrences(of: "-", with: " ").capitalized }
    }
}
