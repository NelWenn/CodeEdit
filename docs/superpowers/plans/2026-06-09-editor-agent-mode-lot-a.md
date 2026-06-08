# Editor/Agent Mode (Lot A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a top-right Editor/Agent toolbar toggle that swaps the central editor area for the `claude` CLI, while keeping the file navigator and console.

**Architecture:** A per-workspace `WorkspaceMode` (`.editor`/`.agent`) lives on `WorkspaceDocument` (`@Published`). A SwiftUI segmented control hosted in the AppKit `NSToolbar` (just before the Inspector toggle) writes it. `WorkspaceView.editorArea` reads it and renders either the existing `EditorLayoutView` or a new `ClaudeAgentView` (a full-frame SwiftTerm terminal running `claude`). The navigator (outer AppKit split) and console (bottom of `WorkspaceView`) are untouched.

**Tech Stack:** Swift 6.4 / SwiftUI + AppKit, SwiftTerm (already a dependency), Xcode 27 beta.

---

## ⚠️ Build/verify command (used by every task)

The user is on macOS 27 beta → must compile with **Xcode 27 beta (Swift 6.4)**, which `xcode-select` does NOT point to. Every build/verify step runs exactly:

```bash
cd ~/Developer/CodeEdit
DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer \
xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta \
  -skipPackagePluginValidation build > /tmp/ceai_build.log 2>&1
echo "EXIT=$?"
grep -E "\*\* BUILD (SUCCEEDED|FAILED) \*\*" /tmp/ceai_build.log | tail -1
grep -n "error:" /tmp/ceai_build.log | head
```
Expected on success: `** BUILD SUCCEEDED **` and no `error:` lines. (Do NOT trust the shell exit code of piped commands — read the verdict from the log.)

The Swift **module name is `CodeEdit`** (PRODUCT_NAME unchanged), so tests use `@testable import CodeEdit`. The project uses synchronized file groups, so new files placed in the folders below are auto-added to their target — no `.pbxproj` edits.

---

## File Structure

- Create `CodeEdit/Features/Agent/WorkspaceMode.swift` — the mode enum.
- Create `CodeEdit/Features/Agent/EditorAgentToggle.swift` — toolbar segmented control.
- Create `CodeEdit/Features/Agent/ClaudeSession.swift` — owns the long-lived `claude` terminal.
- Create `CodeEdit/Features/Agent/ClaudeAgentView.swift` — NSViewRepresentable hosting the terminal.
- Create `CodeEditTests/Features/Agent/WorkspaceModeTests.swift` — unit test for the enum.
- Modify `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift` — add `@Published var workspaceMode`.
- Modify `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceStateKey.swift` — add persistence key.
- Modify `CodeEdit/Features/Documents/Controllers/CodeEditWindowControllerExtensions.swift` — add toolbar identifier.
- Modify `CodeEdit/Features/Documents/Controllers/CodeEditWindowController+Toolbar.swift` — build + place the item.
- Modify `CodeEdit/WorkspaceView.swift` — swap `editorArea`, restore persisted mode.

---

### Task 1: `WorkspaceMode` enum (TDD)

**Files:**
- Create: `CodeEdit/Features/Agent/WorkspaceMode.swift`
- Test: `CodeEditTests/Features/Agent/WorkspaceModeTests.swift`

- [ ] **Step 1: Write the failing test**

`CodeEditTests/Features/Agent/WorkspaceModeTests.swift`:
```swift
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
```

- [ ] **Step 2: Run the test, verify it fails to compile**

Run the BETA BUILD command but with `test` and `-only-testing`:
```bash
DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer \
xcodebuild test -project CodeEdit.xcodeproj -scheme CodeEdit \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta \
  -skipPackagePluginValidation -only-testing:CodeEditTests/WorkspaceModeTests \
  > /tmp/ceai_test.log 2>&1; echo "EXIT=$?"; tail -5 /tmp/ceai_test.log
```
Expected: FAIL — `cannot find 'WorkspaceMode' in scope`.

- [ ] **Step 3: Create the enum**

