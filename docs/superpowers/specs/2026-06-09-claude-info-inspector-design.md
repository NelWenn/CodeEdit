# Claude Info Inspector — Design

**Date:** 2026-06-09
**Status:** Approved (pending written-spec review)
**Base:** CodeEditAi (fork of CodeEdit). Builds on the Editor/Agent mode (Lot A).

## Build constraint

Build with **Xcode 27 beta (Swift 6.4)** via `DEVELOPER_DIR=/Users/theoschneider/Downloads/Xcode-beta.app/Contents/Developer` (macOS 27 beta; `xcode-select` points to stable 26.5 which masks 6.4 errors). The app is non-sandboxed (required to read `~/.claude`, the Keychain, and run `claude`).

## Goal

When the workspace is in **Agent** mode, the right-hand **Inspector** becomes a Claude information & control panel showing, and letting the user control, the live state of Claude Code:

- **Account**: email / display name.
- **Subscription**: plan tier (e.g. "Max 20x").
- **Live usage** (3 meters with reset countdowns): Session (5h), Weekly (7d, all models), Weekly Sonnet.
- **Model & effort**: the current model and effort, plus pickers to change them (and "thinking").

In **Editor** mode the Inspector shows its normal tabs (File / History), unchanged.

## Confirmed data sources (from feasibility research)

- **Account / plan**: `~/.claude.json` → `oauthAccount` (`emailAddress`, `displayName`, `organizationRateLimitTier` e.g. `default_claude_max_20x`, `userRateLimitTier`, `billingType`, `hasExtraUsageEnabled`).
- **Model / effort**: `~/.claude/settings.json` (`model`, `effortLevel`). Readable and writable.
- **Live usage**: two mechanisms (user chose **both**):
  - **Statusline (primary, in-session):** Claude Code ≥2.1.x pipes `rate_limits.five_hour` and `rate_limits.seven_day` on the statusLine command's stdin for Pro/Max accounts. We install a small statusLine script that writes that JSON to `~/.claude/codeeditai-usage.json`; CodeEditAi watches the file.
  - **Endpoint (fallback, out of session):** the undocumented `GET https://api.anthropic.com/api/oauth/usage` using the OAuth token (macOS Keychain item, service `Claude Code-credentials`). Returns session/weekly/Sonnet utilization + ISO reset timestamps.
- **Token**: macOS Keychain, service `Claude Code-credentials`, account `theoschneider` (no `~/.claude/.credentials.json` on this machine).

