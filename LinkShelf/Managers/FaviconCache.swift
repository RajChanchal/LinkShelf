//
//  FaviconCache.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import CryptoKit
import Foundation

/// Local, replaceable favicon storage keyed by host. Icons are never part of
/// the synced link records; a missing or stale icon is simply refetched.
actor FaviconCache {
    static let shared = FaviconCache()

    private let directory: URL?
    private let maximumEntries: Int
    private let maximumAge: TimeInterval

    init(directory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Favicons", isDirectory: true),
         maximumEntries: Int = 1_000,
         maximumAge: TimeInterval = 30 * 24 * 60 * 60) {
        self.directory = directory
        self.maximumEntries = maximumEntries
        self.maximumAge = maximumAge
    }

    /// Cached icon for the URL's host, or `nil` when absent or expired.
    func data(for urlString: String) -> Data? {
        guard let fileURL = fileURL(for: urlString),
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modified = attributes[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < maximumAge else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    func store(_ data: Data, for urlString: String) {
        guard let directory, let fileURL = fileURL(for: urlString) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
        evictIfNeeded(in: directory)
    }

    private func fileURL(for urlString: String) -> URL? {
        guard let directory, let host = URL(string: urlString)?.host?.lowercased(), !host.isEmpty else { return nil }
        let name = SHA256.hash(data: Data(host.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }

    private func evictIfNeeded(in directory: URL) {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys),
              files.count > maximumEntries else { return }
        let dated = files.map { file in
            (file, (try? file.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast)
        }
        for (file, _) in dated.sorted(by: { $0.1 < $1.1 }).prefix(files.count - maximumEntries) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
