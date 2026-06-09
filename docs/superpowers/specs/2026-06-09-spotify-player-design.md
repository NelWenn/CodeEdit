# Spotify Player (replaces the Tasks toolbar) — Design

**Date:** 2026-06-09
**Branch:** `claude-integration`
**Status:** Approved (design), pending implementation plan

## Goal

Replace the Tasks UI in the window toolbar with a **Spotify mini-player** that connects to the
user's real Spotify account (OAuth) and controls playback through the Spotify Web API — now
playing, play/pause, next/previous, seek, like, and volume — keeping the current Liquid Glass
aesthetic.

## Decisions (from brainstorming)

- **Premium account** → full playback control via the Web API.
- **Remove only the Tasks UI from the toolbar** (the activity viewer, run/stop, scheme, task
  notification bell). The underlying task subsystem (`TaskManager`, `CETask`, …) stays in place,
  just no longer surfaced in the toolbar — lower risk than ripping it out.
- **Full player**: now playing (title + artists + album art), play/pause, prev/next, scrubber
  (seek), like (save to library), volume.
- **OAuth**: the user creates the Spotify Developer app (guided). **Client ID:
  `9a0a87a8184e45bfb2b52dc76ded0268`** (public — safe in source under PKCE; no client secret).
- Extended controls (scrubber, volume, like) live in a **popover** to keep the toolbar capsule
  compact; primary transport (prev / play-pause / next) + now-playing are inline.
- The task **notification bell** is removed along with the rest of the Tasks toolbar UI.

## Architecture

A shared **`SpotifyPlayerModel`** (`@MainActor`, `ObservableObject`, singleton) owns auth + playback
state — music is global, not per-workspace. Each window's toolbar hosts a **`SpotifyPlayerView`**
(SwiftUI, via `NSHostingView`) observing that model.

Rejected alternatives: the Web Playback SDK (browser-only JS, unfit for native); controlling the
Spotify.app via AppleScript/ScriptingBridge (not "the real API").

## OAuth — Authorization Code + PKCE (no client secret)

1. **Login**: `ASWebAuthenticationSession` opens Spotify's authorize URL; the user signs in; Spotify
   redirects to `codeedit://spotify-callback` (the `codeedit` scheme is already registered in
   `Info.plist`). PKCE: a random `code_verifier` + S256 `code_challenge`.
2. **Scopes**: `user-read-playback-state`, `user-modify-playback-state`,
   `user-read-currently-playing`, `user-library-read`, `user-library-modify`.
3. **Token exchange**: `POST https://accounts.spotify.com/api/token` (grant `authorization_code`
   + `code_verifier`) → `access_token` + `refresh_token` + `expires_in`. **Stored in the Keychain**
   via `CodeEditKeychain`. Refreshed automatically when expired (grant `refresh_token`).
4. **Contingency**: if the Spotify dashboard rejects the custom scheme, fall back to a loopback
   redirect `http://127.0.0.1:<port>/spotify-callback` served by a minimal local `NWListener`. The
   plan implements whichever the dashboard accepts; design favours the custom scheme.

## Components

1. **`SpotifyConfiguration`** — `clientID`, `redirectURI` (`codeedit://spotify-callback`), `scopes`,
   API base URLs. A plain constants struct.
2. **`SpotifyAuthService`** — PKCE generation, `ASWebAuthenticationSession` flow, token
   exchange/refresh, Keychain persistence, current-token accessor (refreshing if near expiry).
   *Pure, testable parts: PKCE verifier/challenge (S256), token-response decoding, expiry math.*
