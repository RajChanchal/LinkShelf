import Foundation

struct ImportedBookmark: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: String
    let folder: String?
}

enum BookmarkImportError: LocalizedError {
    case unreadableFile, noBookmarks
    var errorDescription: String? {
        switch self {
        case .unreadableFile: return "The bookmark file could not be read."
        case .noBookmarks: return "No web bookmarks were found in this file."
        }
    }
}

struct BookmarkImporter {
    func parse(file url: URL) throws -> [ImportedBookmark] {
        guard let data = try? Data(contentsOf: url), let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { throw BookmarkImportError.unreadableFile }
        let regex = try NSRegularExpression(pattern: #"(?is)<H3\b[^>]*>(.*?)</H3>|<DL\b[^>]*>|</DL\s*>|<A\b[^>]*HREF\s*=\s*[\"']([^\"']+)[\"'][^>]*>(.*?)</A>"#)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var folders: [String] = []
        var pendingFolder: String?
        var result: [ImportedBookmark] = []

        for match in regex.matches(in: html, range: range) {
            if let headingRange = Range(match.range(at: 1), in: html) {
                pendingFolder = cleanHTML(String(html[headingRange]))
            } else if match.range(at: 0).location != NSNotFound,
                      let tokenRange = Range(match.range, in: html) {
                let token = String(html[tokenRange]).uppercased()
                if token.hasPrefix("<DL") {
                    if let pendingFolder, !pendingFolder.isEmpty { folders.append(pendingFolder) }
                    pendingFolder = nil
                } else if token.hasPrefix("</DL") {
                    if !folders.isEmpty { folders.removeLast() }
                } else if let hrefRange = Range(match.range(at: 2), in: html),
                          let titleRange = Range(match.range(at: 3), in: html),
                          let linkURL = URL(string: String(html[hrefRange])),
                          ["http", "https"].contains(linkURL.scheme?.lowercased()) {
                    let title = cleanHTML(String(html[titleRange]))
                    if !title.isEmpty {
                        result.append(ImportedBookmark(title: title, url: linkURL.absoluteString, folder: folders.isEmpty ? nil : folders.joined(separator: " / ")))
                    }
                }
            }
        }
        guard !result.isEmpty else { throw BookmarkImportError.noBookmarks }
        return result
    }

    private func cleanHTML(_ value: String) -> String {
        value.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
