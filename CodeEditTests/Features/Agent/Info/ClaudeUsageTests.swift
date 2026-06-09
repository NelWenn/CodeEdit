@testable import CodeEdit
import XCTest

final class ClaudeUsageTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name).json")
        return try Data(contentsOf: url)
    }

    func testDecodesEndpointPayload() throws {
        let usage = try ClaudeUsage(endpointData: fixture("usage-endpoint"))
        XCTAssertEqual(usage.session?.usedPercent, 15.0)
        XCTAssertEqual(usage.weekly?.usedPercent, 5.0)
        XCTAssertEqual(usage.weeklySonnet?.usedPercent, 0.0)
        XCTAssertNotNil(usage.session?.resetsAt)   // ISO8601 with microseconds must parse
    }
}
