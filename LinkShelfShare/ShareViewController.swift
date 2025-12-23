//
//  ShareViewController.swift
//  LinkShelfShare
//
//  Created for LinkShelf
//

import Cocoa
import AppKit

class ShareViewController: NSViewController, NSExtensionRequestHandling {
    
    private var urlTextField: NSTextField!
    private var titleTextField: NSTextField!
    private var warningLabel: NSTextField!
    private var addButton: NSButton!
    private var cancelButton: NSButton!
    
    private var sharedURL: String = ""
    private var pageTitle: String = ""
    private var extensionContext: NSExtensionContext?
    
    override func loadView() {
        // Create the view programmatically
        view = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        setupUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func beginRequest(with context: NSExtensionContext) {
        self.extensionContext = context
        
        // Extract URL and title from shared items
        guard let inputItems = context.inputItems as? [NSExtensionItem],
              let item = inputItems.first else {
            cancelRequest()
            return
        }
        
        // Extract title if available
        if let title = item.attributedTitle?.string, !title.isEmpty {
            pageTitle = title
        } else if let contentText = item.attributedContentText?.string, !contentText.isEmpty {
            pageTitle = contentText
        }
        
        // Extract URL
        if let attachments = item.attachments {
            var foundURL = false
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier("public.url") {
                    foundURL = true
                    attachment.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                        DispatchQueue.main.async {
                            if let url = item as? URL {
                                self?.sharedURL = url.absoluteString
                                if self?.pageTitle.isEmpty ?? true {
                                    self?.pageTitle = url.host ?? url.absoluteString
                                }
                                self?.updateUI()
                            }
                        }
                    }
                    break
                }
            }
            
            // If no URL found, try plain text
            if !foundURL {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier("public.plain-text") {
                        attachment.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                            DispatchQueue.main.async {
                                if let text = item as? String {
                                    // Try to extract URL from text
                                    if let url = self?.extractURL(from: text) {
                                        self?.sharedURL = url
                                        if self?.pageTitle.isEmpty ?? true {
                                            self?.pageTitle = url
                                        }
                                        self?.updateUI()
                                    }
                                }
                            }
                        }
                        break
                    }
                }
            }
        }
    }
    
    private func extractURL(from text: String) -> String? {
        // Simple URL extraction from text
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        if let match = matches?.first, let url = match.url {
            return url.absoluteString
        }
        
        // Fallback: check if entire text is a URL
        if let url = URL(string: text), url.scheme != nil, url.host != nil {
            return text
        }
        
        return nil
    }
    
    private func setupUI() {
        // Remove existing subviews
        view.subviews.forEach { $0.removeFromSuperview() }
        
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        // Title label
        let titleLabel = NSTextField(labelWithString: NSLocalizedString("share.extension.title.label", comment: ""))
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        stackView.addArrangedSubview(titleLabel)
        
        // Title text field
        let titleField = NSTextField()
        titleField.placeholderString = NSLocalizedString("link.title.placeholder", comment: "")
        titleField.font = .systemFont(ofSize: 13)
        titleField.isBordered = true
        titleField.bezelStyle = .roundedBezel
        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        titleField.widthAnchor.constraint(equalToConstant: 460).isActive = true
        self.titleTextField = titleField
        stackView.addArrangedSubview(titleField)
        
        // URL label
        let urlLabel = NSTextField(labelWithString: NSLocalizedString("share.extension.url.label", comment: ""))
        urlLabel.font = .systemFont(ofSize: 13, weight: .medium)
        stackView.addArrangedSubview(NSView()) // Spacer
        stackView.addArrangedSubview(urlLabel)
        
        // URL text field (read-only)
        let urlField = NSTextField()
        urlField.font = .systemFont(ofSize: 12)
        urlField.isBordered = true
        urlField.isEditable = false
        urlField.isSelectable = true
        urlField.backgroundColor = NSColor.controlBackgroundColor
        urlField.bezelStyle = .roundedBezel
        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.heightAnchor.constraint(equalToConstant: 24).isActive = true
        urlField.widthAnchor.constraint(equalToConstant: 460).isActive = true
        self.urlTextField = urlField
        stackView.addArrangedSubview(urlField)
        
        // Warning label (hidden by default)
        let warning = NSTextField(labelWithString: "")
        warning.font = .systemFont(ofSize: 11)
        warning.textColor = .systemOrange
        warning.isHidden = true
        warning.translatesAutoresizingMaskIntoConstraints = false
        self.warningLabel = warning
        stackView.addArrangedSubview(warning)
        
        // Button container
        let buttonStack = NSStackView()
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .trailing
        buttonStack.distribution = .fill
        
        // Cancel button
        let cancelBtn = NSButton(title: NSLocalizedString("button.cancel", comment: ""), target: self, action: #selector(cancelAction))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1b}" // Escape key
        self.cancelButton = cancelBtn
        buttonStack.addArrangedSubview(cancelBtn)
        
        // Add button
        let addBtn = NSButton(title: NSLocalizedString("share.extension.add.button", comment: ""), target: self, action: #selector(addAction))
        addBtn.bezelStyle = .rounded
        addBtn.keyEquivalent = "\r" // Enter key
        addBtn.isHighlighted = true
        self.addButton = addBtn
        buttonStack.addArrangedSubview(addBtn)
        
        stackView.addArrangedSubview(NSView()) // Spacer
        stackView.addArrangedSubview(buttonStack)
        
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func updateUI() {
        guard !sharedURL.isEmpty else { return }
        
        // Normalize URL
        var finalURL = sharedURL.trimmingCharacters(in: .whitespaces)
        if !finalURL.hasPrefix("http://") && !finalURL.hasPrefix("https://") {
            finalURL = "https://" + finalURL
        }
        
        urlTextField.stringValue = finalURL
        
        // Set title (use page title if available, otherwise use URL)
        if !pageTitle.isEmpty && pageTitle != sharedURL {
            titleTextField.stringValue = pageTitle
        } else {
            // Extract domain name as default title
            if let url = URL(string: finalURL), let host = url.host {
                titleTextField.stringValue = host.replacingOccurrences(of: "www.", with: "")
            } else {
                titleTextField.stringValue = finalURL
            }
        }
        
        // Check for duplicate
        checkForDuplicate(url: finalURL)
    }
    
    private func checkForDuplicate(url: String) {
        if SharedLinkStorage.shared.linkExists(url: url) {
            warningLabel.stringValue = NSLocalizedString("share.extension.url.exists", comment: "")
            warningLabel.isHidden = false
        } else {
            warningLabel.isHidden = true
        }
    }
    
    @objc private func cancelAction() {
        cancelRequest()
    }
    
    @objc private func addAction() {
        let title = titleTextField.stringValue.trimmingCharacters(in: .whitespaces)
        var url = urlTextField.stringValue.trimmingCharacters(in: .whitespaces)
        
        // Validate
        if title.isEmpty {
            titleTextField.becomeFirstResponder()
            return
        }
        
        if url.isEmpty {
            urlTextField.becomeFirstResponder()
            return
        }
        
        // Normalize URL
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }
        
        // Validate URL
        guard URL(string: url) != nil else {
            // Show error
            return
        }
        
        // Save link
        SharedLinkStorage.shared.addLink(title: title, url: url)
        
        // Close extension
        cancelRequest()
    }
    
    private func cancelRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

