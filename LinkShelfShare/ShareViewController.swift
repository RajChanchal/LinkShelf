//
//  ShareViewController.swift
//  LinkShelfShare
//
//  Created for LinkShelf
//

import Cocoa
import AppKit

class ShareViewController: NSViewController {
    
    private var urlTextField: NSTextField!
    private var titleTextField: NSTextField!
    private var warningLabel: NSTextField!
    private var addButton: NSButton!
    private var cancelButton: NSButton!
    
    private var sharedURL: String = ""
    private var pageTitle: String = ""
    
    private var storedContext: NSExtensionContext?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 280))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func beginRequest(with context: NSExtensionContext) {
        // Always call super implementation
        super.beginRequest(with: context)
        
        // Store context manually as a backup
        self.storedContext = context
        
        // Ensure view is loaded first
        _ = view
        
        print("🚀 Share Extension beginRequest started")
        
        guard let inputItems = context.inputItems as? [NSExtensionItem],
              let item = inputItems.first else {
            print("⚠️ No input items found")
            cancelAction(nil)
            return
        }
        
        // 1. Try to get data from JavaScript (Safari)
        if let attachments = item.attachments {
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("com.apple.property-list") {
                    attachment.loadItem(forTypeIdentifier: "com.apple.property-list", options: nil) { [weak self] (result, error) in
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("JS load error: \(error)")
                            return
                        }
                        
                        if let dict = result as? NSDictionary,
                           let results = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? NSDictionary {
                            
                            DispatchQueue.main.async {
                                if let urlString = results["URL"] as? String {
                                    print("🌍 JS URL: \(urlString)")
                                    self.sharedURL = urlString
                                }
                                
                                if let title = results["title"] as? String {
                                    print("📝 JS Title: \(title)")
                                    self.pageTitle = title
                                }
                                
                                self.updateUI()
                            }
                            return // Found JS data, stop here
                        }
                    }
                }
            }
        }
        
        // 2. Fallback to existing logic (non-Safari)
        
        // Extract title if available (and not already set by JS)
        if pageTitle.isEmpty {
           if let title = item.attributedTitle?.string, !title.isEmpty {
               pageTitle = title
               print("📝 Title from item: \(title)")
           } else if let contentText = item.attributedContentText?.string, !contentText.isEmpty {
               pageTitle = contentText
               print("📝 Title from contentText: \(contentText)")
           }
        }
        
        // Extract URL from attachments if not found by JS
        if sharedURL.isEmpty {
            if let attachments = item.attachments {
                // Log available types
                for (index, attachment) in attachments.enumerated() {
                    print("📎 Attachment \(index): \(attachment.registeredTypeIdentifiers.joined(separator: ", "))")
                }
                
                findURL(in: attachments)
            } else {
                print("⚠️ No attachments found")
            }
        }
    }
    
    private func findURL(in attachments: [NSItemProvider]) {
        var foundProvider: NSItemProvider?
        
        // First pass: Look for direct URL
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier("public.url") {
                foundProvider = attachment
                break
            }
        }
        
        // Second pass: Look for plain text if no URL found
        if foundProvider == nil {
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                    foundProvider = attachment
                    break
                }
            }
        }
        
        if let provider = foundProvider {
            print("🔍 Attempting to load item from provider: \(provider)")
            
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                    if let error = error {
                        print("❌ Error loading URL: \(error.localizedDescription)")
                    }
                    
                    self?.handleURLItem(item)
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                    if let error = error {
                        print("❌ Error loading text: \(error.localizedDescription)")
                    }
                    
                    if let text = item as? String {
                        self?.handleTextItem(text)
                    }
                }
            }
        } else {
            print("❌ No suitable provider found")
        }
    }

    private func handleURLItem(_ item: NSSecureCoding?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var urlString: String?
            
            if let url = item as? URL {
                urlString = url.absoluteString
            } else if let url = item as? NSURL {
                urlString = url.absoluteString
            }
            
            if let finalURL = urlString {
                self.sharedURL = finalURL
                if self.pageTitle.isEmpty {
                    if let url = URL(string: finalURL) {
                        self.pageTitle = url.host ?? finalURL
                    }
                }
                print("✅ Extracted URL: \(self.sharedURL)")
                self.updateUI()
            } else {
                print("❌ Failed to cast item to URL: \(String(describing: item))")
            }
        }
    }
    
    private func handleTextItem(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📝 Processing text for URL: \(text)")
            
            if let url = self.extractURL(from: text) {
                self.sharedURL = url
                if self.pageTitle.isEmpty {
                    self.pageTitle = url
                }
                print("✅ Extracted URL from text: \(self.sharedURL)")
                self.updateUI()
            } else {
                print("❌ No URL found in text")
            }
        }
    }
    
    private func extractURL(from text: String) -> String? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        if let match = matches?.first, let url = match.url {
            return url.absoluteString
        }
        
        if let url = URL(string: text), url.scheme != nil, url.host != nil {
            return text
        }
        
        return nil
    }
    
    private func setupUI() {
        view.subviews.forEach { $0.removeFromSuperview() }
        
        // Helper for localized strings
        func L(_ key: String, _ fallback: String) -> String {
            let localized = NSLocalizedString(key, comment: "")
            return localized == key ? fallback : localized
        }
        
        // Main container with padding
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
        
        // Title label
        let titleLabel = NSTextField(labelWithString: L("share.extension.title.label", "Title"))
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Title text field
        let titleField = NSTextField()
        titleField.placeholderString = L("link.title.placeholder", "e.g., LinkedIn Profile")
        titleField.font = .systemFont(ofSize: 13)
        titleField.isBordered = true
        titleField.bezelStyle = .roundedBezel
        titleField.translatesAutoresizingMaskIntoConstraints = false
        self.titleTextField = titleField
        containerView.addSubview(titleField)
        
        // URL label
        let urlLabel = NSTextField(labelWithString: L("share.extension.url.label", "URL"))
        urlLabel.font = .systemFont(ofSize: 13, weight: .medium)
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(urlLabel)
        
        // URL text field (read-only)
        let urlField = NSTextField()
        urlField.font = .systemFont(ofSize: 12)
        urlField.isBordered = true
        urlField.isEditable = false
        urlField.isSelectable = true
        urlField.backgroundColor = NSColor.controlBackgroundColor
        urlField.bezelStyle = .roundedBezel
        urlField.translatesAutoresizingMaskIntoConstraints = false
        self.urlTextField = urlField
        containerView.addSubview(urlField)
        
        // Warning label
        let warning = NSTextField(labelWithString: "")
        warning.font = .systemFont(ofSize: 11)
        warning.textColor = .systemOrange
        warning.isHidden = true
        warning.translatesAutoresizingMaskIntoConstraints = false
        self.warningLabel = warning
        containerView.addSubview(warning)
        
        // Cancel button
        let cancelBtn = NSButton()
        cancelBtn.title = L("button.cancel", "Cancel")
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.target = self
        cancelBtn.action = #selector(cancelAction(_:))
        self.cancelButton = cancelBtn
        containerView.addSubview(cancelBtn)
        
        // Add button
        let addBtn = NSButton()
        addBtn.title = L("share.extension.add.button", "Add to LinkShelf")
        addBtn.bezelStyle = .rounded
        addBtn.keyEquivalent = "\r"
        addBtn.isHighlighted = true
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addBtn.target = self
        addBtn.action = #selector(addAction(_:))
        self.addButton = addBtn
        containerView.addSubview(addBtn)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Title field
            titleField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            titleField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleField.heightAnchor.constraint(equalToConstant: 24),
            
            // URL label
            urlLabel.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 16),
            urlLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            urlLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // URL field
            urlField.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 6),
            urlField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            urlField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            urlField.heightAnchor.constraint(equalToConstant: 24),
            
            // Warning label
            warning.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 8),
            warning.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            warning.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            // Buttons
            cancelBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            cancelBtn.trailingAnchor.constraint(equalTo: addBtn.leadingAnchor, constant: -10),
            cancelBtn.widthAnchor.constraint(equalToConstant: 80),
            cancelBtn.heightAnchor.constraint(equalToConstant: 32),
            
            addBtn.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            addBtn.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            addBtn.widthAnchor.constraint(equalToConstant: 140),
            addBtn.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    private func updateUI() {
        guard !sharedURL.isEmpty else { return }
        guard let urlField = urlTextField, let titleField = titleTextField else {
            // Retry if UI not ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.updateUI()
            }
            return
        }
        
        // Normalize URL
        var finalURL = sharedURL.trimmingCharacters(in: .whitespaces)
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "https://" + finalURL
        }
        
        urlField.stringValue = finalURL
        
        // Set title
        if !pageTitle.isEmpty && pageTitle != sharedURL {
            titleField.stringValue = pageTitle
        } else {
            if let url = URL(string: finalURL), let host = url.host {
                titleField.stringValue = host.replacingOccurrences(of: "www.", with: "")
            } else {
                titleField.stringValue = finalURL
            }
        }
        
        // Check for duplicate
        if SharedLinkStorage.shared.linkExists(url: finalURL) {
            warningLabel.stringValue = NSLocalizedString("share.extension.url.exists", comment: "⚠️ This URL already exists in LinkShelf")
            warningLabel.isHidden = false
        } else {
            warningLabel.isHidden = true
        }
    }
    
    @objc private func cancelAction(_ sender: Any?) {
        print("🚫 Cancel button pressed")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let context = self.storedContext ?? self.extensionContext else {
                print("❌ No extension context found to complete request")
                // Try to find context from parent or view if possible, but usually self.extensionContext is correct
                return
            }
            
            context.completeRequest(returningItems: nil, completionHandler: { success in
                print("Cancel completed: \(success)")
            })
        }
    }
    
    @objc private func addAction(_ sender: Any?) {
        print("➕ Add button pressed")
        
        guard let titleField = titleTextField, let urlField = urlTextField else {
            print("❌ Text fields not available")
            return
        }
        
        var title = titleField.stringValue.trimmingCharacters(in: .whitespaces)
        var url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        
        // Use sharedURL if field is empty
        if url.isEmpty && !sharedURL.isEmpty {
            url = sharedURL
        }
        
        print("📝 Title: '\(title)', URL: '\(url)'")
        
        // Validate
        if title.isEmpty {
            if !url.isEmpty {
                if let urlObj = URL(string: url), let host = urlObj.host {
                    title = host.replacingOccurrences(of: "www.", with: "")
                } else {
                    title = url
                }
            } else {
                print("⚠️ Title is empty and no URL")
                titleField.becomeFirstResponder()
                return
            }
        }
        
        if url.isEmpty {
            print("⚠️ URL is empty")
            urlField.becomeFirstResponder()
            return
        }
        
        // Normalize URL
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        
        // Validate URL
        guard URL(string: url) != nil else {
            print("❌ Invalid URL: \(url)")
            return
        }
        
        print("💾 Saving link - Title: '\(title)', URL: '\(url)'")
        
        // Save link
        SharedLinkStorage.shared.addLink(title: title, url: url)
        
        print("✅ Link saved, closing extension")
        
        // Close extension
        let context = storedContext ?? self.extensionContext
        context?.completeRequest(returningItems: nil, completionHandler: { success in
            print("Add completed: \(success)")
        })
    }
}
