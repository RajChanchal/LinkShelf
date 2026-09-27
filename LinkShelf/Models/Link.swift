//
//  Link.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation

/// Presentation value for a saved link. Persistence uses `LinkSnapshot`
/// records from LinkShelfKit; `LinkManager` maps between the two.
struct Link: Identifiable, Equatable {
    let id: UUID
    var title: String
    var url: String
    /// Position within its folder, derived from the stored rank.
    var order: Int
    /// Folder path with components separated by " / ", or `nil` when unfiled.
    var folder: String?
    /// Icon from the local favicon cache; never persisted with the link.
    var faviconData: Data?

    init(id: UUID = UUID(), title: String, url: String, order: Int = 0, folder: String? = nil, faviconData: Data? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.order = order
        self.folder = folder
        self.faviconData = faviconData
    }
}
