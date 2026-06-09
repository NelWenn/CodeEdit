@testable import CodeEdit
import XCTest

final class ClaudeSettingsStoreTests: XCTestCase {
    func testReadsModelAndEffort() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
        try #"{"model":"opus","effortLevel":"xhigh","permissions":{"allow":[]}}"#.write(to: url, atomically: true, encoding: .utf8)
        let store = ClaudeSettingsStore(url: url)
        XCTAssertEqual(store.read()?.model, "opus")
        XCTAssertEqual(store.read()?.effort, "xhigh")
    }

    func testWritePreservesOtherKeys() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).json")
        try #"{"model":"opus","effortLevel":"xhigh","tui":"fullscreen"}"#.write(to: url, atomically: true, encoding: .utf8)
        let store = ClaudeSettingsStore(url: url)
        try store.update(model: "sonnet", effort: "high")
        let raw = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(raw.contains("\"tui\""))
        XCTAssertEqual(store.read()?.model, "sonnet")
        XCTAssertEqual(store.read()?.effort, "high")
    }
}
