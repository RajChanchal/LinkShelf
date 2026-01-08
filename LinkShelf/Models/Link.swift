//
//  Link.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation

struct Link: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var url: String
    var order: Int
    var folder: String?
    var faviconData: Data?
    
    init(id: UUID = UUID(), title: String, url: String, order: Int = 0, folder: String? = nil, faviconData: Data? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.order = order
        self.folder = folder
        self.faviconData = faviconData
    }
    
    var isValidURL: Bool {
        guard let url = URL(string: url),
              url.scheme != nil,
              url.host != nil else {
            return false
        }
        return true
    }
}
