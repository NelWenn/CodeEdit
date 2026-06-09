@testable import CodeEdit
import XCTest

final class DiscordActivityTests: XCTestCase {
    func testEncodesDiscordSnakeCaseKeys() throws {
        let activity = DiscordActivity(
            details: "smaacks-app",
            state: "Editing · main",
            startTimestamp: 1_000,
            largeImage: "logo",
            largeText: "CodeEditAi"
        )
        let data = try JSONEncoder().encode(activity)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["details"] as? String, "smaacks-app")
        XCTAssertEqual(obj["state"] as? String, "Editing · main")
        XCTAssertEqual((obj["timestamps"] as? [String: Any])?["start"] as? Int, 1_000)
        let assets = try XCTUnwrap(obj["assets"] as? [String: Any])
        XCTAssertEqual(assets["large_image"] as? String, "logo")
        XCTAssertEqual(assets["large_text"] as? String, "CodeEditAi")
    }

    func testOmitsEmptySections() throws {
        let activity = DiscordActivity(details: "x", state: nil, startTimestamp: nil,
                                       largeImage: nil, largeText: nil)
        let obj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try JSONEncoder().encode(activity)) as? [String: Any]
        )
        XCTAssertNil(obj["timestamps"])
        XCTAssertNil(obj["assets"])
        XCTAssertNil(obj["state"])
    }
}
