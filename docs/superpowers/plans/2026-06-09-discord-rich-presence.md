# Discord Rich Presence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show CodeEditAi on the user's Discord profile (logo, project folder, git branch, editing/idle, elapsed time) via Discord's local IPC, with a Settings toggle (on by default), never exposing file names.

**Architecture:** A shared `@MainActor DiscordPresenceManager` observes the frontmost workspace, builds a folder-only `DiscordActivity` via a pure `DiscordPresenceBuilder`, and pushes it through a low-level `DiscordRPCClient` (POSIX `AF_UNIX` socket + framed JSON). Started/stopped from `AppDelegate`; gated on a `GeneralSettings` toggle.

**Tech Stack:** Swift 6.4, Foundation, POSIX sockets (`Darwin`), Discord IPC RPC, XCTest.

---

## Build & Test Commands

Set `DEVELOPER_DIR` (Xcode 27 beta / Swift 6.4); read the verdict from the log (a SwiftLint *plugin* phase may report "(N failures)" from a sandbox artifact — the authoritative verdict is `** BUILD SUCCEEDED **`).

**Build:**
```bash
cd /Users/theoschneider/Developer/CodeEdit
DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer \
  xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta \
  -skipPackagePluginValidation build > /tmp/ceai_build.log 2>&1
grep -E "BUILD (SUCCEEDED|FAILED)" /tmp/ceai_build.log | tail -1
```

**Run one test suite:**
```bash
cd /Users/theoschneider/Developer/CodeEdit
DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer \
  xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta \
  -skipPackagePluginValidation test -only-testing:CodeEditTests/<SuiteName> \
  > /tmp/ceai_test.log 2>&1
grep -E "Test Suite '<SuiteName>'|Executed [0-9]+ test|\*\* TEST (SUCCEEDED|FAILED)|error:" /tmp/ceai_test.log | tail -20
```

**Conventions:** new `.swift` files auto-join their target (synchronized groups — no `.pbxproj` edits). SwiftLint identifiers ≥3 chars. Module `CodeEdit`; tests `@testable import CodeEdit`. `do {...} catch` blocks must put `} catch` on the same line as the closing brace.

## File Structure

**Create (all under `CodeEdit/Features/DiscordPresence/`):**
- `DiscordActivity.swift` — the `Encodable` activity payload (snake_case keys).
- `DiscordRPCFrame.swift` — pure frame encoder/decoder (LE op + length + JSON).
- `DiscordSocketLocator.swift` — pure candidate-socket-path list from env vars.
- `DiscordPresenceBuilder.swift` — pure `PresenceContext -> DiscordActivity` (folder-only).
- `DiscordRPCClient.swift` — POSIX `AF_UNIX` socket: connect, handshake, set/clear activity.
- `DiscordPresenceManager.swift` — shared manager: observe workspace, debounce, retry, gate on setting.

**Modify:**
- `CodeEdit/Features/Settings/Pages/GeneralSettings/Models/GeneralSettings.swift` — add `discordRichPresenceEnabled` + decode.
- `CodeEdit/Features/Settings/Pages/GeneralSettings/GeneralSettingsView.swift` — a toggle.
- `CodeEdit/AppDelegate.swift` — start/stop the manager.

**Tests (under `CodeEditTests/Features/DiscordPresence/`):** one suite per pure helper.

---

## Task 1: `DiscordActivity` + `DiscordRPCFrame`

**Files:**
- Create: `CodeEdit/Features/DiscordPresence/DiscordActivity.swift`, `CodeEdit/Features/DiscordPresence/DiscordRPCFrame.swift`
- Test: `CodeEditTests/Features/DiscordPresence/DiscordRPCFrameTests.swift`, `CodeEditTests/Features/DiscordPresence/DiscordActivityTests.swift`

- [ ] **Step 1: Write the failing tests**

