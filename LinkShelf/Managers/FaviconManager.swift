//
//  FaviconManager.swift
//  LinkShelf
//
//  Created for LinkShelf
//

import Foundation
import AppKit

///Manager to show icons in front of each url
class FaviconManager {
    static let shared = FaviconManager()
    
    private init() {}
    
    /// Fetches favicon for a given URL
    /// - Parameter urlString: The URL string to fetch favicon for
    /// - Returns: Favicon image data, or nil if not found
    func fetchFavicon(for urlString: String) async -> Data? {
        guard let url = URL(string: urlString) else { return nil }
        
        // Ensure URL has a scheme
        var finalURL = url
        if url.scheme == nil {
            finalURL = URL(string: "https://\(urlString)") ?? url
        }
        
        guard let host = finalURL.host else { return nil }
        
        // Try multiple favicon locations
        let faviconPaths = [
            "/favicon.ico",
            "/favicon.png",
            "/apple-touch-icon.png"
        ]
        
        // Try common favicon locations
        for path in faviconPaths {
            if let faviconURL = URL(string: "\(finalURL.scheme ?? "https")://\(host)\(path)"),
               let data = await downloadImage(from: faviconURL) {
                return data
            }
        }
        
        // Try to get favicon from HTML
        if let htmlFavicon = await fetchFaviconFromHTML(url: finalURL) {
            return htmlFavicon
        }
        
        return nil
    }
    
    /// Downloads image data from a URL
    private func downloadImage(from url: URL) async -> Data? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check if response is successful and is an image
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200,
               let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               contentType.hasPrefix("image/") {
                return data
            }
        } catch {
            // Silently fail and try next option
        }
        
        return nil
    }
    
    /// Fetches favicon by parsing HTML for favicon links
    private func fetchFaviconFromHTML(url: URL) async -> Data? {
        do {
            let (htmlData, _) = try await URLSession.shared.data(from: url)
            guard let htmlString = String(data: htmlData, encoding: .utf8) else { return nil }
            
            // Look for favicon in HTML
            let patterns = [
                #"<link[^>]*rel=["'](?:icon|shortcut icon|apple-touch-icon)["'][^>]*href=["']([^"']+)["']"#,
                #"<link[^>]*href=["']([^"']+)["'][^>]*rel=["'](?:icon|shortcut icon|apple-touch-icon)["']"#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)),
                   match.numberOfRanges > 1,
                   let range = Range(match.range(at: 1), in: htmlString) {
                    let faviconPath = String(htmlString[range])
                    
                    // Resolve relative URLs
                    var faviconURL: URL?
                    if faviconPath.hasPrefix("http://") || faviconPath.hasPrefix("https://") {
                        faviconURL = URL(string: faviconPath)
                    } else if faviconPath.hasPrefix("//") {
                        faviconURL = URL(string: "\(url.scheme ?? "https"):\(faviconPath)")
                    } else {
                        faviconURL = URL(string: faviconPath, relativeTo: url)
                    }
                    
                    if let faviconURL = faviconURL,
                       let data = await downloadImage(from: faviconURL) {
                        return data
                    }
                }
            }
        } catch {
            // Silently fail
        }
        
        return nil
    }
    
    /// Creates an NSImage from favicon data
    func image(from data: Data) -> NSImage? {
        return NSImage(data: data)
    }
}