`CodeEdit/Features/Agent/WorkspaceMode.swift`:
```swift
//
//  WorkspaceMode.swift
//  CodeEdit
//

import Foundation

/// Whether the workspace's central area shows the code editor or the Claude agent.
enum WorkspaceMode: String, CaseIterable, Identifiable {
    case editor
    case agent

    var id: Self { self }

    var title: String {
        switch self {
        case .editor: return "Editor"
        case .agent: return "Agent"
        }
    }

    var systemImage: String {
        switch self {
        case .editor: return "doc.text"
        case .agent: return "sparkles"
        }
    }
}
```

- [ ] **Step 4: Run the test, verify it passes**

Run the Step 2 command. Expected: `** TEST SUCCEEDED **`, 3 tests passed.

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Agent/WorkspaceMode.swift CodeEditTests/Features/Agent/WorkspaceModeTests.swift
git commit -m "feat(agent): add WorkspaceMode enum"
```

---

### Task 2: `workspaceMode` state on `WorkspaceDocument`

**Files:**
- Modify: `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift` (just before `func getFromWorkspaceState`, around line 71)

- [ ] **Step 1: Add the published property**

In `WorkspaceDocument.swift`, immediately above `func getFromWorkspaceState(_ key: WorkspaceStateKey) -> Any? {`, add:
```swift
    /// The current central-area mode (code editor vs. Claude agent). Persisted in Task 7.
    @Published var workspaceMode: WorkspaceMode = .editor
```

- [ ] **Step 2: Build, verify it compiles**

Run the BETA BUILD command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift
git commit -m "feat(agent): add workspaceMode state to WorkspaceDocument"
```

---

### Task 3: `EditorAgentToggle` segmented control

**Files:**
- Create: `CodeEdit/Features/Agent/EditorAgentToggle.swift`

- [ ] **Step 1: Create the view**

`CodeEdit/Features/Agent/EditorAgentToggle.swift`:
```swift
//
//  EditorAgentToggle.swift
//  CodeEdit
//

import SwiftUI

/// Toolbar segmented control that switches the workspace between Editor and Agent modes.
struct EditorAgentToggle: View {
    @EnvironmentObject private var workspace: WorkspaceDocument

    var body: some View {
        Picker(
            "Editor or Agent",
            selection: Binding(
                get: { workspace.workspaceMode },
                set: { workspace.workspaceMode = $0 }
            )
        ) {
            ForEach(WorkspaceMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}
```

- [ ] **Step 2: Build, verify it compiles**

Run the BETA BUILD command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add CodeEdit/Features/Agent/EditorAgentToggle.swift
git commit -m "feat(agent): add EditorAgentToggle segmented control"
```

---

### Task 4: Toolbar item + placement (before the Inspector toggle)

**Files:**
- Modify: `CodeEdit/Features/Documents/Controllers/CodeEditWindowControllerExtensions.swift:117`
- Modify: `CodeEdit/Features/Documents/Controllers/CodeEditWindowController+Toolbar.swift`

- [ ] **Step 1: Add the toolbar identifier**

In `CodeEditWindowControllerExtensions.swift`, in the `extension NSToolbarItem.Identifier { ... }` block (after the `toggleLastSidebarItem` line), add:
```swift
    static let editorAgentModeItem: NSToolbarItem.Identifier = NSToolbarItem.Identifier("EditorAgentModeItem")
```

- [ ] **Step 2: Place the item before the Inspector toggle**

In `CodeEditWindowController+Toolbar.swift`, in `toolbarDefaultItemIdentifiers`, change the trailing block (currently):
```swift
        items += [
            .flexibleSpace,
            .itemListTrackingSeparator,
            .flexibleSpace,
            .toggleLastSidebarItem
        ]
```
to:
```swift
        items += [
            .flexibleSpace,
            .itemListTrackingSeparator,
            .flexibleSpace,
            .editorAgentModeItem,
            .toggleLastSidebarItem
        ]
```

- [ ] **Step 3: Allow the item**

In the same file, in `toolbarAllowedItemIdentifiers`, add `.editorAgentModeItem` to the first `items` array (e.g., right after `.toggleLastSidebarItem,`).

- [ ] **Step 4: Build the item**

In the same file, in `func toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)`, add a case before `default:`:
```swift
        case .editorAgentModeItem:
            return editorAgentModeItem()
