//
//  LocalizedStrings.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation

// Localized string keys
enum L10n: String {
    // App name
    case appName = "app.name"
    
    // Empty states
    case emptyStateTitle = "empty.state.title"
    case emptyStateMessage = "empty.state.message"
    case addFirstLink = "empty.state.add.first.link"
    case quickTips = "empty.state.quick.tips"
    case tipCopyLinks = "empty.state.tip.copy.links"
    case tipOpenLinks = "empty.state.tip.open.links"
    case tipSearchLinks = "empty.state.tip.search.links"
    
    // Search
    case searchPlaceholder = "search.placeholder"
    case noResultsFound = "search.no.results"
    case noResultsMessage = "search.no.results.message"
    case clearSearch = "search.clear"
    case tryLabel = "search.try.label"
    case tryCheckSpelling = "search.try.check.spelling"
    case trySearchByTitle = "search.try.search.by.title"
    
    // Add/Edit Link
    case addLink = "link.add"
    case editLink = "link.edit"
    case linkTitle = "link.title"
    case linkURL = "link.url"
    case linkFolder = "link.folder"
    case linkTitlePlaceholder = "link.title.placeholder"
    case linkURLPlaceholder = "link.url.placeholder"
    case linkFolderPlaceholder = "link.folder.placeholder"
    case linkNoFolder = "link.no.folder"
    case linkFolderChoose = "link.folder.choose"
    case cancel = "button.cancel"
    case add = "button.add"
    case save = "button.save"
    case delete = "button.delete"
    case edit = "button.edit"
    
    // Errors
    case errorTitleRequired = "error.title.required"
    case errorURLRequired = "error.url.required"
    case errorInvalidURL = "error.invalid.url"
    
    // Actions
    case copyToClipboard = "action.copy.to.clipboard"
    case copied = "action.copied"
    case openInBrowser = "action.open.in.browser"
    case quitApp = "action.quit.app"
    
    // Menu
    case quitLinkShelf = "menu.quit.linkshelf"
    
    // Share Extension
    case shareExtensionTitle = "share.extension.title"
    case shareExtensionAddButton = "share.extension.add.button"
    case shareExtensionUrlLabel = "share.extension.url.label"
    case shareExtensionTitleLabel = "share.extension.title.label"
    case shareExtensionUrlExists = "share.extension.url.exists"
    
    // Shortcuts
    case shortcutTooltip = "shortcut.tooltip"
    case shortcutIntroTitle = "shortcut.intro.title"
    case shortcutIntroMessage = "shortcut.intro.message"
    case shortcutIntroButton = "shortcut.intro.button"
    
    var localized: String {
        String(
            localized: String.LocalizationValue(rawValue),
            table: "Localizable",
            bundle: .main,
            locale: .current,
            comment: ""
        )
    }

    /// Formats a translated string while honoring the user's current locale.
    /// Translation entries may use positional placeholders such as `%1$@`.
    func formatted(_ arguments: CVarArg...) -> String {
        String(format: localized, locale: .current, arguments: arguments)
    }
}

// Convenience alias for shorter usage
typealias L = L10n
