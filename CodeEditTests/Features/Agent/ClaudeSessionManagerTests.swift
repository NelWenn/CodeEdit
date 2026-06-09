@testable import CodeEdit
import XCTest

@MainActor
final class ClaudeSessionManagerTests: XCTestCase {
    func testNewTabAppendsAndActivates() {
        let manager = ClaudeSessionManager()
        let first = manager.newTab()
        let second = manager.newTab()
        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.activeTabID, second.id)
        XCTAssertEqual(manager.openSessionIds, [first.claudeSessionId, second.claudeSessionId])
    }

    func testActivateAndActiveIndex() {
        let manager = ClaudeSessionManager()
        let first = manager.newTab()
        _ = manager.newTab()
        manager.activate(first.id)
        XCTAssertEqual(manager.activeSession?.id, first.id)
        XCTAssertEqual(manager.activeIndex, 0)
    }

    func testClosingActiveTabActivatesNeighbor() {
        let manager = ClaudeSessionManager()
        _ = manager.newTab()
        let second = manager.newTab()
        manager.closeTab(second.id)
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.activeTabID, manager.tabs[0].id)
    }

    func testClosingLastTabOpensFreshOne() {
        let manager = ClaudeSessionManager()
        let only = manager.newTab()
        manager.closeTab(only.id)
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertNotEqual(manager.tabs[0].id, only.id)
        XCTAssertEqual(manager.activeTabID, manager.tabs[0].id)
    }

    func testOpenAlreadyOpenSessionActivatesInsteadOfDuplicating() {
        let manager = ClaudeSessionManager()
        let resumed = manager.newTab(resuming: "session-x", title: "X")
        _ = manager.newTab()
        manager.open(claudeId: "session-x", title: "X", mode: .newTab, model: nil, effort: nil)
        XCTAssertEqual(manager.tabs.filter { $0.claudeSessionId == "session-x" }.count, 1)
        XCTAssertEqual(manager.activeTabID, resumed.id)
    }

    func testOpenInNewTabResumes() {
        let manager = ClaudeSessionManager()
        _ = manager.newTab()
        manager.open(claudeId: "session-y", title: "Y", mode: .newTab, model: nil, effort: nil)
        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.activeSession?.claudeSessionId, "session-y")
        XCTAssertEqual(manager.activeSession?.title, "Y")
    }

    func testOpenInCurrentTabReplacesActiveSessionInPlace() {
        let manager = ClaudeSessionManager()
        let first = manager.newTab()
        let second = manager.newTab()
        manager.open(claudeId: "session-z", title: "Z", mode: .currentTab, model: nil, effort: nil)
        XCTAssertEqual(manager.tabs.count, 2)
        XCTAssertEqual(manager.tabs[0].id, first.id)
        XCTAssertNotEqual(manager.tabs[1].id, second.id)
        XCTAssertEqual(manager.tabs[1].claudeSessionId, "session-z")
        XCTAssertEqual(manager.activeTabID, manager.tabs[1].id)
    }

    func testRestoreRebuildsTabsAndActive() {
        let manager = ClaudeSessionManager()
        manager.restore(
            sessions: [(id: "a", title: "Alpha"), (id: "b", title: "Beta")],
            activeIndex: 1
        )
        XCTAssertEqual(manager.openSessionIds, ["a", "b"])
        XCTAssertEqual(manager.activeSession?.claudeSessionId, "b")
        XCTAssertEqual(manager.activeSession?.title, "Beta")
    }

    func testRestoreEmptyOpensFreshTab() {
        let manager = ClaudeSessionManager()
        manager.restore(sessions: [], activeIndex: 0)
        XCTAssertEqual(manager.tabs.count, 1)
        XCTAssertEqual(manager.activeTabID, manager.tabs[0].id)
    }
}
