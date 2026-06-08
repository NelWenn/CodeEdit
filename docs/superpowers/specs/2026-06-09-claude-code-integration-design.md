# Claude Code Integration — Design

**Date:** 2026-06-09
**Status:** Approved (pending written-spec review)
**Base:** Fork of [CodeEditApp/CodeEdit](https://github.com/CodeEditApp/CodeEdit) (MIT), native macOS SwiftUI IDE.

## Goal

Turn the CodeEdit fork into the user's daily-driver, AI-native IDE by adding a
dedicated **Claude** panel that hosts the official `claude` CLI (Claude Code) and
automatically feeds it the current file / selection as context.

The IDE already provides the other three requested pieces out of the box:

- File tree (left) — `Features/NavigatorArea`
- Git source control — `Features/SourceControl`
- Integrated terminal (SwiftTerm) — `Features/TerminalEmulator` + `Features/UtilityArea`

### Why not the VSCode extension

The official Claude Code product for VSCode is a VSCode *extension*. Extensions run
only inside VSCode's Electron-based Extension Host (the `vscode` API) and cannot be
loaded into a native AppKit/SwiftUI app. The intelligence, however, lives in the
**`claude` CLI**; the extension is a thin integration layer over it. We therefore
integrate the CLI directly — cleaner and fully native.

## Scope (this milestone)

Integration depth: **dedicated panel + auto context** (chosen over "CLI in the
terminal only" and "deep native IDE protocol").

In scope:
- A "Claude" tab in the right-hand **Inspector** panel.
- A real terminal session running `claude` in the workspace root.
- Toolbar actions: new session, send current file, send current selection.
- Auto context via `@file` mentions and annotated selection blocks injected into the
  running session's stdin.
- Graceful handling when `claude` is not installed.

Out of scope (possible future milestones):
- Deep native IDE protocol (`~/.claude/ide/` lockfile + MCP/WebSocket, native diff
  viewer, bidirectional selection) — the "Niveau 3" option.
- Multiple concurrent Claude sessions / session history persistence.

## Placement

A new case in `InspectorTab` (`Features/InspectorArea/Models/InspectorTab.swift`,
which conforms to `WorkspacePanelTab`). Claude appears as a tab in the existing
right column, next to File and History. This is the least code, 100% native, and
matches the intended "Claude on the right" layout.

## Architecture

Each unit has a single responsibility, a clear interface, and is understandable in
isolation.

| Unit | Responsibility | Reuses / depends on |
|---|---|---|
| `InspectorTab.claude` | New enum case: title "Claude", SF Symbol `sparkles`, body → `ClaudeInspectorView` | `InspectorTab.swift` |
| `ClaudeInspectorView` | SwiftUI container: toolbar + terminal + "not installed" banner | `ClaudeSession` |
| `ClaudeTerminalView` | `NSViewRepresentable` wrapping a SwiftTerm local-process view that runs `claude` | modeled on `TerminalEmulatorView` / `CELocalShellTerminalView` |
| `ClaudeSession` (`ObservableObject`) | Session lifecycle, holds the terminal handle, injects stdin, reads the active editor | `EditorManager.activeEditor` |
| `ClaudeContextBuilder` | **Pure function**: `(fileURL, workspaceURL, selectionText, range) -> String` prompt | none (pure, unit-tested) |

### Data flow

1. **Launch.** `ClaudeSession` spawns `claude` through the user's login shell
   (`/bin/zsh -lc 'claude'`) with `cwd` = workspace root URL. Going through the login
   shell resolves `PATH` — essential because the app is sandboxed; this mirrors how the
   existing terminal already launches the user's shell (`CELocalShellTerminalView.startProcess`).
2. **Send file (toolbar ⧉).** Read `EditorManager.activeEditor.selectedTab?.file.url`,
   compute the path relative to the workspace root, inject `@<relative/path>` into the
   PTY stdin (Claude Code understands `@file` mentions).
3. **Send selection (toolbar ✎).** Read `cursorPositions[0].range` (an `NSRange`) from the
   active `EditorInstance`, extract the selected substring, inject it as an annotated
   fenced code block, e.g. `` From Foo.swift L12–L20: ```...``` ``.
4. **New session (toolbar ⊕).** Terminate the current `claude` process and start a fresh one.

### Key integration points (verified in the codebase)

- Active file + selection: `EditorManager.activeEditor` → `.selectedTab` →
  `EditorInstance.file.url` and `EditorInstance.cursorPositions: [CursorPosition]`,
  where `CursorPosition.range` is an `NSRange` (used already by
  `StatusBarCursorPositionLabel`).
- Terminal spawning: `CELocalShellTerminalView.startProcess(workspaceURL:shell:)`
  (SwiftTerm `LocalProcessTerminalView`). `ClaudeTerminalView` follows the same pattern,
  swapping the launched command for `claude`.
- Right-panel tabs: `InspectorTab: WorkspacePanelTab` enum with `title`,
  `systemImage`, and `body`.

## Error handling

- **`claude` not on PATH** — detected via a `which claude` probe through the login
  shell. If absent, `ClaudeInspectorView` shows a banner ("Claude Code n'est pas
  installé") with the install command instead of starting a session.
- **No file open** — ⧉ and ✎ toolbar actions are disabled.
- **Empty selection** — ✎ falls back to sending the whole file (`@file` mention).

## Testing

- `ClaudeContextBuilder` is a pure function → unit tests in `CodeEditTests`:
  - relative-path computation for files inside the workspace,
  - selection formatting (file name + line range + fenced block),
  - empty selection → file-only output.
- Process spawn + stdin injection → manual verification (not unit-testable cleanly).

## Effort & risks

Roughly 1–2 focused sessions; most work reuses the terminal infrastructure.

Risk areas to validate early:
1. Injecting text into the SwiftTerm PTY stdin of the running `claude` TUI.
2. Exact formatting of `@file` mentions / selection blocks that Claude Code parses well.

## Build prerequisite

Before feature work, verify the fork builds and runs (Xcode 26.5, Swift 6.3.2,
`CodeEdit` scheme). The base must be a working daily driver first.
