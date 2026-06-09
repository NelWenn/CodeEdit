@testable import CodeEdit
import XCTest

final class ClaudeSessionCommandTests: XCTestCase {
    func testFreshSessionUsesSessionId() {
        let cmd = ClaudeSession.launchCommand(
            sessionId: "11111111-2222-3333-4444-555555555555",
            resume: false, model: nil, effort: nil
        )
        XCTAssertEqual(cmd, "claude --session-id 11111111-2222-3333-4444-555555555555")
    }

    func testResumeUsesResume() {
        let cmd = ClaudeSession.launchCommand(
            sessionId: "abc", resume: true, model: nil, effort: nil
        )
        XCTAssertEqual(cmd, "claude --resume abc")
    }

    func testAppendsModelAndEffort() {
        let cmd = ClaudeSession.launchCommand(
            sessionId: "abc", resume: true, model: "opus", effort: "xhigh"
        )
        XCTAssertEqual(cmd, "claude --resume abc --model opus --effort xhigh")
    }

    func testUltracodeUsesSettingsFlag() {
        let cmd = ClaudeSession.launchCommand(
            sessionId: "abc", resume: false, model: "opus", effort: "ultracode"
        )
        XCTAssertEqual(cmd, "claude --session-id abc --model opus --settings '{\"ultracode\": true}'")
    }
}
