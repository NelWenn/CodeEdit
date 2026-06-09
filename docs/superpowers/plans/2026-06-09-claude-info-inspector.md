# Claude Info Inspector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In Agent mode, turn the Inspector into a Claude info+control panel: account, plan, three live usage meters, and model/effort/thinking pickers.

**Architecture:** Pure file-readers/writers (`~/.claude.json`, `~/.claude/settings.json`) and a usage source (statusline-written file + keychain-token endpoint fallback) feed a workspace-scoped `ClaudeInfoModel` (ObservableObject). `InspectorAreaView` renders `ClaudeInfoInspectorView` when `workspace.workspaceMode == .agent`. Controls write the settings file and inject slash commands into the existing Agent terminal.

**Tech Stack:** Swift 6.4 / SwiftUI + AppKit, Foundation (Codable, FileHandle, Security/Keychain, URLSession), Xcode 27 beta.

---

## ⚠️ Build/verify command (every task)

```bash
cd ~/Developer/CodeEdit
DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer \
xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta \
  -skipPackagePluginValidation build > /tmp/ceai_build.log 2>&1
echo "EXIT=$?"; grep -E "\*\* BUILD (SUCCEEDED|FAILED) \*\*" /tmp/ceai_build.log | tail -1
grep -n "error:" /tmp/ceai_build.log | head
```
For unit tests, replace `build` with `test -only-testing:CodeEditTests/<TestClass>`. Read the verdict from the log (`** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **`), never a piped exit code. Swift module is `CodeEdit`; new files in existing folders auto-join the target (synchronized groups). New code lives in `CodeEdit/Features/Agent/Info/`; tests in `CodeEditTests/Features/Agent/Info/`; fixtures in `CodeEditTests/Features/Agent/Info/Fixtures/`.

---

## Task 1: Empirical capture of undocumented shapes (collaborative)

The statusline `rate_limits` JSON, the `/api/oauth/usage` response, the Keychain credential JSON, and the live model/effort control commands are undocumented. Capture them from the user's real `claude` before writing any parser. **This task requires the user** (run `claude`, approve a Keychain prompt). The controller drives it; the user performs the live steps.

