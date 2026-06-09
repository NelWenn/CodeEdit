# Claude Sessions & Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run multiple concurrent Claude sessions in Agent mode (each in its own tab) and browse/resume the project's past Claude sessions from a new "Sessions" inspector tab, opening a chosen session in the current tab (default) or a new tab.

**Architecture:** A `ClaudeSessionManager` (owned by `WorkspaceDocument`) holds an ordered array of open tabs, each a `ClaudeSession` bound to one Claude session UUID. A `ClaudeTabBar` sits atop the Agent area; the active tab's `ClaudeAgentView` is shown. A pure `ClaudeSessionsReader` reads `~/.claude/projects/<encoded-cwd>/*.jsonl` to power the Sessions list. Open tabs persist in workspace state and restore via `claude --resume`.

**Tech Stack:** Swift 6.4 / SwiftUI + AppKit, SwiftTerm (`CELocalShellTerminalView`), Claude Code CLI (`--session-id`, `--resume`, `--model`, `--effort`), XCTest (`@testable import CodeEdit`).

---

## Build & Test Commands (this project)

Always set `DEVELOPER_DIR` to the Xcode 27 beta toolchain (Swift 6.4) or Swift-6.4 errors are masked. Read the verdict from the log, **not** a piped exit code.

**Build:**
```bash
cd /Users/theoschneider/Developer/CodeEdit
DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer \
  xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta \
  -skipPackagePluginValidation build > /tmp/ceai_build.log 2>&1
grep -E "BUILD (SUCCEEDED|FAILED)" /tmp/ceai_build.log | tail -1
```

**Run one test suite (TDD):**
```bash
cd /Users/theoschneider/Developer/CodeEdit
DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer \
  xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta \
  -skipPackagePluginValidation test -only-testing:CodeEditTests/<SuiteName> \
  > /tmp/ceai_test.log 2>&1
grep -E "Test Suite .* (passed|failed)|\*\* TEST (SUCCEEDED|FAILED)" /tmp/ceai_test.log | tail -5
```

**Conventions:** new `.swift` files auto-join their target (synchronized file groups — no `.pbxproj` edits). SwiftLint requires identifiers ≥3 chars. App module name is `CodeEdit`.

---

## File Structure

**Create:**
- `CodeEdit/Features/Agent/Sessions/ClaudeSessionsReader.swift` — pure reader of `~/.claude/projects/<encoded-cwd>/*.jsonl` → `[ClaudeSessionInfo]`.
- `CodeEdit/Features/Agent/ClaudeSessionManager.swift` — owns `[ClaudeSession]` tabs + active tab; new/close/activate/open/restore.
- `CodeEdit/Features/Agent/ClaudeTabBar.swift` — Agent-mode tab strip.
- `CodeEdit/Features/Agent/Sessions/ClaudeSessionsListView.swift` — Sessions inspector list.
- `CodeEdit/Features/Agent/Sessions/ClaudeAgentInspectorView.swift` — Info|Sessions switcher for the Agent inspector.
- `CodeEditTests/Features/Agent/Sessions/ClaudeSessionsReaderTests.swift`
- `CodeEditTests/Features/Agent/ClaudeSessionCommandTests.swift`
- `CodeEditTests/Features/Agent/ClaudeSessionManagerTests.swift`

**Modify:**
- `CodeEdit/Features/Agent/ClaudeSession.swift` — per-tab identity (`id`, `claudeSessionId`, `title`), resume-vs-fresh launch, `terminate()`, `prepareLaunch()`.
- `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceStateKey.swift` — two new keys.
- `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift` — replace single `claudeSession` with `claudeSessionManager`; persist/restore tabs.
- `CodeEdit/WorkspaceView.swift` — Agent case renders `ClaudeTabBar` + active session view.
- `CodeEdit/Features/InspectorArea/Views/InspectorAreaView.swift` — Agent inspector shows `ClaudeAgentInspectorView`.

---

## Task 1: `ClaudeSessionsReader` (pure reader)

**Files:**
- Create: `CodeEdit/Features/Agent/Sessions/ClaudeSessionsReader.swift`
- Test: `CodeEditTests/Features/Agent/Sessions/ClaudeSessionsReaderTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `CodeEditTests/Features/Agent/Sessions/ClaudeSessionsReaderTests.swift`:

```swift
@testable import CodeEdit
import XCTest

final class ClaudeSessionsReaderTests: XCTestCase {
    private func makeTempProjectsDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ceai-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func testEncodedProjectDirReplacesNonAlphanumericWithDash() {
        let cwd = URL(fileURLWithPath: "/Users/theo/Documents/Smaacks/smaacks-app")
        XCTAssertEqual(
            ClaudeSessionsReader.encodedProjectDir(for: cwd),
            "-Users-theo-Documents-Smaacks-smaacks-app"
        )
    }

