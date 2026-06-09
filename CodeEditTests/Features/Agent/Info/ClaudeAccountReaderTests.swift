@testable import CodeEdit
import XCTest

final class ClaudeAccountReaderTests: XCTestCase {
    private func fixtureURL(_ name: String) -> URL {
        Bundle(for: Self.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("Fixtures/\(name).json")
    }

    func testParsesAccountFromClaudeJSON() throws {
        let account = try ClaudeAccountReader.read(claudeJSONURL: fixtureURL("oauth-account"))
        XCTAssertEqual(account.email, "contact@bryanmourier.com")
        XCTAssertEqual(account.planDisplayName, "Max 20x")
    }

    func testTierMapping() {
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "default_claude_max_20x"), "Max 20x")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "default_claude_max_5x"), "Max 5x")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "default_claude_pro"), "Pro")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "something_else"), "Something Else")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: nil), "Unknown")
    }
}
