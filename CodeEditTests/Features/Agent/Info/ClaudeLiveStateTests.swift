@testable import CodeEdit
import XCTest

final class ClaudeLiveStateTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name).json")
        return try Data(contentsOf: url)
    }

    func testDecodesStatusline() throws {
        let state = try ClaudeLiveState(statuslineData: fixture("statusline"))
        XCTAssertEqual(state.modelDisplayName, "Opus 4.8")
        XCTAssertEqual(state.effortLevel, "xhigh")
        XCTAssertEqual(state.thinkingEnabled, true)
        XCTAssertNil(state.contextUsedPercent)
    }
}