`CodeEditTests/Features/DiscordPresence/DiscordRPCFrameTests.swift`:
```swift
@testable import CodeEdit
import XCTest

final class DiscordRPCFrameTests: XCTestCase {
    func testEncodeWritesLittleEndianHeaderThenPayload() {
        let json = Data("{}".utf8) // 2 bytes
        let frame = DiscordRPCFrame.encode(op: 0, json: json)
        XCTAssertEqual([UInt8](frame.prefix(4)), [0, 0, 0, 0])       // op 0 LE
        XCTAssertEqual([UInt8](frame[4..<8]), [2, 0, 0, 0])          // length 2 LE
        XCTAssertEqual(Data(frame[8...]), json)
    }

    func testDecodeHeaderRoundTrips() {
        let frame = DiscordRPCFrame.encode(op: 1, json: Data("hello".utf8))
        let header = DiscordRPCFrame.decodeHeader(frame)
        XCTAssertEqual(header?.op, 1)
        XCTAssertEqual(header?.length, 5)
    }

    func testDecodeHeaderRejectsShortData() {
        XCTAssertNil(DiscordRPCFrame.decodeHeader(Data([0, 0, 0])))
    }
}
```

`CodeEditTests/Features/DiscordPresence/DiscordActivityTests.swift`:
```swift
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
```

- [ ] **Step 2: Run both suites, verify they fail** (cannot find types).

- [ ] **Step 3: Implement** — `CodeEdit/Features/DiscordPresence/DiscordRPCFrame.swift`:
```swift
//
//  DiscordRPCFrame.swift
//  CodeEdit
//

import Foundation

/// Encodes/decodes Discord IPC frames: a little-endian `op` (UInt32) + `length` (UInt32) header
/// followed by the JSON payload. Pure — no networking.
enum DiscordRPCFrame {
    static func encode(op: UInt32, json: Data) -> Data {
        var data = Data()
        for value in [op, UInt32(json.count)] {
            data.append(UInt8(value & 0xFF))
            data.append(UInt8((value >> 8) & 0xFF))
            data.append(UInt8((value >> 16) & 0xFF))
            data.append(UInt8((value >> 24) & 0xFF))
        }
        data.append(json)
        return data
    }

    static func decodeHeader(_ data: Data) -> (op: UInt32, length: UInt32)? {
        guard data.count >= 8 else { return nil }
        let bytes = [UInt8](data.prefix(8))
        let opValue = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let lenValue = UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24
        return (opValue, lenValue)
    }
}
```

`CodeEdit/Features/DiscordPresence/DiscordActivity.swift`:
```swift
//
//  DiscordActivity.swift
//  CodeEdit
//

import Foundation

/// A Discord Rich Presence activity payload (encodes to the snake_case shape the API expects).
struct DiscordActivity: Encodable, Equatable {
    var details: String?
    var state: String?
    /// Unix epoch seconds when the activity started (drives the "elapsed" timer).
    var startTimestamp: Int?
    var largeImage: String?
    var largeText: String?

    private enum CodingKeys: String, CodingKey {
        case details, state, timestamps, assets
    }
    private struct Timestamps: Encodable { let start: Int }
    private struct Assets: Encodable {
        let largeImage: String?
        let largeText: String?
        enum CodingKeys: String, CodingKey {
            case largeImage = "large_image"
            case largeText = "large_text"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(state, forKey: .state)
        if let startTimestamp {
            try container.encode(Timestamps(start: startTimestamp), forKey: .timestamps)
        }
        if largeImage != nil || largeText != nil {
            try container.encode(Assets(largeImage: largeImage, largeText: largeText), forKey: .assets)
        }
    }
}
```

- [ ] **Step 4: Run both suites, verify they pass.**

- [ ] **Step 5: Commit**
```bash
git add CodeEdit/Features/DiscordPresence/DiscordRPCFrame.swift \
        CodeEdit/Features/DiscordPresence/DiscordActivity.swift \
        CodeEditTests/Features/DiscordPresence/DiscordRPCFrameTests.swift \
        CodeEditTests/Features/DiscordPresence/DiscordActivityTests.swift
git commit -m "feat(discord): activity payload + IPC frame encoding"
```

