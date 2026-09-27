import Foundation
import LinkShelfDomain
import Testing

struct LinkURLTests {
    @Test func addsHTTPSWhenSchemeIsMissing() throws {
        #expect(try LinkURL(validating: "  example.com/Path ").string == "https://example.com/Path")
        #expect(try LinkURL(validating: "localhost:3000/a").string == "https://localhost:3000/a")
    }

    @Test func preservesMeaningfulComponents() throws {
        let url = try LinkURL(validating: "HTTPS://Example.COM/Docs/Page/?b=2&a=1#Section")
        #expect(url.string == "https://example.com/Docs/Page/?b=2&a=1#Section")
        #expect(url.comparisonKey == "https://example.com/Docs/Page/?b=2&a=1#Section")
    }

    @Test func comparisonDistinguishesPathCaseAndTrailingSlash() throws {
        let keys = try ["example.com/a", "example.com/A", "example.com/a/"].map {
            try LinkURL(validating: $0).comparisonKey
        }
        #expect(Set(keys).count == 3)
    }

    @Test func comparisonIgnoresHostCaseAndDefaultPorts() throws {
        let plain = try LinkURL(validating: "https://example.com/x").comparisonKey
        #expect(try LinkURL(validating: "https://EXAMPLE.com:443/x").comparisonKey == plain)
        #expect(try LinkURL(validating: "https://example.com:8443/x").comparisonKey != plain)
        #expect(try LinkURL(validating: "http://example.com:80/x").comparisonKey == "http://example.com/x")
    }

    @Test(arguments: [
        ("", LinkShelfError.emptyURL),
        ("javascript:alert(1)", .unsupportedScheme("javascript")),
        ("mailto:someone@example.com", .unsupportedScheme("mailto")),
        ("ftp://example.com", .unsupportedScheme("ftp")),
        ("https://user:secret@example.com", .embeddedCredentials),
        ("https:///path", .missingHost),
        ("exa mple.com", .malformedURL)
    ])
    func rejectsUnsupportedInput(input: String, expected: LinkShelfError) {
        #expect(throws: expected) { try LinkURL(validating: input) }
    }

    @Test func schemelessInputWithColonInPathIsNotAScheme() throws {
        #expect(try LinkURL(validating: "example.com/a:b").string == "https://example.com/a:b")
    }

    @Test func openableURLRevalidatesStoredValues() {
        #expect(LinkURL.openableURL(from: "https://example.com") != nil)
        #expect(LinkURL.openableURL(from: "javascript:alert(1)") == nil)
        #expect(LinkURL.comparisonKey(forStored: "not a url") == "invalid:not a url")
    }

    @Test func draftRequiresTitle() throws {
        #expect(throws: LinkShelfError.emptyTitle) {
            try LinkDraft(title: "   ", url: "example.com").validated()
        }
        #expect(try LinkDraft(title: " Docs ", url: "example.com").validated().title == "Docs")
    }

    @Test func folderNamesRejectSeparators() throws {
        #expect(try FolderName.validate("  Work ") == "Work")
        #expect(try FolderName.validate("News/Tech") == "News/Tech")
        #expect(throws: LinkShelfError.invalidFolderName) { try FolderName.validate("a / b") }
        #expect(throws: LinkShelfError.invalidFolderName) { try FolderName.validate(" \n ") }
    }
}