3. **`SpotifyAPIClient`** — typed Web API calls, injecting the bearer token and handling
   `401 → refresh → retry once` and `404 No active device`:
   - `GET /v1/me/player` → playback state (track, `is_playing`, `progress_ms`, `item.duration_ms`,
     device, `volume_percent`).
   - `PUT /v1/me/player/play`, `PUT /v1/me/player/pause`, `POST /v1/me/player/next`,
     `POST /v1/me/player/previous`.
   - `PUT /v1/me/player/seek?position_ms=`, `PUT /v1/me/player/volume?volume_percent=`.
   - Like: `GET /v1/me/tracks/contains?ids=`, `PUT /v1/me/tracks?ids=`, `DELETE /v1/me/tracks?ids=`.
   - `GET /v1/me/player/devices` + `PUT /v1/me/player` (transfer) for the no-active-device case.
   *Pure, testable parts: request building (URL/method/body) and response decoding.*
4. **`SpotifyPlayerModel`** (shared) — `@Published`: `isAuthorized`, `track` (title, artists,
   `albumArtURL`, `trackID`), `isPlaying`, `progressMs`, `durationMs`, `volume`, `isLiked`,
   `hasActiveDevice`, `errorMessage`. Methods: `authorize()`, `logout()`, `togglePlayPause()`,
   `next()`, `previous()`, `seek(toMs:)`, `setVolume(_:)`, `toggleLike()`, `transferToDevice(_:)`.
   A **poll timer** hits `/me/player` (~1 s while the player is visible) for live updates; a local
   tick advances `progressMs` between polls for a smooth scrubber.
5. **`SpotifyPlayerView`** (toolbar) — Liquid Glass capsule (consistent with the current style):
   album-art thumbnail + scrolling title/artist + `prev / play-pause / next`. A click opens a
   **popover** with the scrubber, volume slider, and like toggle. Signed-out state = a **"Connect
   Spotify"** button. No-active-device state = a hint + device picker.

## Toolbar change (remove Tasks)

In `CodeEditWindowController+Toolbar.swift`: drop `.activityViewer`, `.startTaskSidebarItem`,
`.stopTaskSidebarItem`, `.taskSidebarItem`, and `.notificationItem` from the default/allowed/
centered identifiers, and add **`.spotifyPlayer`** as the centered item, whose
`NSToolbarItem.view` is an `NSHostingView(rootView: SpotifyPlayerView())`. The task code
(`TaskManager`, `ActivityViewer`, etc.) remains in the project, simply unreferenced by the toolbar.

## Error handling

- **Not authorized** → "Connect Spotify" button; `authorize()` runs the OAuth flow.
- **No active device** (404) → show "Open Spotify or pick a device"; offer a device picker
  (`/me/player/devices` + transfer). Controls are disabled until a device is active.
- **Token expired / 401** → refresh once and retry; if refresh fails → mark unauthorized
  (re-login).
- **Network errors** → keep the last known state, surface a subtle error, retry on next poll.
- **Nothing playing** → idle state ("Not playing") with the Connect/now-playing area empty.

## Testing

Pure logic is unit-tested (`@testable import CodeEdit`, XCTest, identifiers ≥3 chars):
- PKCE: `code_verifier` charset/length; `code_challenge` = base64url(SHA256(verifier)) for a known
  vector.
- Token response decoding (access/refresh/expires) and expiry/`shouldRefresh` logic.
- `/me/player` JSON decoding → the player state (track, isPlaying, progress, duration, volume,
  device).
- `SpotifyAPIClient` request building: correct URL, method, query, and JSON body for play/pause/
  next/previous/seek/volume/like.
- The auth-callback URL parser (extract `code`/`state`, reject mismatched `state`).

OAuth + live API + the toolbar/popover UI → manual verification.

## User setup (Spotify Developer app)

At <https://developer.spotify.com/dashboard>: create an app; copy the **Client ID** (already
provided); under settings add the **Redirect URI** `codeedit://spotify-callback` (if custom schemes
are rejected, add `http://127.0.0.1:8888/spotify-callback` and we use the loopback fallback); save.
No client secret is needed (PKCE).

## Out of scope (YAGNI)

Browsing/searching the catalog, playlists/queue management, lyrics, multi-account, the Web Playback
SDK (in-app audio output). The player controls the user's existing Spotify Connect device(s).