---

## Task 2: `DiscordSocketLocator`

**Files:**
- Create: `CodeEdit/Features/DiscordPresence/DiscordSocketLocator.swift`
- Test: `CodeEditTests/Features/DiscordPresence/DiscordSocketLocatorTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
@testable import CodeEdit
import XCTest

final class DiscordSocketLocatorTests: XCTestCase {
    func testBuildsTenCandidatesPerBaseDeduplicatedAndOrdered() {
        let paths = DiscordSocketLocator.candidatePaths(environment: [
            "XDG_RUNTIME_DIR": "/run/u",
            "TMPDIR": "/var/t/",       // trailing slash trimmed
            "TMP": "/run/u"            // duplicate of XDG base -> skipped
        ])
        XCTAssertEqual(paths.first, "/run/u/discord-ipc-0")
        XCTAssertTrue(paths.contains("/run/u/discord-ipc-9"))
        XCTAssertTrue(paths.contains("/var/t/discord-ipc-0"))
        XCTAssertTrue(paths.contains("/tmp/discord-ipc-3"))     // /tmp always appended
        // 3 unique bases (/run/u, /var/t, /tmp) × 10
        XCTAssertEqual(paths.count, 30)
        XCTAssertEqual(Set(paths).count, paths.count)           // no duplicates
    }
}
```

- [ ] **Step 2: Run it, verify it fails.**

- [ ] **Step 3: Implement** — `CodeEdit/Features/DiscordPresence/DiscordSocketLocator.swift`:
```swift
//
//  DiscordSocketLocator.swift
//  CodeEdit
//

import Foundation

/// Builds the ordered list of candidate Discord IPC socket paths (`<base>/discord-ipc-0…9`) from the
/// environment. Pure (env is injected) so it is unit-testable.
enum DiscordSocketLocator {
    static func candidatePaths(environment: [String: String]) -> [String] {
        let envBases = ["XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TMP_DIR"].compactMap { environment[$0] }
        var seen = Set<String>()
        var result: [String] = []
        for base in envBases + ["/tmp"] {
            let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            for index in 0...9 {
                result.append("\(trimmed)/discord-ipc-\(index)")
            }
        }
        return result
    }
}
```

- [ ] **Step 4: Run it, verify it passes.**

- [ ] **Step 5: Commit**
```bash
git add CodeEdit/Features/DiscordPresence/DiscordSocketLocator.swift \
        CodeEditTests/Features/DiscordPresence/DiscordSocketLocatorTests.swift
git commit -m "feat(discord): IPC socket path locator"
```

---

## Task 3: `DiscordPresenceBuilder`

**Files:**
- Create: `CodeEdit/Features/DiscordPresence/DiscordPresenceBuilder.swift`
- Test: `CodeEditTests/Features/DiscordPresence/DiscordPresenceBuilderTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
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
```

- [ ] **Step 2: Run it, verify it fails.**

- [ ] **Step 3: Implement** — `CodeEdit/Features/DiscordPresence/DiscordPresenceBuilder.swift`:
```swift
//
//  DiscordPresenceBuilder.swift
//  CodeEdit
//

import Foundation

/// Inputs for building the presence (folder-only — never a file name).
struct DiscordPresenceContext: Equatable {
    var folder: String?
    var branch: String?
    var isEditing: Bool
    var startTimestamp: Int
}

/// Turns a `DiscordPresenceContext` into a folder-only `DiscordActivity`.
enum DiscordPresenceBuilder {
    static func build(_ context: DiscordPresenceContext) -> DiscordActivity {
        guard let folder = context.folder, !folder.isEmpty else {
            return DiscordActivity(
                details: "CodeEditAi",
                state: "Idle",
                startTimestamp: context.startTimestamp,
                largeImage: "logo",
                largeText: "CodeEditAi"
            )
        }
        let status = context.isEditing ? "Editing" : "Idle"
        let state: String
        if let branch = context.branch, !branch.isEmpty {
            state = "\(status) · \(branch)"
        } else {
            state = status
        }
        return DiscordActivity(
            details: folder,
            state: state,
            startTimestamp: context.startTimestamp,
            largeImage: "logo",
            largeText: "CodeEditAi"
        )
    }
}
```

