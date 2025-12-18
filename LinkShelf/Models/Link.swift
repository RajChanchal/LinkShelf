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
    
    init(id: UUID = UUID(), title: String, url: String, order: Int = 0) {
        self.id = id
        self.title = title
        self.url = url
        self.order = order
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

