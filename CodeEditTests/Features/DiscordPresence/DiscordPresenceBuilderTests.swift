@testable import CodeEdit
import XCTest

final class DiscordPresenceBuilderTests: XCTestCase {
    func testEditingWithBranchShowsFolderAndBranchNoFileName() {
        let activity = DiscordPresenceBuilder.build(
            DiscordPresenceContext(folder: "smaacks-app", branch: "main", isEditing: true, startTimestamp: 42)
        )
        XCTAssertEqual(activity.details, "smaacks-app")
        XCTAssertEqual(activity.state, "Editing · main")
        XCTAssertEqual(activity.startTimestamp, 42)
        XCTAssertEqual(activity.largeImage, "logo")
        XCTAssertEqual(activity.largeText, "CodeEditAi")
    }

    func testIdleWhenNoFileOpen() {
        let activity = DiscordPresenceBuilder.build(
            DiscordPresenceContext(folder: "smaacks-app", branch: "main", isEditing: false, startTimestamp: 0)
        )
        XCTAssertEqual(activity.state, "Idle · main")
    }

    func testNoBranchOmitsBranchSegment() {
        let activity = DiscordPresenceBuilder.build(
            DiscordPresenceContext(folder: "proj", branch: nil, isEditing: true, startTimestamp: 0)
        )
        XCTAssertEqual(activity.state, "Editing")
    }

    func testNoWorkspaceFallback() {
        let activity = DiscordPresenceBuilder.build(
            DiscordPresenceContext(folder: nil, branch: nil, isEditing: false, startTimestamp: 0)
        )
        XCTAssertEqual(activity.details, "CodeEditAi")
        XCTAssertEqual(activity.state, "Idle")
    }
}
