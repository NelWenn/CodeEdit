# Claude Sessions & Tabs — Design

**Date:** 2026-06-09
**Branch:** `claude-integration`
**Status:** Approved (design), pending implementation plan

## Goal

Let the user run **multiple concurrent Claude sessions** in Agent mode, each in its own
tab, and **browse/resume the project's past Claude sessions** from a new "Sessions" tab in
the right inspector — opening a chosen session either in the current tab (default) or a new
tab.

## Background / current state

- Agent mode currently hosts **one** `ClaudeSession` (`WorkspaceDocument.claudeSession`),
  rendered by `ClaudeAgentView`, keyed on `claudeSession.generation`.
- The right inspector, in agent mode, shows only `ClaudeInfoInspectorView`
  (account / plan / usage / model / effort), bound to that single session.
- Claude Code already persists every session as
  `~/.claude/projects/<encoded-cwd>/<sessionId>.jsonl` (the cwd path with `/` replaced by
  `-`). The smaacks-app project already has 126 such files. We **leverage** this storage
  rather than inventing our own.

Verified CLI mechanics (claude 2.1.169):
- `claude --session-id <uuid>` — start a session with a known UUID (works interactively).
- `claude --resume <id>` / `-r <id>` — resume a specific session.
- `claude --model <m>` / `--effort <e>` — already used by the existing restart path.
- `-n, --name <name>` — display name (prompt box, /resume picker, terminal title). Optional.

## Architecture

A **`ClaudeSessionManager`** owns an ordered array of open tabs `[ClaudeSession]` plus the
active tab id. It replaces the single `WorkspaceDocument.claudeSession`.

Each **tab = one `ClaudeSession` = one terminal** hosting `claude` with a specific claude
session UUID. The underlying `LocalProcess` runs independently of view attachment, so a
non-visible tab keeps running; switching tabs is instant and no conversation dies.

Alternatives considered and rejected:
- **Reuse the editor's `EditorManager`/tab system** — heavy and file-oriented; would
  entangle file tabs with Claude tabs. The user chose a dedicated Agent tab strip.
- **Single session with a session switcher (no concurrent terminals)** — no real
  concurrent tabs; switching would tear down/relaunch the process each time.

## Components

Each unit below has one responsibility and a clear interface so it can be understood and
(where pure) tested in isolation.

### 1. `ClaudeSession` (modify) — `Features/Agent/ClaudeSession.swift`

Owns one long-lived `claude` terminal for one tab.

New/changed surface:
- `let id: UUID` — stable tab identity (for SwiftUI `id()` and manager lookup).
- `private(set) var claudeSessionId: String` — the claude session UUID this tab runs.
  - New tab: generated up front (`UUID().uuidString.lowercased()`), launched with
    `--session-id`.
  - Resumed tab: set to the resumed id, launched with `--resume`.
- `@Published private(set) var title: String` — tab label. Defaults to `"New Session"` for
  fresh tabs; set from `ClaudeSessionInfo.title` when resuming.
- Launch command building (pure, extracted so it is unit-testable):
  - Fresh: `claude --session-id <uuid> [--model M] [--effort E | --settings '{"ultracode":true}']`
  - Resume: `claude --resume <id> [--model M] [--effort E | …]`
  - Reuses the existing effort/ultracode handling already in `launchClaudeIfNeeded`.
- Keeps the existing `generation` bump + `makeOrReuseTerminal` + `restart(...)` mechanics.
  `restart` is generalized to relaunch either fresh or resuming, depending on the tab.

### 2. `ClaudeSessionManager` (new) — `Features/Agent/ClaudeSessionManager.swift`

`ObservableObject` owned by `WorkspaceDocument` (replaces `claudeSession`).

State:
- `@Published private(set) var tabs: [ClaudeSession]`
- `@Published var activeTabID: UUID?`
- `var activeSession: ClaudeSession?` (computed from `activeTabID`)

Behavior:
- `newTab(resuming claudeId: String? = nil, title: String? = nil)` — append a session
  (fresh or resuming), make it active.
- `closeTab(_ id: UUID)` — terminate that session's process, remove it. If it was active,
  activate a neighbor. **If it was the last tab, open a fresh one** (Agent mode always has
  ≥1 tab).
- `activate(_ id: UUID)`.
- `open(claudeId: String, title: String, mode: OpenMode)` where
  `enum OpenMode { case currentTab, newTab }`:
  - If a tab already runs `claudeId` → just `activate` it (never two processes on one
    `.jsonl`).
  - `.currentTab` → active session `restart(resuming: claudeId)`, set its title.
  - `.newTab` → `newTab(resuming: claudeId, title:)`.
- Terminal creation is injected via a closure/factory so the state machine is testable
  without real terminals.

Persistence (workspace state, new keys):
- On any change to `tabs`/`activeTabID`, save `[claudeSessionId]` (open tabs, in order) +
  active index.
- On first entry to Agent mode / load, restore: recreate one resuming tab per saved id; if
  none, one fresh tab.

### 3. `ClaudeSessionsReader` (new, pure) — `Features/Agent/Sessions/ClaudeSessionsReader.swift`

Reads the project's claude session files. No UI, no terminals — unit-testable.