```
Then add this private method (next to `notificationItem()`):
```swift
    private func editorAgentModeItem() -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: .editorAgentModeItem)
        toolbarItem.paletteLabel = "Editor / Agent"
        toolbarItem.toolTip = "Switch between the editor and the Claude agent"
        guard let workspace else { return nil }
        let view = NSHostingView(rootView: EditorAgentToggle().environmentObject(workspace))
        toolbarItem.view = view
        return toolbarItem
    }
```

- [ ] **Step 5: Build, verify it compiles**

Run the BETA BUILD command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manual check**

Open the project in Xcode 27 beta, `Cmd+R`, open a folder. A `[ Editor | Agent ]` segmented control appears in the toolbar, immediately to the left of the Inspector toggle. Switching it does nothing visible yet (wired in Task 6).

- [ ] **Step 7: Commit**

```bash
git add CodeEdit/Features/Documents/Controllers/CodeEditWindowControllerExtensions.swift \
        CodeEdit/Features/Documents/Controllers/CodeEditWindowController+Toolbar.swift
git commit -m "feat(agent): add Editor/Agent toolbar toggle before Inspector"
```

---

### Task 5: `ClaudeSession` + `ClaudeAgentView`

**Files:**
- Create: `CodeEdit/Features/Agent/ClaudeSession.swift`
- Create: `CodeEdit/Features/Agent/ClaudeAgentView.swift`

- [ ] **Step 1: Create `ClaudeSession`**

`CodeEdit/Features/Agent/ClaudeSession.swift`:
```swift
//
//  ClaudeSession.swift
//  CodeEdit
//

import AppKit
import SwiftTerm

/// Owns the long-lived `claude` terminal for a workspace so the session survives
/// toggling between Editor and Agent modes.
final class ClaudeSession: ObservableObject {
    private var terminalView: CELocalShellTerminalView?
    private var hasLaunchedClaude = false

    /// Returns the existing terminal view, or creates one rooted at `workspaceURL`,
    /// starts the login shell, and launches the Claude Code CLI inside it.
    func makeOrReuseTerminal(workspaceURL: URL?) -> CELocalShellTerminalView {
        if let terminalView {
            return terminalView
        }
        let view = CELocalShellTerminalView(frame: .zero)
        view.startProcess(workspaceURL: workspaceURL)
        terminalView = view
        launchClaudeIfNeeded(in: view)
        return view
    }

    private func launchClaudeIfNeeded(in view: CELocalShellTerminalView) {
        guard !hasLaunchedClaude else { return }
        hasLaunchedClaude = true
        // Let the login shell finish initializing (PATH, rc files) before running claude.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            view.process.send(data: Array("claude\n".utf8)[...])
        }
    }
}
```

- [ ] **Step 2: Create `ClaudeAgentView`**

`CodeEdit/Features/Agent/ClaudeAgentView.swift`:
```swift
//
//  ClaudeAgentView.swift
//  CodeEdit
//

import SwiftUI
import SwiftTerm

/// Full-frame view hosting the `claude` CLI for Agent mode.
struct ClaudeAgentView: NSViewRepresentable {
    @ObservedObject var session: ClaudeSession
    let workspaceURL: URL?

    func makeNSView(context: Context) -> CELocalShellTerminalView {
        let view = session.makeOrReuseTerminal(workspaceURL: workspaceURL)
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        return view
    }

    func updateNSView(_ nsView: CELocalShellTerminalView, context: Context) { }
}
```

- [ ] **Step 3: Build, verify it compiles**

Run the BETA BUILD command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add CodeEdit/Features/Agent/ClaudeSession.swift CodeEdit/Features/Agent/ClaudeAgentView.swift
git commit -m "feat(agent): add ClaudeSession and ClaudeAgentView (claude in SwiftTerm)"
```

---

### Task 6: Swap `editorArea` on mode (the feature comes alive)

**Files:**
- Modify: `CodeEdit/WorkspaceView.swift` (add `claudeSession` state; rewrite `editorArea`)

- [ ] **Step 1: Add the session state object**

In `WorkspaceView.swift`, with the other `@StateObject` declarations (near line 30), add:
```swift
    @StateObject private var claudeSession = ClaudeSession()
```

- [ ] **Step 2: Rewrite `editorArea` to switch on mode**