    func testReadsSessionsSortedNewestFirstWithDerivedTitles() throws {
        let base = try makeTempProjectsDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let cwd = URL(fileURLWithPath: "/tmp/proj")
        let dir = base.appendingPathComponent(ClaudeSessionsReader.encodedProjectDir(for: cwd), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Session A: has a summary line.
        let idA = "aaaaaaaa-0000-0000-0000-000000000001"
        try ("{\"type\":\"summary\",\"summary\":\"Refactor the auth flow\"}\n")
            .write(to: dir.appendingPathComponent("\(idA).jsonl"), atomically: true, encoding: .utf8)
        // Session B: no summary, first user message text.
        let idB = "bbbbbbbb-0000-0000-0000-000000000002"
        try ("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"Fix the navbar spacing please\"}}\n")
            .write(to: dir.appendingPathComponent("\(idB).jsonl"), atomically: true, encoding: .utf8)
        // Malformed file: must be skipped, not crash.
        try ("not json at all\n")
            .write(to: dir.appendingPathComponent("cccccccc-0000-0000-0000-000000000003.jsonl"),
                   atomically: true, encoding: .utf8)

        // Make A newer than B.
        let now = Date()
        try FileManager.default.setAttributes([.modificationDate: now],
            ofItemAtPath: dir.appendingPathComponent("\(idA).jsonl").path)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-60)],
            ofItemAtPath: dir.appendingPathComponent("\(idB).jsonl").path)

        let reader = ClaudeSessionsReader(projectsBaseURL: base)
        let sessions = reader.readSessions(for: cwd)

        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].id, idA)
        XCTAssertEqual(sessions[0].title, "Refactor the auth flow")
        XCTAssertEqual(sessions[1].id, idB)
        XCTAssertEqual(sessions[1].title, "Fix the navbar spacing please")
        // Malformed file still listed with a fallback (date) title, not a crash.
        XCTAssertTrue(sessions[2].title.hasPrefix("Session —"))
    }

    func testReturnsEmptyWhenDirMissing() {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ceai-missing-\(UUID().uuidString)", isDirectory: true)
        let reader = ClaudeSessionsReader(projectsBaseURL: base)
        XCTAssertEqual(reader.readSessions(for: URL(fileURLWithPath: "/tmp/none")).count, 0)
    }
}
```

- [ ] **Step 2: Run tests, verify they fail**

Run the test command with `-only-testing:CodeEditTests/ClaudeSessionsReaderTests`.
Expected: FAIL to compile / "cannot find 'ClaudeSessionsReader'".

- [ ] **Step 3: Implement `ClaudeSessionsReader`**

Create `CodeEdit/Features/Agent/Sessions/ClaudeSessionsReader.swift`:

```swift
//
//  ClaudeSessionsReader.swift
//  CodeEdit
//

import Foundation

/// Metadata about one persisted Claude Code session for a project.
struct ClaudeSessionInfo: Identifiable, Equatable {
    /// The Claude session UUID — also the `.jsonl` filename stem.
    let id: String
    let title: String
    let lastModified: Date
}

/// Reads Claude Code session files from `~/.claude/projects/<encoded-cwd>/`.
/// Filesystem-only and side-effect-free so it can be unit-tested with a temp base directory.
struct ClaudeSessionsReader {
    /// Base `~/.claude/projects` directory (overridable for tests).
    let projectsBaseURL: URL