> The exact JSON field names of the statusline `rate_limits` payload and of the
> `/api/oauth/usage` response are community-derived and undocumented. **Implementation
> Task 1 captures the real shapes** (from the user's running `claude`) and the parsers
> are written against the captured shapes — no guessing.

## Architecture

The Inspector is SwiftUI (`InspectorAreaView` → `WorkspacePanelView`). The workspace mode lives on `WorkspaceDocument.workspaceMode` (from Lot A).

### UX integration

`InspectorAreaView` observes `workspace.workspaceMode`:
```
if workspace.workspaceMode == .agent { ClaudeInfoInspectorView(model: claudeInfoModel) }
else { WorkspacePanelView(...) }   // existing tabs
```
`claudeInfoModel` is a workspace-scoped `@StateObject` (created once, started/stopped with agent mode).

### Units (each one responsibility, in `CodeEdit/Features/Agent/Info/`)

| Unit | Responsibility |
|---|---|
| `ClaudeAccount` (struct) | Parsed account: email, displayName, planTier, planDisplayName, hasExtraUsage |
| `ClaudeAccountReader` | Reads & decodes `~/.claude.json` `oauthAccount` → `ClaudeAccount`; maps tier → display name |
| `ClaudeModelConfig` (struct) + `ClaudeSettingsStore` | Reads/writes `model` + `effortLevel` in `~/.claude/settings.json` (preserving other keys) |
| `ClaudeUsage` (struct) | `session`, `weekly`, `weeklySonnet`: each `{ usedPercent: Double, resetsAt: Date }` |
| `ClaudeUsageReader` | Loads usage: prefers `~/.claude/codeeditai-usage.json` (fresh), else endpoint fallback |
| `ClaudeUsageStatuslineInstaller` | Ensures the statusLine script + settings entry are installed (idempotent, non-clobbering) |
| `ClaudeUsageEndpointClient` | Reads Keychain token, calls `/api/oauth/usage`, decodes response → `ClaudeUsage` |
| `ClaudeInfoModel` (`ObservableObject`) | Aggregates account + config + usage; FSEvents-watches the usage file; refresh timer for reset countdowns; exposes published values + actions |
| `ClaudeInfoInspectorView` | The panel: account header, plan badge, 3 `UsageMeter`s, model/effort/thinking controls |
| `UsageMeter` (View) | One labeled progress bar + "Resets in …" countdown |
| `ModelEffortPicker` (View) | Model menu, effort menu, thinking toggle; calls model actions |

### Data flow

1. **Account/plan**: `ClaudeAccountReader` reads `~/.claude.json` once on panel appear (+ on FSEvents change). Tier→name map: `default_claude_max_20x`→"Max 20x", `default_claude_max_5x`→"Max 5x", `default_claude_pro`/pro→"Pro", else humanize the raw tier; prefer `userRateLimitTier` then `organizationRateLimitTier`.
2. **Usage (primary)**: `ClaudeUsageStatuslineInstaller` installs the statusLine on first agent launch. While `claude` runs in the Agent terminal, its statusLine subprocess writes `~/.claude/codeeditai-usage.json`. `ClaudeInfoModel` FSEvents-watches it and decodes via `ClaudeUsageReader`.
3. **Usage (fallback)**: if the file is missing or older than a threshold (e.g. >2 min) and no session is active, `ClaudeUsageEndpointClient` fetches from the endpoint. Manual "refresh" button also triggers it.
4. **Countdowns**: a 1s timer recomputes "Resets in …" from `resetsAt`.
5. **Model/effort/thinking (control)**: pickers write `~/.claude/settings.json` via `ClaudeSettingsStore`, AND apply to the live session — preferred: inject the slash command into the Agent terminal stdin (e.g. `/model <id>`); for changes the TUI can't apply live, offer "Restart Agent session" (relaunch `claude` with `--model`/`--effort`). The exact live-apply commands are confirmed in Task 1.

### Statusline installation (non-intrusive)

- If `~/.claude/settings.json` has **no** `statusLine`, install ours (a script at `~/.claude/codeeditai-statusline.sh` that reads stdin, writes `rate_limits` to `codeeditai-usage.json`, and echoes a minimal status line). Record that CodeEditAi installed it.
- If a `statusLine` **already exists**, do **not** clobber it; rely on the endpoint fallback and surface a one-line note in the panel offering to install.

## Error handling

- `~/.claude.json` / `settings.json` missing or unreadable → panel shows "Claude Code not configured" with guidance; controls disabled.
- No usage yet (no session has run, endpoint unavailable) → meters show "—" with a "Refresh" action; never crash.
- Keychain read denied by the user → fallback disabled, note shown; statusline path still works.
- Endpoint failure / unexpected shape → keep last known values, show a subtle stale indicator.
- `claude` not installed → reuse Agent-mode handling.

## Testing

- Pure parsers are unit-tested in `CodeEditTests` against **captured real fixtures** (Task 1 output): `ClaudeAccountReader` (tier→name, missing fields), `ClaudeUsageReader`/decoders (statusline shape + endpoint shape), `ClaudeSettingsStore` (round-trip write preserves unrelated keys).
- Tier→display-name mapping table: unit-tested.
- FSEvents/Keychain/endpoint/terminal-injection: manual verification in Xcode 27 beta with a live `claude`.

## Scope

In scope (one milestone, "all in one"): everything above — display (account, plan, 3 usage meters) **and** controls (model/effort/thinking) with both usage mechanisms.

Out of scope: historical usage graphs; cost breakdown; multiple accounts; editing usage limits.
