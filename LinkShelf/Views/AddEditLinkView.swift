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
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: .linkUrl))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField(String(localized: .linkUrlPlaceholder), text: $url)
                        .textFieldStyle(.roundedBorder)
                    
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
            // Focus on title field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
    }
    
    private func saveLink() {
        // Validate URL
        guard !title.isEmpty, !url.isEmpty else {
            errorMessage = String(localized: .errorTitleRequired)
            return
        }
        
        // Add http:// if no scheme
        var finalURL = url
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "https://" + finalURL
        }
        
        // Basic URL validation
        guard URL(string: finalURL) != nil else {
            errorMessage = String(localized: .errorInvalidUrl)
            return
        }
        
        errorMessage = nil
        
        if let existingLink = link {
            linkManager.updateLink(existingLink, title: title, url: finalURL, folder: folder)
        } else {
            linkManager.addLink(title: title, url: finalURL, folder: folder)
        }
        
        isPresented = false
    }
}