    init(projectsBaseURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)) {
        self.projectsBaseURL = projectsBaseURL
    }

    /// Encodes a working-directory path the way Claude Code names its project folders:
    /// every character that is not an ASCII letter or digit becomes `-`.
    static func encodedProjectDir(for cwd: URL) -> String {
        let path = cwd.path(percentEncoded: false)
        return String(path.map { character in
            (character.isASCII && (character.isLetter || character.isNumber)) ? character : "-"
        })
    }

    /// The directory holding the session `.jsonl` files for `cwd`.
    func sessionsDirectory(for cwd: URL) -> URL {
        projectsBaseURL.appendingPathComponent(Self.encodedProjectDir(for: cwd), isDirectory: true)
    }

    /// All sessions for `cwd`, newest first. Unreadable directories yield an empty array;
    /// individual malformed files still appear (with a date-based fallback title).
    func readSessions(for cwd: URL) -> [ClaudeSessionInfo] {
        let dir = sessionsDirectory(for: cwd)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { sessionInfo(at: $0) }
            .sorted { $0.lastModified > $1.lastModified }
    }

    private func sessionInfo(at url: URL) -> ClaudeSessionInfo? {
        let id = url.deletingPathExtension().lastPathComponent
        guard !id.isEmpty else { return nil }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date.distantPast
        let title = Self.deriveTitle(fromFileAt: url) ?? Self.fallbackTitle(for: modified)
        return ClaudeSessionInfo(id: id, title: title, lastModified: modified)
    }

    /// Scans the JSONL top (≤256 KB) and returns the first good title:
    /// a `summary` entry wins, else the first real user message's text (truncated).
    static func deriveTitle(fromFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 256 * 1024)) ?? Data()
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        var firstUserText: String?
        for line in text.split(separator: "\n") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                continue
            }
            if obj["type"] as? String == "summary", let summary = obj["summary"] as? String {
                let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return truncate(trimmed) }
            }
            if firstUserText == nil,
               obj["type"] as? String == "user",
               obj["attachment"] == nil,                       // skip hook/system injections
               (obj["isMeta"] as? Bool) != true,
               let message = obj["message"] as? [String: Any],
               let content = messageText(message) {
                firstUserText = content
            }
        }
        return firstUserText.map(truncate)
    }

    /// Extracts plain text from a user message's `content` (a string or an array of blocks).
    private static func messageText(_ message: [String: Any]) -> String? {
        if let str = message["content"] as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let blocks = message["content"] as? [[String: Any]] {
            for block in blocks where block["type"] as? String == "text" {
                if let str = block["text"] as? String {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }
        return nil
    }

    private static func truncate(_ text: String, max: Int = 60) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        if oneLine.count <= max { return oneLine }
        return String(oneLine.prefix(max)).trimmingCharacters(in: .whitespaces) + "…"
    }

    static func fallbackTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return "Session — \(formatter.string(from: date))"
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run `-only-testing:CodeEditTests/ClaudeSessionsReaderTests`. Expected: all 3 pass.

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Agent/Sessions/ClaudeSessionsReader.swift \
        CodeEditTests/Features/Agent/Sessions/ClaudeSessionsReaderTests.swift
git commit -m "feat(agent): read project's Claude sessions from disk"
```

---

## Task 2: Launch-command builder

**Files:**
- Modify: `CodeEdit/Features/Agent/ClaudeSession.swift` (add a static builder via extension)
- Test: `CodeEditTests/Features/Agent/ClaudeSessionCommandTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `CodeEditTests/Features/Agent/ClaudeSessionCommandTests.swift`:

```swift
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run `-only-testing:CodeEditTests/ClaudeSessionCommandTests`.
Expected: FAIL — "type 'ClaudeSession' has no member 'launchCommand'".

- [ ] **Step 3: Implement the builder**

Append to `CodeEdit/Features/Agent/ClaudeSession.swift` (after the class, same file):

```swift
extension ClaudeSession {
    /// Builds the shell command that launches `claude` for one tab.
    /// - `resume == false` → start a new session with a known id (`--session-id`).
    /// - `resume == true`  → resume an existing session (`--resume`).
    /// `--continue` keeps a conversation's model/effort, so pass them explicitly when set.
    static func launchCommand(sessionId: String, resume: Bool, model: String?, effort: String?) -> String {
        var command = "claude"
        command += resume ? " --resume \(sessionId)" : " --session-id \(sessionId)"
        if let model, !model.isEmpty { command += " --model \(model)" }
        if let effort, !effort.isEmpty {
            if effort == "ultracode" {
                // `ultracode` is not a --effort value (claude rejects it); it's a session setting
                // (xhigh effort + dynamic-workflow orchestration) enabled via --settings.
                command += " --settings '{\"ultracode\": true}'"
            } else {
                command += " --effort \(effort)"
            }
        }
        return command
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run `-only-testing:CodeEditTests/ClaudeSessionCommandTests`. Expected: all 4 pass.

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Agent/ClaudeSession.swift \
        CodeEditTests/Features/Agent/ClaudeSessionCommandTests.swift
git commit -m "feat(agent): pure launch-command builder for Claude sessions"
```

---

## Task 3: Per-tab `ClaudeSession`

Rewrite `ClaudeSession` so each instance is one tab bound to one Claude session id, launching fresh-or-resume based on whether its `.jsonl` already exists. Keep the launch-command extension from Task 2 in the same file.

**Files:**
- Modify: `CodeEdit/Features/Agent/ClaudeSession.swift`

- [ ] **Step 1: Replace the class body**

Replace everything in `CodeEdit/Features/Agent/ClaudeSession.swift` **above** the `extension ClaudeSession` (added in Task 2) with:

```swift
//
//  ClaudeSession.swift
//  CodeEdit
//

import AppKit
import SwiftTerm

/// Owns one long-lived `claude` terminal for a single Agent tab. The session survives
/// toggling between Editor and Agent modes and switching between tabs (the process runs
/// independently of view attachment).
final class ClaudeSession: ObservableObject, Identifiable {
    /// Stable tab identity (for SwiftUI `id()` and manager lookup).
    let id = UUID()
    /// The Claude session UUID this tab runs (the `.jsonl` filename stem).
    let claudeSessionId: String
    /// Tab label, shown in the tab bar.
    @Published private(set) var title: String
    /// Bumped on restart so the SwiftUI Agent view recreates the terminal.
    @Published private(set) var generation = 0

    private var terminalView: CELocalShellTerminalView?
    private var hasLaunchedClaude = false
    /// Model/effort to force on the next launch (e.g. resuming with the current settings).
    private var relaunchModel: String?
    private var relaunchEffort: String?
    private let reader = ClaudeSessionsReader()

    /// A fresh session with a newly-generated Claude session id.
    init(title: String = "New Session") {
        self.claudeSessionId = UUID().uuidString.lowercased()
        self.title = title
    }

    /// A session bound to an existing Claude session id (resumed from the list or restored).
    init(resuming claudeSessionId: String, title: String) {
        self.claudeSessionId = claudeSessionId
        self.title = title
    }

    func setTitle(_ newTitle: String) {
        guard newTitle != title else { return }
        title = newTitle
    }

    /// Set the model/effort to apply on the next (first) launch, without relaunching now.
    func prepareLaunch(model: String?, effort: String?) {
        relaunchModel = model
        relaunchEffort = effort
    }

    /// Returns the existing terminal view, or creates one rooted at `workspaceURL`, starts the
    /// login shell, and launches `claude` (fresh or resuming this tab's session).
    func makeOrReuseTerminal(workspaceURL: URL?) -> CELocalShellTerminalView {
        if let terminalView { return terminalView }
        let view = CELocalShellTerminalView(frame: .zero)
        view.startProcess(workspaceURL: workspaceURL)
        terminalView = view
        launchClaudeIfNeeded(in: view, workspaceURL: workspaceURL)
        return view
    }

    /// Whether the claude process is currently running.
    var isRunning: Bool { terminalView?.process.running ?? false }

    /// Sends raw text (e.g. a slash command) to the running claude TUI.
    func send(_ text: String) {
        guard let view = terminalView, view.process.running else { return }
        view.process.send(data: Array(text.utf8)[...])
    }

    /// Relaunch this tab (e.g. after a model/effort change), resuming the same conversation.
    func restart(model: String?, effort: String?) {
        relaunchModel = model
        relaunchEffort = effort
        terminalView?.process.terminate()
        terminalView = nil
        hasLaunchedClaude = false
        generation += 1
    }

    /// Terminate this tab's process (on tab close). The session stays on disk and is resumable.
    func terminate() {
        terminalView?.process.terminate()
        terminalView = nil
    }

    private func launchClaudeIfNeeded(in view: CELocalShellTerminalView, workspaceURL: URL?) {
        guard !hasLaunchedClaude else { return }
        hasLaunchedClaude = true
        let resume = sessionFileExists(workspaceURL: workspaceURL)
        let command = Self.launchCommand(
            sessionId: claudeSessionId,
            resume: resume,
            model: relaunchModel,
            effort: relaunchEffort
        ) + "\n"
        // Let the login shell finish initializing (PATH, rc files) before running claude.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak view] in
            guard let view, view.process.running else { return }
            view.process.send(data: Array(command.utf8)[...])
        }
    }

    /// True when this tab's session already has a `.jsonl` on disk (so we `--resume` it rather
    /// than starting it with `--session-id`).
    private func sessionFileExists(workspaceURL: URL?) -> Bool {
        guard let workspaceURL else { return false }
        let file = reader.sessionsDirectory(for: workspaceURL)
            .appendingPathComponent("\(claudeSessionId).jsonl")
        return FileManager.default.fileExists(atPath: file.path(percentEncoded: false))
    }
}
```

- [ ] **Step 2: Keep call sites compiling — note only**

`WorkspaceDocument`, `WorkspaceView`, and `InspectorAreaView` still reference the old single `workspace.claudeSession`. They are updated in Tasks 5–7. Until then the build will fail at those three sites; that is expected and resolved by Task 5. (If implementing strictly task-by-task with a green build between tasks, do Tasks 3→4→5 as a unit before the build/commit in Task 5. The Task 2 command tests already pass and stay green.)

- [ ] **Step 3: Commit**

```bash
git add CodeEdit/Features/Agent/ClaudeSession.swift
git commit -m "feat(agent): per-tab ClaudeSession with resume-or-fresh launch"
```

---

## Task 4: `ClaudeSessionManager`

A manager owning the open tabs. Pure state machine — tests create real `ClaudeSession` objects (constructing one does **not** spawn a process; only `makeOrReuseTerminal` does, which tests never call).

**Files:**
- Create: `CodeEdit/Features/Agent/ClaudeSessionManager.swift`
- Test: `CodeEditTests/Features/Agent/ClaudeSessionManagerTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `CodeEditTests/Features/Agent/ClaudeSessionManagerTests.swift`:

```swift
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
        let first = manager.newTab()              // index 0
        let second = manager.newTab()             // index 1, active
        manager.open(claudeId: "session-z", title: "Z", mode: .currentTab, model: nil, effort: nil)
        XCTAssertEqual(manager.tabs.count, 2)     // no new tab
        XCTAssertEqual(manager.tabs[0].id, first.id)
        XCTAssertNotEqual(manager.tabs[1].id, second.id)       // replaced
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
```

- [ ] **Step 2: Run tests, verify they fail**

Run `-only-testing:CodeEditTests/ClaudeSessionManagerTests`.
Expected: FAIL — "cannot find 'ClaudeSessionManager'".

- [ ] **Step 3: Implement `ClaudeSessionManager`**

Create `CodeEdit/Features/Agent/ClaudeSessionManager.swift`:

```swift
//
//  ClaudeSessionManager.swift
//  CodeEdit
//

import Combine
import Foundation

/// Owns the open Claude tabs for a workspace. Each tab is a ``ClaudeSession``.
@MainActor
final class ClaudeSessionManager: ObservableObject {
    enum OpenMode { case currentTab, newTab }

    @Published private(set) var tabs: [ClaudeSession] = []
    @Published var activeTabID: UUID?

    /// Re-publishes each child session's changes (title/generation) as our own.
    private var cancellables: [UUID: AnyCancellable] = [:]

    /// The active session (falls back to the first tab if the id is stale).
    var activeSession: ClaudeSession? {
        tabs.first { $0.id == activeTabID } ?? tabs.first
    }

    /// Open session ids in tab order (for persistence).
    var openSessionIds: [String] { tabs.map(\.claudeSessionId) }

    /// Index of the active tab (for persistence).
    var activeIndex: Int {
        guard let activeTabID, let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return 0 }
        return idx
    }

    /// Ensure there is at least one tab (called when entering Agent mode).
    func ensureAtLeastOneTab() {
        if tabs.isEmpty { newTab() }
    }

    @discardableResult
    func newTab(resuming claudeId: String? = nil, title: String? = nil) -> ClaudeSession {
        let session = claudeId.map { ClaudeSession(resuming: $0, title: title ?? "Session") }
            ?? ClaudeSession(title: title ?? "New Session")
        track(session)
        tabs.append(session)
        activeTabID = session.id
        return session
    }

    func activate(_ id: UUID) { activeTabID = id }

    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].terminate()
        cancellables[id] = nil
        tabs.remove(at: idx)
        if activeTabID == id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs.indices.contains(newIdx) ? tabs[newIdx].id : nil
        }
        if tabs.isEmpty { newTab() }   // Agent mode always keeps ≥1 tab
    }

    /// Open a session from the list. Activates an already-open tab rather than launching a
    /// second process on the same `.jsonl`.
    func open(claudeId: String, title: String, mode: OpenMode, model: String?, effort: String?) {
        if let existing = tabs.first(where: { $0.claudeSessionId == claudeId }) {
            activeTabID = existing.id
            return
        }
        switch mode {
        case .newTab:
            newTab(resuming: claudeId, title: title).prepareLaunch(model: model, effort: effort)
        case .currentTab:
            guard let active = activeSession, let idx = tabs.firstIndex(where: { $0.id == active.id }) else {
                newTab(resuming: claudeId, title: title).prepareLaunch(model: model, effort: effort)
                return
            }
            active.terminate()
            cancellables[active.id] = nil
            let replacement = ClaudeSession(resuming: claudeId, title: title)
            replacement.prepareLaunch(model: model, effort: effort)
            track(replacement)
            tabs[idx] = replacement
            activeTabID = replacement.id
        }
    }

    /// Rebuild tabs from persisted state (each becomes a resuming tab).
    func restore(sessions: [(id: String, title: String)], activeIndex: Int) {
        tabs.forEach { $0.terminate() }
        cancellables.removeAll()
        tabs = sessions.map { entry in
            let session = ClaudeSession(resuming: entry.id, title: entry.title)
            track(session)
            return session
        }
        if tabs.isEmpty { newTab() }
        let idx = tabs.indices.contains(activeIndex) ? activeIndex : 0
        activeTabID = tabs[idx].id
    }

    private func track(_ session: ClaudeSession) {
        cancellables[session.id] = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run `-only-testing:CodeEditTests/ClaudeSessionManagerTests`. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Agent/ClaudeSessionManager.swift \
        CodeEditTests/Features/Agent/ClaudeSessionManagerTests.swift
git commit -m "feat(agent): ClaudeSessionManager owning the open tabs"
```

---

## Task 5: Wire the manager into `WorkspaceDocument` (+ persistence)

Replace the single `claudeSession` with `claudeSessionManager`, persist open tabs, and restore them on load. After this task the app builds again.

**Files:**
- Modify: `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceStateKey.swift`
- Modify: `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift:49,70` and the workspace-state restore region (~`:192`).

- [ ] **Step 1: Add workspace-state keys**

In `WorkspaceStateKey.swift`, add two cases to the enum:

```swift
    case workspaceMode
    case claudeOpenSessions
    case claudeActiveSessionIndex
```

- [ ] **Step 2: Replace the single session with the manager**

In `WorkspaceDocument.swift`, replace line 49:

```swift
    let claudeSession = ClaudeSession()
```

with:

```swift
    let claudeSessionManager = ClaudeSessionManager()
    private var claudeTabsObserver: AnyCancellable?
```

(Ensure `import Combine` is present at the top of the file; add it if missing.)

- [ ] **Step 3: Re-publish + persist on change**

Find the init block that re-publishes the old session (around line 70):

```swift
        claudeSession.objectWillChange
```

Replace that re-publish subscription with one driven by the manager, and persist tab state on changes. Use this (matching the surrounding `.sink`/`store` style already in the file):

```swift
        claudeSessionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
                self?.persistClaudeTabs()
            }
            .store(in: &cancellables)
```

If the file does not already have a `Set<AnyCancellable>` named `cancellables`, store it in `claudeTabsObserver` instead:

```swift
        claudeTabsObserver = claudeSessionManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.objectWillChange.send()
                self?.persistClaudeTabs()
            }
```

Add the persistence helper as a method on `WorkspaceDocument`:

```swift
    /// Persist the open Claude tab ids + active index so they restore on relaunch.
    private func persistClaudeTabs() {
        addToWorkspaceState(key: .claudeOpenSessions, value: claudeSessionManager.openSessionIds)
        addToWorkspaceState(key: .claudeActiveSessionIndex, value: claudeSessionManager.activeIndex)
    }
```

- [ ] **Step 4: Restore tabs on load**

In the workspace-state restore region (near where `.workspaceMode` is restored, ~line 192), after the workspace mode is applied, add:

```swift
        if let ids = getFromWorkspaceState(.claudeOpenSessions) as? [String], !ids.isEmpty {
            let reader = ClaudeSessionsReader()
            let titles = Dictionary(
                uniqueKeysWithValues: reader
                    .readSessions(for: workspaceFileManager?.folderUrl ?? url)
                    .map { ($0.id, $0.title) }
            )
            let sessions = ids.map { (id: $0, title: titles[$0] ?? "Session") }
            let activeIndex = getFromWorkspaceState(.claudeActiveSessionIndex) as? Int ?? 0
            claudeSessionManager.restore(sessions: sessions, activeIndex: activeIndex)
        }
```

(`url` is the workspace URL available in `initWorkspaceState(_ url:)`; if the signature differs, use `workspaceFileManager?.folderUrl`.)

- [ ] **Step 5: Build, verify it compiles (call sites still pending — temporarily reference the manager)**

To get a green build now, update the two remaining call sites minimally; Tasks 6–7 refine the UI:

In `WorkspaceView.swift` agent case (lines ~148–156), replace the body with the active session (full version comes in Task 6):

```swift
                    case .agent:
                        ClaudeAgentView(
                            session: workspace.claudeSessionManager.activeSession
                                ?? workspace.claudeSessionManager.newTab(),
                            workspaceURL: workspace.workspaceFileManager?.folderUrl
                        )
                        .id("\(workspace.claudeSessionManager.activeSession?.id.uuidString ?? "")-\(workspace.claudeSessionManager.activeSession?.generation ?? 0)")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(EffectView(.contentBackground))
```

In `InspectorAreaView.swift` (lines ~52–53), replace `workspace.claudeSession` with the active session:

```swift
                ClaudeInfoInspectorView(model: claudeInfoModel)
                    .onAppear {
                        workspace.claudeSessionManager.ensureAtLeastOneTab()
                        claudeInfoModel.start(session: workspace.claudeSessionManager.activeSession)
                    }
                    .onDisappear { claudeInfoModel.stop() }
```

- [ ] **Step 6: Build, verify success**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Re-run all new test suites**

Run `test` with `-only-testing:CodeEditTests/ClaudeSessionsReaderTests -only-testing:CodeEditTests/ClaudeSessionCommandTests -only-testing:CodeEditTests/ClaudeSessionManagerTests`. Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceStateKey.swift \
        CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift \
        CodeEdit/WorkspaceView.swift \
        CodeEdit/Features/InspectorArea/Views/InspectorAreaView.swift
git commit -m "feat(agent): multi-tab Claude sessions wired into the workspace with persistence"
```

---

## Task 6: `ClaudeTabBar` + Agent area layout

**Files:**
- Create: `CodeEdit/Features/Agent/ClaudeTabBar.swift`
- Modify: `CodeEdit/WorkspaceView.swift` (agent case)

- [ ] **Step 1: Implement `ClaudeTabBar`**

Create `CodeEdit/Features/Agent/ClaudeTabBar.swift`:

```swift
//
//  ClaudeTabBar.swift
//  CodeEdit
//

import SwiftUI

/// Tab strip shown atop the Agent area: one pill per open Claude session, plus a `+` to add one.
struct ClaudeTabBar: View {
    @ObservedObject var manager: ClaudeSessionManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(manager.tabs) { session in
                    tab(session)
                }
                Button {
                    manager.newTab()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("New Claude session")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(EffectView(.titlebar))
    }

    @ViewBuilder
    private func tab(_ session: ClaudeSession) -> some View {
        let isActive = manager.activeTabID == session.id
        HStack(spacing: 6) {
            Text(session.title)
                .lineLimit(1)
                .font(.system(size: 11))
            Button {
                manager.closeTab(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Close session")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(maxWidth: 180)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.25) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { manager.activate(session.id) }
    }
}
```

- [ ] **Step 2: Use it in the Agent case**

In `WorkspaceView.swift`, replace the agent case body (from Task 5 Step 5) with the tab bar above the active session:

```swift
                    case .agent:
                        let manager = workspace.claudeSessionManager
                        VStack(spacing: 0) {
                            ClaudeTabBar(manager: manager)
                            Group {
                                if let active = manager.activeSession {
                                    ClaudeAgentView(
                                        session: active,
                                        workspaceURL: workspace.workspaceFileManager?.folderUrl
                                    )
                                    .id("\(active.id.uuidString)-\(active.generation)")
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .background(EffectView(.contentBackground))
                        .onAppear { manager.ensureAtLeastOneTab() }
```

- [ ] **Step 3: Build, verify success**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual verification**

Launch the app, enter Agent mode. Expected: a tab bar with one tab; `+` adds a second tab that starts a *new* claude session; clicking tabs switches between live sessions (each keeps running); the `×` closes a tab (closing the last reopens a fresh one).

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Agent/ClaudeTabBar.swift CodeEdit/WorkspaceView.swift
git commit -m "feat(agent): Claude tab bar in the Agent area"
```

---

## Task 7: Sessions inspector tab (Info | Sessions) + open-in-tab

**Files:**
- Create: `CodeEdit/Features/Agent/Sessions/ClaudeSessionsListView.swift`
- Create: `CodeEdit/Features/Agent/Sessions/ClaudeAgentInspectorView.swift`
- Modify: `CodeEdit/Features/InspectorArea/Views/InspectorAreaView.swift`

- [ ] **Step 1: Implement the Sessions list**

Create `CodeEdit/Features/Agent/Sessions/ClaudeSessionsListView.swift`:

```swift
//
//  ClaudeSessionsListView.swift
//  CodeEdit
//

import SwiftUI

/// Lists the project's past Claude sessions. Clicking opens in the current tab; the context
/// menu offers a new tab. Defaults to the current tab.
struct ClaudeSessionsListView: View {
    @ObservedObject var manager: ClaudeSessionManager
    let workspaceURL: URL?

    @State private var sessions: [ClaudeSessionInfo] = []
    @State private var query: String = ""

    private let settingsStore = ClaudeSettingsStore()

    private var filtered: [ClaudeSessionInfo] {
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search sessions", text: $query)
                    .textFieldStyle(.plain)
                Button {
                    manager.newTab()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
                .help("New session")
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(8)
            Divider()
            if filtered.isEmpty {
                Spacer()
                Text(sessions.isEmpty ? "No sessions yet" : "No matches")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(filtered) { session in
                    row(session)
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private func row(_ session: ClaudeSessionInfo) -> some View {
        let isOpen = manager.tabs.contains { $0.claudeSessionId == session.id }
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(session.title).lineLimit(1)
                if isOpen {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.green)
                }
            }
            Text(session.lastModified.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { open(session, mode: .currentTab) }
        .contextMenu {
            Button("Open in Current Tab") { open(session, mode: .currentTab) }
            Button("Open in New Tab") { open(session, mode: .newTab) }
        }
    }

    private func open(_ session: ClaudeSessionInfo, mode: ClaudeSessionManager.OpenMode) {
        let config = settingsStore.read()
        manager.open(
            claudeId: session.id,
            title: session.title,
            mode: mode,
            model: config?.model,
            effort: config?.effort
        )
    }

    private func reload() {
        sessions = ClaudeSessionsReader().readSessions(for: workspaceURL ?? FileManager.default.homeDirectoryForCurrentUser)
    }
}
```

- [ ] **Step 2: Implement the Info | Sessions switcher**

Create `CodeEdit/Features/Agent/Sessions/ClaudeAgentInspectorView.swift`:

```swift
//
//  ClaudeAgentInspectorView.swift
//  CodeEdit
//

import SwiftUI

/// The Agent-mode inspector: a small segmented switcher between the live Info panel and the
/// project's session list.
struct ClaudeAgentInspectorView: View {
    @ObservedObject var infoModel: ClaudeInfoModel
    @ObservedObject var manager: ClaudeSessionManager
    let workspaceURL: URL?

    enum Tab: String, CaseIterable { case info = "Info", sessions = "Sessions" }
    @State private var tab: Tab = .info

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)
            Divider()
            switch tab {
            case .info:
                ClaudeInfoInspectorView(model: infoModel)
            case .sessions:
                ClaudeSessionsListView(manager: manager, workspaceURL: workspaceURL)
            }
        }
    }
}
```

- [ ] **Step 3: Use it from `InspectorAreaView`**

In `InspectorAreaView.swift`, replace the agent branch (the `if workspace.workspaceMode == .agent { ClaudeInfoInspectorView(...) }` block) with:

```swift
            if workspace.workspaceMode == .agent {
                ClaudeAgentInspectorView(
                    infoModel: claudeInfoModel,
                    manager: workspace.claudeSessionManager,
                    workspaceURL: workspace.workspaceFileManager?.folderUrl
                )
                .onAppear {
                    workspace.claudeSessionManager.ensureAtLeastOneTab()
                    claudeInfoModel.start(session: workspace.claudeSessionManager.activeSession)
                }
                .onChange(of: workspace.claudeSessionManager.activeTabID) { _, _ in
                    claudeInfoModel.start(session: workspace.claudeSessionManager.activeSession)
                }
                .onDisappear { claudeInfoModel.stop() }
            } else {
```

- [ ] **Step 4: Build, verify success**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual verification**

In Agent mode, open the inspector. Expected: an Info | Sessions segmented control. **Sessions** lists the project's past sessions (newest first, titled by their first prompt/summary), with a green dot on already-open ones, search filters by title. Clicking a row resumes it in the **current** tab; the context menu's "Open in New Tab" resumes it in a new tab; selecting an already-open session just activates its tab. The **Info** tab follows the active tab.

- [ ] **Step 6: Commit**

```bash
git add CodeEdit/Features/Agent/Sessions/ClaudeSessionsListView.swift \
        CodeEdit/Features/Agent/Sessions/ClaudeAgentInspectorView.swift \
        CodeEdit/Features/InspectorArea/Views/InspectorAreaView.swift
git commit -m "feat(agent): Sessions inspector tab with open-in-current/new-tab"
```

---

## Task 8: Full integration verification

**Files:** none (verification only).

- [ ] **Step 1: Full build**

Run the **Build** command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Full test run of new suites**

Run `test` with all three suites:
`-only-testing:CodeEditTests/ClaudeSessionsReaderTests -only-testing:CodeEditTests/ClaudeSessionCommandTests -only-testing:CodeEditTests/ClaudeSessionManagerTests`.
Expected: all pass.

- [ ] **Step 3: Manual end-to-end**

1. Agent mode → one tab, claude starts a fresh session.
2. `+` → second tab → second concurrent claude session. Both keep running when switching.
3. Inspector → Sessions → click a past session → resumes in the current tab; title updates.
4. Context menu → "Open in New Tab" on another session → new tab resumes it.
5. Click an already-open session → just activates its tab (no duplicate, no second process).
6. Close a tab (×) → process ends, session remains in the Sessions list (resumable).
7. Quit & reopen the app → previously open tabs are restored (resumed) with the active one selected.
8. Info tab shows account/usage/model for the **active** tab and updates on tab switch.

- [ ] **Step 4: Commit (if any verification fixes were needed)**

```bash
git add -A
git commit -m "test(agent): verify Claude sessions & tabs end-to-end"
```

---

## Self-Review

**Spec coverage:**
- "Open a new Claude tab that launches a new session" → Task 6 (`+`), Task 4 (`newTab`), Task 3 (`--session-id`). ✓
- "Session system that saves conversations" → leverages Claude's own `.jsonl` persistence; read by Task 1; resume by Task 3. ✓
- "Sessions tab in the right panel listing sessions to select" → Task 7 (`ClaudeSessionsListView` + `ClaudeAgentInspectorView`). ✓
- "Option to open in the tab or a new tab, default current tab" → Task 7 row tap = current; context menu = new; Task 4 `open(mode:)`. ✓
- "All project sessions" → Task 1 reads the whole `~/.claude/projects/<cwd>/`. ✓
- "Restore open tabs on relaunch" → Task 5 persistence + Task 4 `restore`. ✓

**Placeholder scan:** No TBD/TODO; every code step has complete code; every command has an expected result. ✓

**Type consistency:**
- `ClaudeSession.launchCommand(sessionId:resume:model:effort:)` — defined Task 2, used Task 3. ✓
- `ClaudeSession` inits `init(title:)` / `init(resuming:title:)`, methods `prepareLaunch(model:effort:)`, `restart(model:effort:)`, `terminate()`, `setTitle(_:)` — defined Task 3, used Task 4. ✓
- `ClaudeSessionManager`: `tabs`, `activeTabID`, `activeSession`, `openSessionIds`, `activeIndex`, `newTab(resuming:title:)`, `activate(_:)`, `closeTab(_:)`, `open(claudeId:title:mode:model:effort:)`, `restore(sessions:activeIndex:)`, `ensureAtLeastOneTab()`, `OpenMode` — defined Task 4, used Tasks 5–7. ✓
- `ClaudeSessionsReader`: `init(projectsBaseURL:)`, `encodedProjectDir(for:)`, `sessionsDirectory(for:)`, `readSessions(for:)`, `ClaudeSessionInfo{id,title,lastModified}` — defined Task 1, used Tasks 3, 5, 7. ✓
- `ClaudeSettingsStore().read()?.model/.effort` — existing API, used Task 7. ✓
- Workspace state keys `.claudeOpenSessions`, `.claudeActiveSessionIndex` — defined Task 5 Step 1, used Task 5 Steps 3–4. ✓

**Note on green-build ordering:** Task 3 alone breaks the three call sites; Task 5 restores them. Implement Tasks 3→4→5 before expecting a green build (the unit-test suites from Tasks 1, 2, 4 stay green independently). This is called out in Task 3 Step 2.
