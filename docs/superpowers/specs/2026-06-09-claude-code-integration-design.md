# Claude Code Integration — Design (Editor/Agent Mode)

**Date:** 2026-06-09
**Status:** Approved (Lot A); Lot B deferred
**Base:** Fork of [CodeEditApp/CodeEdit](https://github.com/CodeEditApp/CodeEdit) (MIT), rebranded **CodeEditAi**.

> Supersedes the earlier "Claude tab in the Inspector" approach. The user wants a
> full **Editor ⇄ Agent mode** toggle that transforms the central area, not a side tab.

## Build constraint

CodeEditAi must be built with **Xcode 27 beta (Swift 6.4)** at
`~/Downloads/Xcode-beta.app` (the user is on macOS 27 beta). CLI verification must set
`DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer`,
since `xcode-select` points to the stable Xcode 26.5 whose Swift 6.3.2 silently
accepts code that 6.4 rejects.

## Goal

Add an **Editor / Agent** toggle in the top-right of the toolbar (just before the
Inspector toggle). Two modes for the workspace:

- **Editor** (default): the classic IDE — central code editor.
- **Agent**: the central editor area is replaced by the **Claude Code CLI** (`claude`)
  running full-frame. The **file navigator** (left) and the **console/terminal**
  remain visible and usable.

## Why not the VSCode extension

The official Claude Code product for VSCode is a VSCode extension; extensions only run
in VSCode's Electron Extension Host and cannot load into a native AppKit/SwiftUI app.
The intelligence is the `claude` CLI; we host that directly — fully native.

## Architecture (how it plugs into CodeEdit)

CodeEdit's window is an AppKit `CodeEditSplitViewController` (NSSplitViewController) with
three panes: **navigator | center | inspector**, plus an `NSToolbar`
(`CodeEditWindowController+Toolbar.swift`). The **center** pane is the SwiftUI
`WorkspaceView`, itself a vertical split of `editorArea` (top) and the utility
area/console (bottom).

### Lot A — Editor/Agent mode (this milestone)

| Unit | Responsibility | Plugs into |
|---|---|---|
| `WorkspaceMode` (enum `.editor`/`.agent`) | the mode value | new file |
| `WorkspaceDocument.workspaceMode` (`@Published`) | per-workspace mode state, persisted in workspace state (like `toolbarCollapsed`) | `WorkspaceDocument` |
| `EditorAgentToggle` | SwiftUI segmented control `[ Editor \| Agent ]` (SF Symbols `doc.text` / `sparkles`) bound to `workspaceMode` | hosted in toolbar |
| `.editorAgentModeItem` toolbar item | `NSToolbarItem` (NSHostingView of `EditorAgentToggle`), inserted in `toolbarDefaultItemIdentifiers` immediately **before** `.toggleLastSidebarItem` | `CodeEditWindowController+Toolbar.swift` |
| `ClaudeAgentView` | `NSViewRepresentable` wrapping a SwiftTerm local-process view that runs `claude` in the workspace root | new file, models on `TerminalEmulatorView` / `CELocalShellTerminalView` |
| `ClaudeSession` (`ObservableObject`) | lifecycle of the `claude` process for the workspace; created lazily on first switch to Agent, kept alive when toggling back (cached like `TerminalCache`) | new file |

**The swap** happens in `WorkspaceView.editorArea`:

```
switch workspace.workspaceMode {
case .editor: EditorLayoutView(...)   // existing
case .agent:  ClaudeAgentView()       // full-frame claude terminal
}
```

The navigator (outer AppKit split) and the console (bottom of `WorkspaceView`) are
untouched. In Agent mode the editor tab bar is not shown (the whole editor area is
replaced).

### Data flow (Agent mode)

1. Toggling to **Agent** sets `workspace.workspaceMode = .agent`.
2. `WorkspaceView.editorArea` renders `ClaudeAgentView`, which (via `ClaudeSession`)
   spawns `claude` through the user's login shell (`/bin/zsh -lc 'claude'`) with `cwd` =
   workspace root. Going through the login shell resolves `PATH` (the app is sandboxed;
   this mirrors how the existing terminal launches the shell).
3. Toggling back to **Editor** keeps the `claude` process alive (cached) so the session
   resumes on return.

### Error handling

- **`claude` not on PATH** — `ClaudeAgentView` shows a banner ("Claude Code n'est pas
  installé") with the install command instead of a dead terminal (probe via `which claude`).
- The toggle is always available; switching to Agent with no workspace folder is a no-op
  banner.

### Testing

- `WorkspaceMode` + persistence (read/write workspace state) — unit-testable in
  `CodeEditTests`.
- Toolbar item presence/placement — light unit/manual check.
- Process spawn + terminal rendering — manual verification (run app, toggle, see `claude`).

### Out of scope for Lot A

- Auto-sending current file/selection as context (possible later; the editor isn't
  visible in Agent mode, so context UX needs its own thought).
- Multiple concurrent Claude sessions.

## Lot B — Console dockable bottom/right (deferred)

Make the console (`UtilityAreaView`, currently the bottom item of `WorkspaceView`'s
vertical `SplitView`, positioned via overlay) dockable to either **bottom** or **right**.
Requires restructuring `WorkspaceView`'s split to support a horizontal axis and a
`consoleDockPosition` setting. Riskiest layout change → its own spec/plan after Lot A is
verified working.

## Verification (each lot)

Build green with the beta toolchain:
`DEVELOPER_DIR=<beta> xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Debug -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/ceai_beta -skipPackagePluginValidation build`
then run in Xcode 27 beta and exercise the toggle.