- [ ] **Step 1: Capture the statusline `rate_limits` payload.** Temporarily add a capture statusLine, have the user run a short `claude` session, then read the dump:
```bash
# Back up settings, install a capture statusline that records stdin verbatim
cp ~/.claude/settings.json /tmp/claude-settings.bak.json
python3 - <<'PY'
import json,os,io
p=os.path.expanduser("~/.claude/settings.json"); d=json.load(open(p))
d.setdefault("_ceai_prev_statusLine", d.get("statusLine"))
d["statusLine"]={"type":"command","command":"cat > ~/.claude/ceai-capture.json; echo ceai-capture"}
json.dump(d,open(p,"w"),indent=2)
print("capture statusline installed")
PY
# >>> USER: open a folder in CodeEditAi, switch to Agent, let `claude` start (or run `claude` in any terminal), wait ~3s, then quit it.
cat ~/.claude/ceai-capture.json   # <-- the real statusline JSON incl. rate_limits
# restore:
cp /tmp/claude-settings.bak.json ~/.claude/settings.json
```
Record the exact JSON (especially `rate_limits.five_hour`, `rate_limits.seven_day`, any Sonnet-specific field, and each object's percentage + reset field names).

- [ ] **Step 2: Capture the endpoint response + Keychain credential shape.** (User approves the Keychain prompt.)
```bash
CRED=$(security find-generic-password -w -s "Claude Code-credentials" -a theoschneider 2>/dev/null)
echo "$CRED" | python3 -c "import sys,json;print(list(json.load(sys.stdin).keys()))"   # credential top-level keys (NO secrets printed)
TOKEN=$(echo "$CRED" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('claudeAiOauth',{}).get('accessToken') or d.get('accessToken',''))")
curl -s https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20" \
  -o /tmp/ceai-usage-endpoint.json -w "HTTP %{http_code}\n"
python3 -m json.tool /tmp/ceai-usage-endpoint.json   # the real endpoint shape
```
Record: the credential key path to the access token, the endpoint HTTP status, the required headers, and the response field names for session/weekly/weekly-Sonnet utilization + reset timestamps.

- [ ] **Step 3: Confirm live control commands.** In a running `claude` session, the user runs `/help` and notes the exact commands/syntax for changing **model** and **effort** mid-session (expected `/model`; confirm whether `/effort`/thinking exists or requires a restart). Record findings.

- [ ] **Step 4: Save fixtures + notes.** Commit the captured (non-secret) JSON as test fixtures and a short notes file:
```bash
mkdir -p ~/Developer/CodeEdit/CodeEditTests/Features/Agent/Info/Fixtures
cp ~/.claude/ceai-capture.json        ~/Developer/CodeEdit/CodeEditTests/Features/Agent/Info/Fixtures/statusline-rate-limits.json
cp /tmp/ceai-usage-endpoint.json      ~/Developer/CodeEdit/CodeEditTests/Features/Agent/Info/Fixtures/usage-endpoint.json
# also copy a real ~/.claude.json oauthAccount subset (scrub tokens) -> Fixtures/oauth-account.json
cd ~/Developer/CodeEdit && git add CodeEditTests/Features/Agent/Info/Fixtures && git commit -m "test(agent-info): capture real usage/account fixtures"
```
**The exact field names recorded here are the source of truth** for the `CodingKeys` in Tasks 4–6. Where this plan's later code guesses a field name, adjust it to the fixture.

---

## Task 2: `ClaudeAccount` + reader + plan-tier mapping (TDD)

**Files:** Create `CodeEdit/Features/Agent/Info/ClaudeAccount.swift`; Test `CodeEditTests/Features/Agent/Info/ClaudeAccountReaderTests.swift`.

- [ ] **Step 1: Failing test** (uses `Fixtures/oauth-account.json` captured in Task 1; adjust the expected tier string to the fixture):
```swift
@testable import CodeEdit
import XCTest

final class ClaudeAccountReaderTests: XCTestCase {
    private func fixtureURL(_ name: String) -> URL {
        Bundle(for: Self.self).url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
            ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("Fixtures/\(name).json")
    }

    func testParsesAccountFromClaudeJSON() throws {
        let account = try ClaudeAccountReader.read(claudeJSONURL: fixtureURL("oauth-account"))
        XCTAssertEqual(account.email, "contact@bryanmourier.com")
        XCTAssertEqual(account.planDisplayName, "Max 20x")
    }

    func testTierMapping() {
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "default_claude_max_20x"), "Max 20x")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "default_claude_max_5x"), "Max 5x")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "default_claude_pro"), "Pro")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: "something_else"), "Something Else")
        XCTAssertEqual(ClaudeAccount.planDisplayName(forTier: nil), "Unknown")
    }
}
```

- [ ] **Step 2: Run test, verify it fails** (`cannot find 'ClaudeAccountReader'`). Use the BETA test command for `CodeEditTests/ClaudeAccountReaderTests`.

- [ ] **Step 3: Implement** `ClaudeAccount.swift`:
```swift
//
//  ClaudeAccount.swift
//  CodeEdit
//

import Foundation

/// A Claude Code account parsed from `~/.claude.json`.
struct ClaudeAccount: Equatable {
    let email: String
    let displayName: String
    let planDisplayName: String
    let hasExtraUsage: Bool

    /// Maps a Claude rate-limit tier id (e.g. "default_claude_max_20x") to a display name.
    static func planDisplayName(forTier tier: String?) -> String {
        guard let tier, !tier.isEmpty else { return "Unknown" }
        switch tier {
        case "default_claude_max_20x": return "Max 20x"
        case "default_claude_max_5x": return "Max 5x"
        default:
            if tier.contains("pro") { return "Pro" }
            // Humanize unknown tiers: "default_claude_x" -> "X"
            let cleaned = tier
                .replacingOccurrences(of: "default_", with: "")
                .replacingOccurrences(of: "claude_", with: "")
                .replacingOccurrences(of: "_", with: " ")
            return cleaned.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
        }
    }
}

/// Reads and decodes the `oauthAccount` object from `~/.claude.json`.
enum ClaudeAccountReader {
    struct DecodeError: Error {}

    private struct ClaudeJSON: Decodable {
        struct OAuthAccount: Decodable {
            let emailAddress: String?
            let displayName: String?
            let userRateLimitTier: String?
            let organizationRateLimitTier: String?
            let hasExtraUsageEnabled: Bool?
        }
        let oauthAccount: OAuthAccount?
    }

    static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    static func read(claudeJSONURL url: URL = defaultURL()) throws -> ClaudeAccount {
        let data = try Data(contentsOf: url)
        guard let oauth = try JSONDecoder().decode(ClaudeJSON.self, from: data).oauthAccount else {
            throw DecodeError()
        }
        let tier = oauth.userRateLimitTier ?? oauth.organizationRateLimitTier
        return ClaudeAccount(
            email: oauth.emailAddress ?? "Unknown",
            displayName: oauth.displayName ?? oauth.emailAddress ?? "Claude",
            planDisplayName: ClaudeAccount.planDisplayName(forTier: tier),
            hasExtraUsage: oauth.hasExtraUsageEnabled ?? false
        )
    }
}
```

- [ ] **Step 4: Run test, verify PASS.**
- [ ] **Step 5: Commit** `git add CodeEdit/Features/Agent/Info/ClaudeAccount.swift CodeEditTests/Features/Agent/Info/ClaudeAccountReaderTests.swift && git commit -m "feat(agent-info): read Claude account + plan tier"`

---

## Task 3: `ClaudeSettingsStore` (read/write model + effort) (TDD)

**Files:** Create `CodeEdit/Features/Agent/Info/ClaudeSettingsStore.swift`; Test `CodeEditTests/Features/Agent/Info/ClaudeSettingsStoreTests.swift`.

- [ ] **Step 1: Failing test** (round-trip must preserve unrelated keys):
```swift
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
        XCTAssertTrue(raw.contains("\"tui\""))           // unrelated key preserved
        XCTAssertEqual(store.read()?.model, "sonnet")
        XCTAssertEqual(store.read()?.effort, "high")
    }
}
```

- [ ] **Step 2: Run test, verify it fails.**
- [ ] **Step 3: Implement:**
```swift
//
//  ClaudeSettingsStore.swift
//  CodeEdit
//

import Foundation

/// The Claude model + effort read from `~/.claude/settings.json`.
struct ClaudeModelConfig: Equatable {
    var model: String?
    var effort: String?
}

/// Reads and updates `model` / `effortLevel` in `~/.claude/settings.json`,
/// preserving every other key (settings.json holds permissions, plugins, etc.).
struct ClaudeSettingsStore {
    let url: URL

    init(url: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")) {
        self.url = url
    }

    func read() -> ClaudeModelConfig? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return ClaudeModelConfig(model: obj["model"] as? String, effort: obj["effortLevel"] as? String)
    }

    func update(model: String?, effort: String?) throws {
        let data = (try? Data(contentsOf: url)) ?? Data("{}".utf8)
        var obj = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if let model { obj["model"] = model }
        if let effort { obj["effortLevel"] = effort }
        let out = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
    }
}
```

- [ ] **Step 4: Run test, verify PASS.**
- [ ] **Step 5: Commit** `git commit -m "feat(agent-info): read/write Claude model + effort settings"`

---

## Task 4: `ClaudeUsage` + decoders (statusline + endpoint shapes) (TDD)

Decode BOTH captured shapes into one `ClaudeUsage`. **Adjust the `CodingKeys` below to match the Task-1 fixtures** (field names are the community-known ones; the fixture is authoritative).

**Files:** Create `CodeEdit/Features/Agent/Info/ClaudeUsage.swift`; Test `CodeEditTests/Features/Agent/Info/ClaudeUsageTests.swift`.

- [ ] **Step 1: Failing test** (asserts decode of both fixtures; adjust expected numbers to the captured fixtures):
```swift
@testable import CodeEdit
import XCTest

final class ClaudeUsageTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/\(name).json")
        return try Data(contentsOf: url)
    }

    func testDecodesStatuslinePayload() throws {
        let usage = try ClaudeUsage(statuslineData: fixture("statusline-rate-limits"))
        XCTAssertNotNil(usage.session)
        XCTAssertNotNil(usage.weekly)
        XCTAssertTrue((0...100).contains(usage.session!.usedPercent))
    }

    func testDecodesEndpointPayload() throws {
        let usage = try ClaudeUsage(endpointData: fixture("usage-endpoint"))
        XCTAssertNotNil(usage.session)
        XCTAssertNotNil(usage.weekly)
    }
}
```

- [ ] **Step 2: Run test, verify it fails.**
- [ ] **Step 3: Implement** (the two initializers each decode their shape into the shared model; field names per Task-1 fixtures):
```swift
//
//  ClaudeUsage.swift
//  CodeEdit
//

import Foundation

/// One usage window: how much of the quota is used and when it resets.
struct UsageWindow: Equatable {
    let usedPercent: Double
    let resetsAt: Date?
}

/// Live Claude usage across the session (5h), weekly (7d), and weekly-Sonnet windows.
struct ClaudeUsage: Equatable {
    var session: UsageWindow?
    var weekly: UsageWindow?
    var weeklySonnet: UsageWindow?

    // MARK: Statusline shape: { "rate_limits": { "five_hour": {...}, "seven_day": {...}, "seven_day_sonnet"|... } }
    init(statuslineData data: Data) throws {
        struct Payload: Decodable { let rate_limits: RateLimits? }
        struct RateLimits: Decodable {
            let five_hour: Window?
            let seven_day: Window?
            let seven_day_sonnet: Window?
            let seven_day_opus: Window?    // tolerate variants; ignore unknown
        }
        // ADJUST these keys to the captured fixture field names.
        struct Window: Decodable {
            let utilization: Double?
            let used_pct: Double?
            let resets_at: String?
            var percent: Double { utilization ?? used_pct ?? 0 }
        }
        let p = try JSONDecoder().decode(Payload.self, from: data)
        func map(_ w: Window?) -> UsageWindow? {
            guard let w else { return nil }
            return UsageWindow(usedPercent: w.percent, resetsAt: ClaudeUsage.date(w.resets_at))
        }
        self.session = map(p.rate_limits?.five_hour)
        self.weekly = map(p.rate_limits?.seven_day)
        self.weeklySonnet = map(p.rate_limits?.seven_day_sonnet)
    }

    // MARK: Endpoint shape from GET /api/oauth/usage (ADJUST keys to the captured fixture).
    init(endpointData data: Data) throws {
        struct Payload: Decodable {
            let five_hour: Window?
            let seven_day: Window?
            let seven_day_sonnet: Window?
        }
        struct Window: Decodable {
            let utilization: Double?
            let resets_at: String?
        }
        let p = try JSONDecoder().decode(Payload.self, from: data)
        func map(_ w: Window?) -> UsageWindow? {
            guard let w else { return nil }
            return UsageWindow(usedPercent: w.utilization ?? 0, resetsAt: ClaudeUsage.date(w.resets_at))
        }
        self.session = map(p.five_hour)
        self.weekly = map(p.seven_day)
        self.weeklySonnet = map(p.seven_day_sonnet)
    }

    private static func date(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return ISO8601DateFormatter().date(from: iso)
    }
}
```

- [ ] **Step 4: Run test, verify PASS** (fix `CodingKeys` until it decodes the real fixtures).
- [ ] **Step 5: Commit** `git commit -m "feat(agent-info): decode Claude usage (statusline + endpoint)"`

---

## Task 5: `ClaudeUsageEndpointClient` (Keychain token + GET) — build + manual

**Files:** Create `CodeEdit/Features/Agent/Info/ClaudeUsageEndpointClient.swift`.

- [ ] **Step 1: Implement** (no unit test — network + Keychain; verified manually). Use the token key path and headers recorded in Task 1:
```swift
//
//  ClaudeUsageEndpointClient.swift
//  CodeEdit
//

import Foundation
import Security

/// Fetches Claude usage from the (undocumented) OAuth usage endpoint, used as a
/// fallback when no live statusline data is available.
enum ClaudeUsageEndpointClient {
    enum ClientError: Error { case noToken, badResponse }

    /// Reads the Claude Code OAuth access token from the macOS Keychain.
    static func accessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        // ADJUST key path to the credential shape captured in Task 1.
        if let oauth = obj["claudeAiOauth"] as? [String: Any], let t = oauth["accessToken"] as? String {
            return t
        }
        return obj["accessToken"] as? String
    }

    static func fetchUsage() async throws -> ClaudeUsage {
        guard let token = accessToken() else { throw ClientError.noToken }
        var req = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.badResponse
        }
        return try ClaudeUsage(endpointData: data)
    }
}
```

- [ ] **Step 2: BETA BUILD** — verify it compiles.
- [ ] **Step 3: Commit** `git commit -m "feat(agent-info): keychain-backed usage endpoint fallback"`

---

## Task 6: `ClaudeUsageStatuslineInstaller` (idempotent install) (TDD for merge logic)

**Files:** Create `CodeEdit/Features/Agent/Info/ClaudeUsageStatuslineInstaller.swift`; Test `CodeEditTests/Features/Agent/Info/ClaudeUsageStatuslineInstallerTests.swift`.

- [ ] **Step 1: Failing test** (installs only when absent; never clobbers an existing statusLine):
```swift
@testable import CodeEdit
import XCTest

final class ClaudeUsageStatuslineInstallerTests: XCTestCase {
    func testInstallsWhenAbsent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = dir.appendingPathComponent("settings.json")
        try "{}".write(to: settings, atomically: true, encoding: .utf8)
        let installer = ClaudeUsageStatuslineInstaller(claudeDir: dir)
        XCTAssertEqual(try installer.ensureInstalled(), .installed)
        let raw = try String(contentsOf: settings, encoding: .utf8)
        XCTAssertTrue(raw.contains("statusLine"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("codeeditai-statusline.sh").path))
    }

    func testDoesNotClobberExisting() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = dir.appendingPathComponent("settings.json")
        try #"{"statusLine":{"type":"command","command":"mytool"}}"#.write(to: settings, atomically: true, encoding: .utf8)
        let installer = ClaudeUsageStatuslineInstaller(claudeDir: dir)
        XCTAssertEqual(try installer.ensureInstalled(), .foreignStatuslinePresent)
        XCTAssertTrue(try String(contentsOf: settings, encoding: .utf8).contains("mytool"))
    }
}
```

- [ ] **Step 2: Run test, verify it fails.**
- [ ] **Step 3: Implement:**
```swift
//
//  ClaudeUsageStatuslineInstaller.swift
//  CodeEdit
//

import Foundation

/// Installs a statusLine command into `~/.claude/settings.json` that writes the
/// `rate_limits` payload to `codeeditai-usage.json`, without clobbering an existing one.
struct ClaudeUsageStatuslineInstaller {
    enum Result: Equatable { case installed, alreadyOurs, foreignStatuslinePresent, noSettings }

    let claudeDir: URL
    init(claudeDir: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")) {
        self.claudeDir = claudeDir
    }

    var usageFileURL: URL { claudeDir.appendingPathComponent("codeeditai-usage.json") }
    private var scriptURL: URL { claudeDir.appendingPathComponent("codeeditai-statusline.sh") }
    private var settingsURL: URL { claudeDir.appendingPathComponent("settings.json") }
    private let marker = "codeeditai-statusline.sh"

    @discardableResult
    func ensureInstalled() throws -> Result {
        guard let data = try? Data(contentsOf: settingsURL),
              var obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .noSettings
        }
        if let sl = obj["statusLine"] as? [String: Any], let cmd = sl["command"] as? String {
            return cmd.contains(marker) ? .alreadyOurs : .foreignStatuslinePresent
        }
        // Write the capture script (reads stdin JSON, saves rate_limits, echoes a minimal line).
        let script = """
        #!/bin/zsh
        input=$(cat)
        printf '%s' "$input" | /usr/bin/python3 -c 'import sys,json,os
        d=json.load(sys.stdin); rl=d.get("rate_limits")
        open(os.path.expanduser("~/.claude/codeeditai-usage.json"),"w").write(json.dumps(rl or {}))' 2>/dev/null
        model=$(printf '%s' "$input" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("model",{}).get("display_name",""))' 2>/dev/null)
        printf '%s' "$model"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        obj["statusLine"] = ["type": "command", "command": scriptURL.path]
        let out = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: settingsURL, options: .atomic)
        return .installed
    }
}
```

- [ ] **Step 4: Run test, verify PASS.**
- [ ] **Step 5: Commit** `git commit -m "feat(agent-info): idempotent usage statusline installer"`

---

## Task 7: `ClaudeSession.send` for control injection — build

**Files:** Modify `CodeEdit/Features/Agent/ClaudeSession.swift`.

- [ ] **Step 1: Add** a `send` method + running flag (used by the model picker to inject `/model …`):
```swift
    /// Whether the claude process is currently running.
    var isRunning: Bool { terminalView?.process.running ?? false }

    /// Sends raw text (e.g. a slash command) to the running claude TUI.
    func send(_ text: String) {
        guard let view = terminalView, view.process.running else { return }
        view.process.send(data: Array(text.utf8)[...])
    }
```

- [ ] **Step 2: BETA BUILD.**
- [ ] **Step 3: Commit** `git commit -m "feat(agent): expose ClaudeSession.send for control injection"`

---

## Task 8: `ClaudeInfoModel` (aggregate + watch + refresh) — build + manual

**Files:** Create `CodeEdit/Features/Agent/Info/ClaudeInfoModel.swift`.

- [ ] **Step 1: Implement** (aggregates account/config/usage; polls the usage file every 2s while active — simpler and robust vs raw FSEvents; falls back to the endpoint when the file is stale/missing; recomputes countdowns):
```swift
//
//  ClaudeInfoModel.swift
//  CodeEdit
//

import Foundation
import Combine

@MainActor
final class ClaudeInfoModel: ObservableObject {
    @Published private(set) var account: ClaudeAccount?
    @Published private(set) var config: ClaudeModelConfig = .init()
    @Published private(set) var usage: ClaudeUsage = .init()
    @Published private(set) var usageIsStale = false

    private let settingsStore = ClaudeSettingsStore()
    private let installer = ClaudeUsageStatuslineInstaller()
    private var timer: AnyCancellable?
    private weak var session: ClaudeSession?

    func start(session: ClaudeSession?) {
        self.session = session
        try? installer.ensureInstalled()
        reloadStaticData()
        Task { await refreshUsage() }
        timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() { timer?.cancel(); timer = nil }

    func reloadStaticData() {
        account = try? ClaudeAccountReader.read()
        config = settingsStore.read() ?? .init()
    }

    private func tick() {
        if let data = try? Data(contentsOf: installer.usageFileURL),
           let parsed = try? ClaudeUsage(statuslineData: data) {
            usage = parsed
            usageIsStale = false
        } else if session?.isRunning != true {
            Task { await refreshUsage() }
        }
        objectWillChange.send() // refresh reset countdowns
    }

    func refreshUsage() async {
        if let parsed = try? await ClaudeUsageEndpointClient.fetchUsage() {
            usage = parsed
            usageIsStale = false
        } else {
            usageIsStale = true
        }
    }

    // MARK: Controls
    func setModel(_ model: String) {
        try? settingsStore.update(model: model, effort: nil)
        session?.send("/model \(model)\n")   // ADJUST command per Task 1 if needed
        reloadStaticData()
    }

    func setEffort(_ effort: String) {
        try? settingsStore.update(model: nil, effort: effort)
        reloadStaticData()
        // Effort applies to new sessions; UI offers "Restart Agent session" (Task 9).
    }
}
```

- [ ] **Step 2: BETA BUILD.**
- [ ] **Step 3: Commit** `git commit -m "feat(agent-info): ClaudeInfoModel aggregating account, config, usage"`

---

## Task 9: Inspector UI — `UsageMeter`, `ModelEffortPicker`, `ClaudeInfoInspectorView` — build

**Files:** Create `CodeEdit/Features/Agent/Info/UsageMeter.swift`, `ModelEffortPicker.swift`, `ClaudeInfoInspectorView.swift`.

- [ ] **Step 1: `UsageMeter.swift`:**
```swift
import SwiftUI

/// One usage window rendered as a labeled progress bar + reset countdown.
struct UsageMeter: View {
    let title: String
    let window: UsageWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.callout.weight(.medium))
                Spacer()
                Text(window.map { "\(Int($0.usedPercent))%" } ?? "—")
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
            ProgressView(value: (window?.usedPercent ?? 0) / 100)
                .tint((window?.usedPercent ?? 0) > 90 ? .red : .accentColor)
            if let resets = window?.resetsAt {
                Text("Resets \(resets, format: .relative(presentation: .named))")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
```

- [ ] **Step 2: `ModelEffortPicker.swift`** (menus + thinking note; model ids per Task-1 findings — defaults shown):
```swift
import SwiftUI

struct ModelEffortPicker: View {
    @ObservedObject var model: ClaudeInfoModel
    private let models = ["opus", "sonnet", "haiku"]
    private let efforts = ["low", "medium", "high", "xhigh", "max"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Model") {
                Menu(model.config.model ?? "default") {
                    ForEach(models, id: \.self) { m in Button(m) { model.setModel(m) } }
                }
            }
            LabeledContent("Effort / Thinking") {
                Menu(model.config.effort ?? "default") {
                    ForEach(efforts, id: \.self) { e in Button(e) { model.setEffort(e) } }
                }
            }
            Text("Higher effort = more thinking. Effort applies to new sessions.")
                .font(.caption).foregroundStyle(.tertiary)
        }
    }
}
```

- [ ] **Step 3: `ClaudeInfoInspectorView.swift`:**
```swift
import SwiftUI

/// The Inspector content shown in Agent mode: account, plan, live usage, and controls.
struct ClaudeInfoInspectorView: View {
    @ObservedObject var model: ClaudeInfoModel

    var body: some View {
        Form {
            Section {
                LabeledContent("Account", value: model.account?.email ?? "—")
                LabeledContent("Plan", value: model.account?.planDisplayName ?? "—")
            }
            Section("Usage") {
                UsageMeter(title: "Session (5h)", window: model.usage.session)
                UsageMeter(title: "Weekly (7d)", window: model.usage.weekly)
                UsageMeter(title: "Weekly Sonnet", window: model.usage.weeklySonnet)
                if model.usageIsStale {
                    Text("Usage unavailable — run an Agent session or refresh.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Refresh") { Task { await model.refreshUsage() } }
            }
            Section("Model") { ModelEffortPicker(model: model) }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 4: BETA BUILD.**
- [ ] **Step 5: Commit** `git commit -m "feat(agent-info): Claude info inspector UI (account, usage meters, controls)"`

---

## Task 10: Wire the Inspector to swap in Agent mode — build + manual acceptance

**Files:** Modify `CodeEdit/Features/InspectorArea/Views/InspectorAreaView.swift`.

- [ ] **Step 1: Add** a workspace observation + the model, and swap the body:
```swift
    @StateObject private var claudeInfoModel = ClaudeInfoModel()
```
Replace `var body: some View { WorkspacePanelView(...) ... }` so it switches on mode:
```swift
    var body: some View {
        Group {
            if workspace.workspaceMode == .agent {
                ClaudeInfoInspectorView(model: claudeInfoModel)
                    .onAppear { claudeInfoModel.start(session: nil) }
                    .onDisappear { claudeInfoModel.stop() }
            } else {
                WorkspacePanelView(
                    viewModel: viewModel,
                    selectedTab: $viewModel.selectedTab,
                    tabItems: $viewModel.tabItems,
                    sidebarPosition: sidebarPosition
                )
            }
        }
        .formStyle(.grouped)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("inspector")
        .onChange(of: showInternalDevelopmentInspector) { _, _ in updateTabs() }
    }
```
(`workspace` is already `@EnvironmentObject`; observing `workspace.workspaceMode` re-renders on toggle.)

- [ ] **Step 2: BETA BUILD.**
- [ ] **Step 3: Manual acceptance** in Xcode 27 beta: open a folder, switch to Agent, open the Inspector (right toggle). It shows account (contact@bryanmourier.com), plan (Max 20x), three usage meters that populate once `claude` has run (or via Refresh), and a working Model/Effort picker. Switch to Editor → normal File/History tabs return.

- [ ] **Step 4: Commit** `git commit -m "feat(agent-info): show Claude info inspector in Agent mode"`

---

## Final acceptance

- [ ] BETA BUILD green; unit tests (Tasks 2,3,4,6) pass.
- [ ] Agent mode Inspector shows account + plan + 3 live usage meters (Session/Weekly/Weekly Sonnet) with reset countdowns.
- [ ] Model picker changes the live session (`/model`); effort writes settings.json.
- [ ] Editor mode Inspector unchanged.
- [ ] Statusline install did not clobber any existing statusLine; endpoint fallback works with no active session.

## Notes / deliberate limits

- Usage field names + control commands are pinned by **Task 1** fixtures; later tasks' `CodingKeys`/commands are adjusted to match.
- "Thinking" is surfaced via the effort menu (Claude Code 2.x couples them); a dedicated toggle is added only if Task 1 finds a real setting.
- Effort/model changes that the TUI can't apply live use settings.json + a future "Restart Agent session" affordance.
