# Discord Rich Presence — Design

**Date:** 2026-06-09
**Branch:** `claude-integration`
**Status:** Approved (design), pending implementation plan

## Goal

Show CodeEditAi on the user's Discord profile ("Playing CodeEditAi") with the app logo, the
project folder they're working in, the git branch, an editing/idle status, and elapsed time —
like the VS Code Discord presence extension.

## Decisions (from brainstorming)

- **Discord application** created by the user (guided). **Client ID:** `1513992493396525148`
  (a public application identifier — safe in source). The user uploads a Rich Presence art asset
  named **`logo`** for the large image.
- **Privacy: folder-only (hardcoded).** Never show file names. Show the project folder + git
  branch + editing/idle. No privacy menu — just an enable/disable toggle.
- **Extras:** elapsed time (since the workspace opened), git branch, idle/editing distinction.
  No small image.
- **Enabled by default**, with a Settings toggle to turn it off.

## Architecture

A shared **`DiscordPresenceManager`** (`@MainActor`, singleton) observes the frontmost
`WorkspaceDocument` (folder name, git branch, editing-vs-idle, open time), builds an activity, and
pushes it through a low-level **`DiscordRPCClient`** over Discord's local IPC socket. Started at app
launch (when enabled), stopped on quit/disable.

Rejected alternatives: a third-party Discord SDK (heavy, unnecessary); driving an external helper
process (not native).

## Discord IPC

Discord exposes a Unix domain socket at `<base>/discord-ipc-{0..9}` where `<base>` is each of
`$XDG_RUNTIME_DIR`, `$TMPDIR`, `$TMP`, `$TMP_DIR`, and `/tmp` (in that order, de-duplicated). On
macOS, Discord's socket lives under `$TMPDIR`. The wire protocol frames messages as:

```
[ op: UInt32 little-endian ] [ length: UInt32 little-endian ] [ JSON payload of `length` bytes ]
```

Ops: `0` = handshake, `1` = frame (commands/events), `2` = close, `3` = ping, `4` = pong.

1. **Handshake:** op `0`, payload `{ "v": 1, "client_id": "<id>" }`. Discord replies with a `READY`
   event (op `1`).
2. **Set activity:** op `1`, payload
   `{ "cmd": "SET_ACTIVITY", "nonce": "<uuid>", "args": { "pid": <pid>, "activity": { … } } }`.
3. **Clear activity:** the same with `"activity": null`.

The app is non-sandboxed, so it can reach Discord's socket in `$TMPDIR`.

## Components

1. **`DiscordRPCFrame`** (pure, testable) — encodes `(op: UInt32, json: Data) -> Data` (LE header +
   payload) and decodes a received header. No networking.
2. **`DiscordSocketLocator`** (pure, testable) — returns the ordered list of candidate socket paths
   (`<base>/discord-ipc-0` … `-9` across the env-var bases). No filesystem dependency beyond reading
   env vars (injectable for tests).
3. **`DiscordRPCClient`** — opens a POSIX `AF_UNIX` socket to the first connectable candidate, does
   the handshake, exposes `setActivity(_ activity: DiscordActivity?)` and `close()`. A background
   read loop keeps the connection alive / detects disconnect. Reconnect is driven by the manager.
4. **`DiscordActivity`** (`Encodable`) — `details: String?`, `state: String?`,
   `timestamps: { start: Int }?`, `assets: { largeImage: String?, largeText: String? }?` (snake_case
   via CodingKeys to match the Discord API).
5. **`DiscordPresenceBuilder`** (pure, testable) — `build(context:) -> DiscordActivity` from
   `PresenceContext { folder: String?, branch: String?, isEditing: Bool, startedAt: Int }`:
   - Workspace open: `details = folder`; `state = (isEditing ? "Editing" : "Idle") + (branch.map { " · \($0)" } ?? "")`.
   - No workspace: `details = "CodeEditAi"`, `state = "Idle"`.
   - Always `assets.largeImage = "logo"`, `largeText = "CodeEditAi"`, `timestamps.start = startedAt`.
   - Never includes a file name.
6. **`DiscordPresenceManager`** (shared) — tracks the active `WorkspaceDocument` (its `displayName`,
   `sourceControlManager` current branch, `editorManager.activeEditor.selectedTab != nil` for
   editing/idle, and the workspace open time). Debounces changes (~2s), rebuilds the activity, and
   calls the client. Reads `Settings[\.discord].enabled`; starts/stops accordingly. Retries
   connection (~15s) while Discord isn't running.
7. **Settings** — a new `discord` group in `SettingsData` with a single `enabled: Bool = true`, and a
   small Settings page (a toggle + a one-line explanation). Mirrors an existing simple settings page.

## Data flow

App launch → if `enabled`, the manager starts and attempts to connect. On connect, it sends the
current activity. On workspace/file/branch change (debounced), it rebuilds + `SET_ACTIVITY`. Toggling
the setting off clears the activity and disconnects; on clears the activity is re-sent.

The "active workspace" is the most-recently-key `WorkspaceDocument`. The manager updates when the key
window changes.

## Error handling

- **Discord not running** → connect fails on all candidates → retry every ~15s; nothing is shown
  (silent, no error UI).
- **Socket closes** (Discord quits) → the read loop detects EOF → mark disconnected, retry.
- **Malformed/unknown frames** → ignored; we only need the connection to stay open.
- **No git repo / no branch** → omit the branch segment.
- **Setting disabled** → no socket is opened at all (privacy-respecting).

## Testing

Pure logic is unit-tested (`@testable import CodeEdit`, XCTest, identifiers ≥3 chars):
- `DiscordRPCFrame`: encoding writes the correct little-endian op + length + payload; round-trips a
  known op/JSON; header decode reads op/length.
- `DiscordSocketLocator`: given injected env vars, returns the expected ordered `discord-ipc-0..9`
  candidate paths across bases, de-duplicated.
- `DiscordPresenceBuilder`: folder-only output for editing vs idle, with/without branch, and the
  no-workspace fallback; asserts no file name ever appears; correct assets/timestamps.
- `DiscordActivity` JSON encoding uses the snake_case keys Discord expects
  (`large_image`, `large_text`, `start`).

The live IPC connection, the manager's window/branch observation, and the actual Discord profile
display are verified manually.

## User setup (Discord application)

At <https://discord.com/developers/applications>: New Application → name it "CodeEditAi" → copy the
**Application ID** (already provided). Open **Rich Presence → Art Assets** → upload the app logo as an
asset named **`logo`** (square PNG). No bot, no OAuth, no secret needed for local IPC presence.

## Out of scope (YAGNI)

File names / line numbers, a "spectate/join" party, buttons/links on the presence, multiple
applications, a privacy-level menu (folder-only is fixed), showing the file-type small image.
