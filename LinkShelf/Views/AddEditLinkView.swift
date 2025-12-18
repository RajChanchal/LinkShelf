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
    @State private var errorMessage: String?
    
    init(link: Link? = nil, isPresented: Binding<Bool>) {
        self.link = link
        self._isPresented = isPresented
        if let link = link {
            _title = State(initialValue: link.title)
            _url = State(initialValue: link.url)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(link == nil ? "Add Link" : "Edit Link")
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
                    Text("Title")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("e.g., LinkedIn Profile", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("https://example.com", text: $url)
                        .textFieldStyle(.roundedBorder)
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            Divider()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(link == nil ? "Add" : "Save") {
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
        .frame(width: 400, height: 280)
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
            errorMessage = "Title and URL are required"
            return
        }
        
        // Add http:// if no scheme
        var finalURL = url
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "https://" + finalURL
        }
        
        // Basic URL validation
        guard URL(string: finalURL) != nil else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        errorMessage = nil
        
        if let existingLink = link {
            linkManager.updateLink(existingLink, title: title, url: finalURL)
        } else {
            linkManager.addLink(title: title, url: finalURL)
        }
        
        isPresented = false
    }
}