Replace the entire `editorArea` computed property (currently lines ~136–158) with:
```swift
    @ViewBuilder private var editorArea: some View {
        ZStack {
            GeometryReader { geo in
                Group {
                    switch workspace.workspaceMode {
                    case .editor:
                        EditorLayoutView(
                            layout: editorManager.isFocusingActiveEditor
                            ? editorManager.activeEditor.getEditorLayout() ?? editorManager.editorLayout
                            : editorManager.editorLayout,
                            focus: $focusedEditor
                        )
                    case .agent:
                        ClaudeAgentView(
                            session: claudeSession,
                            workspaceURL: workspace.workspaceFileManager?.folderUrl
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onChange(of: geo.size.height) { _, newHeight in
                    editorsHeight = newHeight
                }
                .onAppear {
                    editorsHeight = geo.size.height
                }
            }
        }
        .frame(minHeight: 170 + 29 + 29)
        .collapsable()
        .collapsed($utilityAreaViewModel.isMaximized)
        .holdingPriority(.init(1))
    }
```

- [ ] **Step 3: Build, verify it compiles**

Run the BETA BUILD command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manual acceptance**

In Xcode 27 beta, `Cmd+R`, open a folder:
- Default is **Editor** (normal editor).
- Click **Agent** → the central editor area is replaced by a terminal that launches `claude` in the workspace root. The **file navigator (left)** and the **console (bottom)** are still there and usable.
- Click **Editor** → the editor returns; clicking **Agent** again resumes the same `claude` session (not a new one).

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/WorkspaceView.swift
git commit -m "feat(agent): swap editor area for claude in Agent mode"
```

---

### Task 7: Persist & restore the mode per workspace

**Files:**
- Modify: `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceStateKey.swift`
- Modify: `CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift`
- Modify: `CodeEdit/WorkspaceView.swift`

- [ ] **Step 1: Add the state key**

In `WorkspaceStateKey.swift`, add a case to the enum:
```swift
    case workspaceMode
```

- [ ] **Step 2: Persist on change**

In `WorkspaceDocument.swift`, change the property from Task 2 to persist via `didSet`:
```swift
    /// The current central-area mode (code editor vs. Claude agent), persisted per workspace.
    @Published var workspaceMode: WorkspaceMode = .editor {
        didSet {
            addToWorkspaceState(key: .workspaceMode, value: workspaceMode.rawValue)
        }
    }
```

- [ ] **Step 3: Restore on appear**

In `WorkspaceView.swift`, add an `.onAppear` to the outer `VStack`/`SplitViewReader` content (alongside the existing `.task`/`.onChange` modifiers near line 73), restoring the saved mode:
```swift
                    .onAppear {
                        if let raw = workspace.getFromWorkspaceState(.workspaceMode) as? String,
                           let mode = WorkspaceMode(rawValue: raw) {
                            workspace.workspaceMode = mode
                        }
                    }
```

- [ ] **Step 4: Build, verify it compiles**

Run the BETA BUILD command. Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Manual check**

Run in Xcode 27 beta: switch to **Agent**, quit and reopen the workspace → it reopens in **Agent** mode. Switch to **Editor**, reopen → reopens in **Editor**.

- [ ] **Step 6: Commit**

```bash
git add CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceStateKey.swift \
        CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift \
        CodeEdit/WorkspaceView.swift
git commit -m "feat(agent): persist and restore workspace mode"
```

---

## Final acceptance (Lot A done)

- [ ] BETA BUILD is green.
- [ ] Toolbar shows `[ Editor | Agent ]` immediately left of the Inspector toggle.
- [ ] Editor mode = normal IDE. Agent mode = `claude` CLI full-frame, with navigator + console still present.
- [ ] Toggling back and forth resumes the same `claude` session.
- [ ] Mode is remembered per workspace across relaunch.

## Notes / deliberate v1 limits (polish later, not in Lot A)

- If `claude` is not on `PATH`, the terminal shows the shell's `command not found`; a dedicated "not installed" banner is a later polish.
- The terminal uses a default monospaced font; full theme integration (colors/font from `TerminalEmulatorView.configureView`) is later polish.
- Auto-sending the current file/selection as context is out of scope (Agent mode hides the editor; context UX needs its own design).
- **Lot B** (console dockable bottom/right) is a separate spec/plan.