- [ ] **Step 4: Run it, verify it passes.**

- [ ] **Step 5: Commit**
```bash
git add CodeEdit/Features/DiscordPresence/DiscordPresenceBuilder.swift \
        CodeEditTests/Features/DiscordPresence/DiscordPresenceBuilderTests.swift
git commit -m "feat(discord): folder-only presence builder"
```

---

## Task 4: `DiscordRPCClient`

Integration (POSIX socket). No unit test; the gate is a green build (the pure pieces it uses are tested; live IPC is verified in Task 8).

**Files:**
- Create: `CodeEdit/Features/DiscordPresence/DiscordRPCClient.swift`

- [ ] **Step 1: Implement** — `CodeEdit/Features/DiscordPresence/DiscordRPCClient.swift`:
```swift
//
//  DiscordRPCClient.swift
//  CodeEdit
//

import Foundation

/// Minimal Discord IPC client: connects to the local `discord-ipc-*` Unix socket, performs the
/// handshake, and sends `SET_ACTIVITY` frames. Detects a dropped connection on write failure;
/// reconnection is driven by `DiscordPresenceManager`.
final class DiscordRPCClient {
    private let clientID: String
    private var descriptor: Int32 = -1

    init(clientID: String) {
        self.clientID = clientID
    }

    var isConnected: Bool { descriptor >= 0 }

    /// Connects to the first available IPC socket and handshakes. Returns false if Discord isn't up.
    @discardableResult
    func connect() -> Bool {
        for path in DiscordSocketLocator.candidatePaths(environment: ProcessInfo.processInfo.environment) {
            guard let opened = Self.openSocket(path: path) else { continue }
            descriptor = opened
            if sendHandshake() {
                return true
            }
            close()
        }
        return false
    }

    func setActivity(_ activity: DiscordActivity?) {
        guard isConnected else { return }
        var args: [String: Any] = ["pid": Int(ProcessInfo.processInfo.processIdentifier)]
        if let activity,
           let data = try? JSONEncoder().encode(activity),
           let object = try? JSONSerialization.jsonObject(with: data) {
            args["activity"] = object
        } else {
            args["activity"] = NSNull()
        }
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "nonce": UUID().uuidString,
            "args": args
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload) else { return }
        if !write(DiscordRPCFrame.encode(op: 1, json: json)) {
            close()
        }
    }

    func close() {
        if descriptor >= 0 {
            Darwin.close(descriptor)
            descriptor = -1
        }
    }

    // MARK: - Internals

    private func sendHandshake() -> Bool {
        let payload: [String: Any] = ["v": 1, "client_id": clientID]
        guard let json = try? JSONSerialization.data(withJSONObject: payload) else { return false }
        return write(DiscordRPCFrame.encode(op: 0, json: json))
    }

    private static func openSocket(path: String) -> Int32? {
        // `sun_path` is 104 bytes on Darwin; leave room for the null terminator.
        guard path.utf8.count < 104 else { return nil }
        let opened = socket(AF_UNIX, SOCK_STREAM, 0)
        guard opened >= 0 else { return nil }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutablePointer(to: &addr.sun_path) { pointer in
            path.withCString { cString in
                pointer.withMemoryRebound(to: CChar.self, capacity: 104) { dest in
                    _ = strncpy(dest, cString, 103)
                }
            }
        }
        let length = socklen_t(MemoryLayout<sockaddr_un>.size)
        let result = withUnsafePointer(to: &addr) { raw -> Int32 in
            raw.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(opened, $0, length) }
        }
        if result != 0 {
            Darwin.close(opened)
            return nil
        }
        return opened
    }

    @discardableResult
    private func write(_ data: Data) -> Bool {
        guard descriptor >= 0 else { return false }
        return data.withUnsafeBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return true }
            var sent = 0
            let total = raw.count
            while sent < total {
                let count = Darwin.write(descriptor, base + sent, total - sent)
                if count <= 0 { return false }
                sent += count
            }
            return true
        }
    }
}
```