- `static func encodedProjectDir(for cwd: URL) -> String` — `cwd.path` with `/` → `-`
  (matching claude's scheme).
- `static func sessionsDirectory(for cwd: URL) -> URL` —
  `~/.claude/projects/<encoded>/`.
- `static func readSessions(for cwd: URL) -> [ClaudeSessionInfo]` — enumerate `*.jsonl`,
  parse each into a `ClaudeSessionInfo`, sort by `lastModified` descending. Malformed files
  are skipped, not fatal.
- `ClaudeSessionInfo`: `{ id: String; title: String; lastModified: Date }`.
- Title derivation (first match wins):
  1. a line with `"type":"summary"` → its `summary` field;
  2. else the first user message's text (trimmed, truncated ~60 chars);
  3. else a date-based fallback (e.g. `"Session — Jun 9, 15:20"`).
- Reading large `.jsonl` files: scan only what's needed for the title (read line-by-line,
  stop once a title is found) to avoid loading multi-MB files fully.

### 4. `ClaudeTabBar` (new) — `Features/Agent/ClaudeTabBar.swift`

Native tab strip at the top of the Agent area, shown only in Agent mode.
- One pill per tab: `title` + a close (×) button (× on hover / when active).
- Active tab highlighted; click activates. A trailing `+` button calls `newTab()`.
- Bound to `ClaudeSessionManager` (`tabs`, `activeTabID`).

### 5. `WorkspaceView` (modify) — agent case

In `case .agent`, render a `VStack`:
- `ClaudeTabBar(manager:)`
- `ClaudeAgentView(session: manager.activeSession, …)` keyed on
  `activeSession.id` + `activeSession.generation`.

### 6. Agent inspector tabs (modify) — `InspectorAreaView` + new container

In agent mode the inspector becomes a 2-tab panel with a small native tab switcher at the
top:
- **Info** — the existing `ClaudeInfoInspectorView`, bound to the manager's **active**
  session (rebinds when the active tab changes).
- **Sessions** — `ClaudeSessionsListView` (below).

`ClaudeInfoModel.start(session:)` is re-pointed at the active session on tab switch.

### 7. `ClaudeSessionsListView` (new) — `Features/Agent/Sessions/ClaudeSessionsListView.swift`

- Loads `ClaudeSessionsReader.readSessions(for: workspaceURL)` (refresh on appear + a
  manual refresh affordance).
- Scrollable list with a search field filtering by title.
- Each row: title + relative date (e.g. "2h ago"); a subtle indicator if that session is
  already open in a tab.
- **Click = open in current tab** (default). A context menu / secondary button offers
  **"Open in New Tab"**.
- A "New Session" affordance at the top maps to `manager.newTab()`.

## Data flow

- **New tab:** `ClaudeTabBar +` → `manager.newTab()` → `ClaudeSession` with fresh UUID →
  `claude --session-id <uuid>`. Title "New Session".
- **Open from list (current):** row click → `manager.open(claudeId, title, .currentTab)` →
  active session `restart(resuming:)` → `claude --resume <id>`; title ← list title.
- **Open from list (new tab):** → `manager.open(claudeId, title, .newTab)` →
  `newTab(resuming:)`.
- **Already-open session selected:** `manager.open` finds the existing tab → `activate` it.
- **Switch tab:** `manager.activeTabID = id` → `WorkspaceView` shows that session's view;
  inspector Info rebinds.
- **Close tab:** `manager.closeTab(id)` → process terminated; session stays on disk
  (re-openable from the list).
- **Persistence:** changes → save open ids + active index to workspace state; load →
  recreate resuming tabs.

## Error handling

- **Resuming a vanished/locked id:** `claude --resume` prints its own error in the terminal;
  the tab stays usable (user can start fresh). We do not pre-validate.
- **Malformed `.jsonl`:** skipped by the reader; never crashes the list.
- **No sessions dir / empty:** Sessions list shows an empty state ("No sessions yet").
- **Two processes on one session:** prevented — `open` activates an already-open tab instead
  of launching a second process on the same id; new tabs always use fresh UUIDs.

## Testing strategy

Pure logic is unit-tested (`@testable import CodeEdit`, ≥3-char identifiers per SwiftLint);
terminal/SwiftUI behavior is verified manually.

- `ClaudeSessionsReader`:
  - `encodedProjectDir` maps `/a/b c` → `-a-b c` correctly.
  - `readSessions` over a temp dir with sample `.jsonl` files: correct count, descending
    sort, malformed file skipped.
  - Title derivation: summary line wins; else first user message truncated; else date
    fallback.
- `ClaudeSession` command building: fresh vs resume vs effort/ultracode variants produce the
  exact expected command string.
- `ClaudeSessionManager` state machine (terminal factory stubbed): newTab/closeTab/activate;
  closing the last tab opens a fresh one; `open` on an already-open id activates rather than
  duplicates; persistence encode→decode round-trips open ids + active index.
- **Manual:** tab strip add/close/switch; concurrent sessions keep running; open-from-list
  in current vs new tab; relaunch restores tabs; inspector Info follows the active tab.

## Out of scope (YAGNI)

- Forking sessions (`--fork-session`), renaming via `-n`, drag-to-reorder tabs, splitting
  terminals, cross-workspace session browsing. Can come later.
