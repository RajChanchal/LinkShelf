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
        // Extract URL and title from shared items
        guard let inputItems = context.inputItems as? [NSExtensionItem],
              let item = inputItems.first else {
            extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            return
        }
        
        // Extract title if available
        if let title = item.attributedTitle?.string, !title.isEmpty {
            pageTitle = title
        } else if let contentText = item.attributedContentText?.string, !contentText.isEmpty {
            pageTitle = contentText
        }
        
        // Extract URL from attachments
        if let attachments = item.attachments {
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("public.url") {
                    attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if let url = item as? URL {
                                self.sharedURL = url.absoluteString
                                if self.pageTitle.isEmpty {
                                    self.pageTitle = url.host ?? url.absoluteString
                                }
                                self.updateUI()
                            }
                        }
                    }
                    return
                }
            }
            
            // If no URL found, try plain text
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                    attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if let text = item as? String, let url = self.extractURL(from: text) {
                                self.sharedURL = url
                                if self.pageTitle.isEmpty {
                                    self.pageTitle = url
                                }
                                self.updateUI()
                            }
                        }
                    }
                    return
                }
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
        cancelBtn.target = self
        cancelBtn.action = #selector(cancelAction)
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        self.cancelButton = cancelBtn
        containerView.addSubview(cancelBtn)
        
        // Add button
        let addBtn = NSButton()
        addBtn.title = L("share.extension.add.button", "Add to LinkShelf")
        addBtn.target = self
        addBtn.action = #selector(addAction)
        addBtn.bezelStyle = .rounded
        addBtn.keyEquivalent = "\r"
        addBtn.isHighlighted = true
        addBtn.translatesAutoresizingMaskIntoConstraints = false
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
    
    @objc private func cancelAction() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func addAction() {
        guard let titleField = titleTextField, let urlField = urlTextField else { return }
        
        var title = titleField.stringValue.trimmingCharacters(in: .whitespaces)
        var url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
        
        // Use sharedURL if field is empty
        if url.isEmpty && !sharedURL.isEmpty {
            url = sharedURL
        }
        
        // Validate
        if title.isEmpty {
            if !url.isEmpty {
                if let urlObj = URL(string: url), let host = urlObj.host {
                    title = host.replacingOccurrences(of: "www.", with: "")
                } else {
                    title = url
                }
            } else {
                titleField.becomeFirstResponder()
                return
            }
        }
        
        if url.isEmpty {
            urlField.becomeFirstResponder()
            return
        }
        
        // Normalize URL
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        
        // Validate URL
        guard URL(string: url) != nil else {
            return
        }
        
        // Save link
        SharedLinkStorage.shared.addLink(title: title, url: url)
        
        // Close extension
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