- [ ] **Step 2: Build, verify it compiles** (`** BUILD SUCCEEDED **`). If `sockaddr_un`/`strncpy`/`Darwin.write` need an explicit `import Darwin`, add it. If the `sun_path` rebind warns, keep it (it's the standard pattern).

- [ ] **Step 3: Commit**
```bash
git add CodeEdit/Features/DiscordPresence/DiscordRPCClient.swift
git commit -m "feat(discord): POSIX IPC client (handshake + set activity)"
```

---

## Task 5: `DiscordPresenceManager`

**Files:**
- Create: `CodeEdit/Features/DiscordPresence/DiscordPresenceManager.swift`

- [ ] **Step 1: Implement** — `CodeEdit/Features/DiscordPresence/DiscordPresenceManager.swift`:
```swift
//
//  DiscordPresenceManager.swift
//  CodeEdit
//

import AppKit
import Combine

/// Shared, app-wide Discord Rich Presence. Observes the frontmost workspace and pushes a
/// folder-only activity to Discord while the setting is enabled and Discord is running.
@MainActor
final class DiscordPresenceManager {
    static let shared = DiscordPresenceManager(clientID: "1513992493396525148")

    private let clientID: String
    private var client: DiscordRPCClient?
    private var loopTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var keyWindowObserver: AnyCancellable?
    private var startedAt = Int(Date().timeIntervalSince1970)
    private(set) var isRunning = false

    init(clientID: String) {
        self.clientID = clientID
    }

    /// Start presence if the setting is enabled (called at app launch).
    func start() {
        guard !isRunning, Settings[\.general].discordRichPresenceEnabled else { return }
        isRunning = true
        startedAt = Int(Date().timeIntervalSince1970)
        keyWindowObserver = NotificationCenter.default
            .publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { [weak self] _ in self?.scheduleUpdate() }
        runLoop()
    }

    func stop() {
        isRunning = false
        loopTask?.cancel(); loopTask = nil
        debounceTask?.cancel(); debounceTask = nil
        keyWindowObserver = nil
        client?.setActivity(nil)
        client?.close()
        client = nil
    }

    /// Re-evaluate the enabled setting (call when the toggle changes).
    func settingChanged() {
        if Settings[\.general].discordRichPresenceEnabled {
            start()
        } else {
            stop()
        }
    }

    // MARK: - Internals

    /// Reconnects if needed and refreshes the activity every 10s (also catches branch/file changes).
    private func runLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                if !(self.client?.isConnected ?? false) {
                    let candidate = DiscordRPCClient(clientID: self.clientID)
                    self.client = candidate.connect() ? candidate : nil
                }
                self.update()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func scheduleUpdate() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.update()
        }
    }

    private func update() {
        guard isRunning, Settings[\.general].discordRichPresenceEnabled else { return }
        client?.setActivity(DiscordPresenceBuilder.build(currentContext()))
    }

    private func currentContext() -> DiscordPresenceContext {
        let workspace = (NSApp.keyWindow?.windowController as? CodeEditWindowController)?.workspace
            ?? NSDocumentController.shared.currentDocument as? WorkspaceDocument
        let folder = workspace?.fileURL?.lastPathComponent ?? workspace?.displayName
        let branch = workspace?.sourceControlManager?.currentBranch?.name
        let isEditing = workspace?.editorManager?.activeEditor.selectedTab != nil
        return DiscordPresenceContext(
            folder: folder,
            branch: branch,
            isEditing: isEditing,
            startTimestamp: startedAt
        )
    }
}
```

- [ ] **Step 2: Build, verify it compiles.** If `workspace.sourceControlManager?.currentBranch?.name` doesn't resolve (the `GitBranch` property is named differently), read `CodeEdit/Features/SourceControl/Models/GitBranch.swift` and use the correct display-name property. If `editorManager?.activeEditor.selectedTab` doesn't resolve, read `Editor.swift` for the selected-tab property. Fix minimally; rebuild until green.

- [ ] **Step 3: Commit**
```bash
git add CodeEdit/Features/DiscordPresence/DiscordPresenceManager.swift
git commit -m "feat(discord): presence manager (observe workspace, debounce, retry)"
```

---

## Task 6: Settings toggle

**Files:**
- Modify: `CodeEdit/Features/Settings/Pages/GeneralSettings/Models/GeneralSettings.swift`
- Modify: `CodeEdit/Features/Settings/Pages/GeneralSettings/GeneralSettingsView.swift`

- [ ] **Step 1: Add the setting.** In `GeneralSettings.swift`, add a stored property next to the other `var` fields (e.g. after `isAutoSaveOn`):
```swift
        /// Whether Discord Rich Presence is shown.
        var discordRichPresenceEnabled: Bool = true
```
And in its `init(from decoder:)`, add a decode line next to the others:
```swift
            self.discordRichPresenceEnabled = try container.decodeIfPresent(
                Bool.self, forKey: .discordRichPresenceEnabled
            ) ?? true
```
(If `GeneralSettings` uses an explicit `CodingKeys` enum, add `case discordRichPresenceEnabled`. If it relies on synthesized keys, no change is needed.)

- [ ] **Step 2: Add the toggle UI.** In `GeneralSettingsView.swift`, find the `@AppSettings(\.general...)` usage and the `Form`/`Section` body. Add a toggle (mirror an existing `Toggle` in that file). Use the binding to the general settings, e.g.:
```swift
            Section {
                Toggle("Discord Rich Presence", isOn: $settings.discordRichPresenceEnabled)
                    .onChange(of: settings.discordRichPresenceEnabled) { _, _ in
                        DiscordPresenceManager.shared.settingChanged()
                    }
            } header: {
                Text("Discord")
            } footer: {
                Text("Show the current project and git branch on your Discord profile (never file names).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
```
Replace `$settings.discordRichPresenceEnabled` with whatever the file's binding to general settings is (e.g. `@AppSettings(\.general) var settings` → `$settings.discordRichPresenceEnabled`, or the existing pattern used for other general toggles in this view). If the view uses `@AppSettings(\.general.someField)` per-field wrappers, add `@AppSettings(\.general.discordRichPresenceEnabled) var discordRichPresenceEnabled` and bind `$discordRichPresenceEnabled`.

- [ ] **Step 3: Build, verify success.** Run the **Build** command → `** BUILD SUCCEEDED **`. Fix the binding form if it doesn't match the file's convention.

- [ ] **Step 4: Manual check.** Open Settings → General: the "Discord Rich Presence" toggle appears, on by default; toggling it calls `settingChanged()`.

- [ ] **Step 5: Commit**
```bash
git add CodeEdit/Features/Settings/Pages/GeneralSettings/Models/GeneralSettings.swift \
        CodeEdit/Features/Settings/Pages/GeneralSettings/GeneralSettingsView.swift
git commit -m "feat(discord): Settings toggle (General > Discord, on by default)"
```

---

## Task 7: App lifecycle wiring

**Files:**
- Modify: `CodeEdit/AppDelegate.swift`

- [ ] **Step 1: Start/stop the manager.** In `AppDelegate.swift`, in `applicationDidFinishLaunching(_:)`, add at the end:
```swift
        DiscordPresenceManager.shared.start()
```
And in `applicationWillTerminate(_:)`, add:
```swift
        DiscordPresenceManager.shared.stop()
```
(`AppDelegate` is `@MainActor` via `NSApplicationDelegate`; `DiscordPresenceManager.shared` is `@MainActor` — the calls are main-actor-isolated already.)

- [ ] **Step 2: Build, verify success** → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual check.** With Discord running and a workspace open, launch the app → the Discord profile shows "CodeEditAi" with the folder, branch, and elapsed time.

- [ ] **Step 4: Commit**
```bash
git add CodeEdit/AppDelegate.swift
git commit -m "feat(discord): start/stop presence with the app lifecycle"
```

---

## Task 8: Integration verification

**Files:** none (verification only).

- [ ] **Step 1: Full build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 2: Run all DiscordPresence unit suites:**
  `-only-testing:CodeEditTests/DiscordRPCFrameTests -only-testing:CodeEditTests/DiscordActivityTests -only-testing:CodeEditTests/DiscordSocketLocatorTests -only-testing:CodeEditTests/DiscordPresenceBuilderTests` → all pass.
- [ ] **Step 3: One-time Discord setup (user).** At <https://discord.com/developers/applications>: create the app, confirm the Application ID matches `1513992493396525148`, and under **Rich Presence → Art Assets** upload a square logo named `logo`.
- [ ] **Step 4: Manual end-to-end.** Discord running + a project open → profile shows "CodeEditAi", the folder (`details`), `Editing · <branch>` (`state`), the logo, and an elapsed timer. Switch branches / open a file → updates within ~10s. Close all files → `Idle · <branch>`. Toggle the setting off → presence clears within a moment. Quit Discord → no crash; relaunch Discord → presence returns within ~15s. Toggle off in Settings → nothing is sent.

---

## Self-Review

**Spec coverage:**
- IPC socket + handshake + SET_ACTIVITY framing → Tasks 1, 4. ✓
- Folder-only privacy (no file names), editing/idle, branch on line 2 → Task 3 (+ builder tests asserting no file name). ✓
- Elapsed time (timestamps.start) → Tasks 1, 3. ✓
- Logo large image → Tasks 1, 3 (`"logo"`). ✓
- Observe frontmost workspace + debounce + retry when Discord down → Task 5. ✓
- Enabled-by-default toggle, gating (no socket when disabled) → Tasks 6, 5 (`start()` guards on the setting). ✓
- App launch/quit lifecycle → Task 7. ✓
- Tests for frame / activity JSON / socket locator / builder → Tasks 1–3. ✓

**Placeholder scan:** No TBD/TODO; each code step is complete; commands have expected results. The two "if the property name differs, read X and adjust" notes (Tasks 5, 6) are explicit fallbacks for codebase-specific names (`GitBranch` display property, the General-settings binding convention), not placeholders for missing logic.

**Type consistency:**
- `DiscordRPCFrame.encode(op:json:)` / `decodeHeader(_:)` — Task 1, used in 4. ✓
- `DiscordActivity(details:state:startTimestamp:largeImage:largeText:)` — Task 1, used in 3. ✓
- `DiscordSocketLocator.candidatePaths(environment:)` — Task 2, used in 4. ✓
- `DiscordPresenceContext(folder:branch:isEditing:startTimestamp:)` + `DiscordPresenceBuilder.build(_:)` — Task 3, used in 5. ✓
- `DiscordRPCClient(clientID:)`, `.connect()`, `.isConnected`, `.setActivity(_:)`, `.close()` — Task 4, used in 5. ✓
- `DiscordPresenceManager.shared`, `.start()`, `.stop()`, `.settingChanged()` — Task 5, used in 6, 7. ✓
- `Settings[\.general].discordRichPresenceEnabled` — Task 6, used in 5. ✓

**Green-build ordering:** Tasks 1–3 are independently green. Task 4 compiles against Tasks 1–2. Task 5 compiles against Tasks 3–4 (and existing workspace APIs). Tasks 6–7 wire it in. No task leaves the build broken.
