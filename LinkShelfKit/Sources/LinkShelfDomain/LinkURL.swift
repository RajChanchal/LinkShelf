import Foundation

/// A validated HTTP(S) link address (FR-02).
///
/// Validation trims surrounding whitespace, adds `https://` when no scheme is
/// present, lowercases the scheme and host, and rejects unsupported schemes,
/// missing hosts, and embedded credentials. Path, query, and fragment are kept
/// exactly as entered, including their case and trailing slashes.
public struct LinkURL: Hashable, Sendable {
    public static let supportedSchemes: Set<String> = ["http", "https"]

    /// The value to persist and open.
    public let string: String
    /// Key for duplicate detection. Only the scheme, host, and default ports
    /// are canonicalized; everything else is compared verbatim.
    public let comparisonKey: String

    public init(validating input: String) throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LinkShelfError.emptyURL }
        let candidate = Self.hasExplicitScheme(trimmed) ? trimmed : "https://" + trimmed

        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased() else {
            throw LinkShelfError.malformedURL
        }
        guard Self.supportedSchemes.contains(scheme) else {
            throw LinkShelfError.unsupportedScheme(scheme)
        }
        guard let host = components.percentEncodedHost, !host.isEmpty else {
            throw LinkShelfError.missingHost
        }
        guard components.percentEncodedUser == nil, components.percentEncodedPassword == nil else {
            throw LinkShelfError.embeddedCredentials
        }

        components.scheme = scheme
        components.percentEncodedHost = host.lowercased()
        guard let string = components.string, URL(string: string) != nil else {
            throw LinkShelfError.malformedURL
        }
        self.string = string
        self.comparisonKey = Self.comparisonKey(for: components, scheme: scheme)
    }

    /// Revalidates a stored value before opening it. Historic or synced values
    /// that fail validation are kept for correction but cannot be opened.
    public static func openableURL(from stored: String) -> URL? {
        guard let validated = try? LinkURL(validating: stored) else { return nil }
        return URL(string: validated.string)
    }

    /// Comparison key for a stored value that may predate validation.
    public static func comparisonKey(forStored stored: String) -> String {
        if let validated = try? LinkURL(validating: stored) {
            return validated.comparisonKey
        }
        return "invalid:" + stored.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Distinguishes `mailto:x` or `javascript:x` (explicit schemes) from
    /// `localhost:3000` or `example.com/a:b` (schemeless host input).
    static func hasExplicitScheme(_ value: String) -> Bool {
        guard let colon = value.firstIndex(of: ":") else { return false }
        let prefix = value[..<colon]
        guard let first = prefix.first, first.isASCII, first.isLetter,
              prefix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "+.-".contains($0)) }) else {
            return false
        }
        let remainder = value[value.index(after: colon)...]
        if remainder.hasPrefix("//") { return true }
        let portCandidate = remainder.prefix { !"/?#".contains($0) }
        let looksLikePort = !portCandidate.isEmpty && portCandidate.allSatisfy { $0.isASCII && $0.isNumber }
        return !looksLikePort
    }

    private static func comparisonKey(for components: URLComponents, scheme: String) -> String {
        var key = scheme + "://" + (components.percentEncodedHost ?? "").lowercased()
        if let port = components.port, port != defaultPort(for: scheme) {
            key += ":\(port)"
        }
        key += components.percentEncodedPath
        if let query = components.percentEncodedQuery { key += "?" + query }
        if let fragment = components.percentEncodedFragment { key += "#" + fragment }
        return key
    }

    private static func defaultPort(for scheme: String) -> Int? {
        switch scheme {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }
}
