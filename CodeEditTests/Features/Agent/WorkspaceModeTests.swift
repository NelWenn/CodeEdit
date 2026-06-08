@testable import CodeEdit
import XCTest

final class WorkspaceModeTests: XCTestCase {
    func testRawValuesAreStableForPersistence() {
        XCTAssertEqual(WorkspaceMode.editor.rawValue, "editor")
        XCTAssertEqual(WorkspaceMode.agent.rawValue, "agent")
    }

    func testRoundTripFromRawValue() {
        XCTAssertEqual(WorkspaceMode(rawValue: "agent"), .agent)
        XCTAssertNil(WorkspaceMode(rawValue: "bogus"))
    }

    func testAllCasesCount() {
        XCTAssertEqual(WorkspaceMode.allCases.count, 2)
    }
}
