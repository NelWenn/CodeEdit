# Spotify Player Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Tasks UI in the window toolbar with a Liquid-Glass Spotify mini-player that signs into the user's Spotify account (OAuth PKCE) and controls playback via the Spotify Web API (now playing, play/pause, prev/next, seek, like, volume).

**Architecture:** A shared `SpotifyPlayerModel` (`@MainActor ObservableObject`) owns auth + playback state. `SpotifyAuthService` does OAuth (ASWebAuthenticationSession + PKCE) and Keychain token storage; `SpotifyAPIClient` calls the Web API. `SpotifyPlayerView` (in the toolbar, via `NSHostingView`) observes the model. Pure helpers (PKCE, token model, callback parsing, request building, playback-state decoding) are unit-tested; OAuth/network/UI are verified manually.

**Tech Stack:** Swift 6.4, SwiftUI + AppKit, `AuthenticationServices` (ASWebAuthenticationSession), `CryptoKit` (PKCE S256), `CodeEditKeychain`, Spotify Web API, XCTest.

---

## Build & Test Commands

Always set `DEVELOPER_DIR` (Xcode 27 beta / Swift 6.4); read the verdict from the log.

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

**Conventions:** new `.swift` files auto-join their target (synchronized groups — no `.pbxproj` edits). SwiftLint identifiers ≥3 chars. Module `CodeEdit`; tests `@testable import CodeEdit` in `CodeEditTests`. `@ViewBuilder` on the same line as a `var`, own line for a `func`.

## File Structure

**Create (all under `CodeEdit/Features/Spotify/`):**
- `SpotifyConfiguration.swift` — client id, redirect URI, scopes, endpoints.
- `SpotifyPKCE.swift` — PKCE verifier/challenge (+ base64url Data helper).
- `SpotifyTokens.swift` — token model, token-response decoding, expiry.
- `SpotifyAuthCallback.swift` — parse `code`/`state` from the redirect URL.
- `SpotifyPlaybackState.swift` — decode `/me/player` JSON into a value type.
- `SpotifyRequest.swift` — pure `URLRequest` builders for every endpoint.
- `SpotifyAPIClient.swift` — sends requests, refreshes on 401, decodes responses.
- `SpotifyAuthService.swift` — ASWebAuthenticationSession + token exchange/refresh + Keychain.
- `SpotifyPlayerModel.swift` — shared model: state, poll timer, command methods.
- `Views/SpotifyPlayerView.swift` — toolbar capsule (now playing + transport).
- `Views/SpotifyPlayerPopover.swift` — scrubber + volume + like.

**Modify:**
- `CodeEdit/Features/Documents/Controllers/CodeEditWindowControllerExtensions.swift` — add `.spotifyPlayer` identifier.
- `CodeEdit/Features/Documents/Controllers/CodeEditWindowController+Toolbar.swift` — replace task/activity items with `.spotifyPlayer`.

**Tests (under `CodeEditTests/Features/Spotify/`):** one suite per pure helper.

---

## Task 1: `SpotifyConfiguration` + `SpotifyPKCE`

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyConfiguration.swift`, `CodeEdit/Features/Spotify/SpotifyPKCE.swift`
- Test: `CodeEditTests/Features/Spotify/SpotifyPKCETests.swift`

- [ ] **Step 1: Write the failing test** — `CodeEditTests/Features/Spotify/SpotifyPKCETests.swift`:

```swift
@testable import CodeEdit
import XCTest

final class SpotifyPKCETests: XCTestCase {
    // RFC 7636 Appendix B test vector.
    func testChallengeMatchesRFCVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        XCTAssertEqual(SpotifyPKCE.challenge(for: verifier), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testVerifierIsUrlSafeAndLongEnough() {
        let verifier = SpotifyPKCE.makeVerifier()
        XCTAssertGreaterThanOrEqual(verifier.count, 43)
        XCTAssertLessThanOrEqual(verifier.count, 128)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        XCTAssertTrue(verifier.unicodeScalars.allSatisfy { allowed.contains($0) })
    }
}
```

- [ ] **Step 2: Run it, verify it fails** (`-only-testing:CodeEditTests/SpotifyPKCETests`) — "cannot find 'SpotifyPKCE'".

- [ ] **Step 3: Implement** — `CodeEdit/Features/Spotify/SpotifyConfiguration.swift`:

```swift
//
//  SpotifyConfiguration.swift
//  CodeEdit
//

import Foundation

/// Static Spotify app configuration. The client id is a PUBLIC identifier (PKCE flow, no secret),
/// so it is safe to keep in source.
enum SpotifyConfiguration {
    static let clientID = "9a0a87a8184e45bfb2b52dc76ded0268"
    /// Must be registered verbatim in the Spotify app dashboard.
    static let redirectURI = "codeedit://spotify-callback"
    /// The custom scheme ASWebAuthenticationSession listens on (the part before `://`).
    static let callbackScheme = "codeedit"
    static let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        "user-library-read",
        "user-library-modify"
    ]
    static let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    static let apiBaseURL = URL(string: "https://api.spotify.com/v1")!
    /// Keychain key for the persisted tokens JSON.
    static let keychainKey = "spotify-tokens"
}
```

`CodeEdit/Features/Spotify/SpotifyPKCE.swift`:

```swift
//
//  SpotifyPKCE.swift
//  CodeEdit
//

import Foundation
import CryptoKit

/// PKCE (RFC 7636) helpers for the Spotify Authorization Code flow.
enum SpotifyPKCE {
    private static let unreserved = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// A high-entropy `code_verifier` (64 unreserved characters).
    static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { unreserved[Int($0) % unreserved.count] })
    }

    /// `code_challenge` = base64url( SHA256(verifier) ), no padding.
    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

extension Data {
    /// Base64url without padding (RFC 4648 §5).
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
```

- [ ] **Step 4: Run it, verify it passes** (both tests).

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyConfiguration.swift \
        CodeEdit/Features/Spotify/SpotifyPKCE.swift \
        CodeEditTests/Features/Spotify/SpotifyPKCETests.swift
git commit -m "feat(spotify): configuration + PKCE helpers"
```

---

## Task 2: `SpotifyTokens` (decode + expiry)

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyTokens.swift`
- Test: `CodeEditTests/Features/Spotify/SpotifyTokensTests.swift`

- [ ] **Step 1: Write the failing test:**

```swift
@testable import CodeEdit
import XCTest

final class SpotifyTokensTests: XCTestCase {
    func testDecodesTokenResponseAndComputesExpiry() throws {
        let json = #"{"access_token":"AT","refresh_token":"RT","expires_in":3600,"token_type":"Bearer"}"#
        let now = Date(timeIntervalSince1970: 1_000_000)
        let tokens = try SpotifyTokens(responseData: Data(json.utf8), refreshFallback: nil, now: now)
        XCTAssertEqual(tokens.accessToken, "AT")
        XCTAssertEqual(tokens.refreshToken, "RT")
        XCTAssertEqual(tokens.expiresAt, now.addingTimeInterval(3600))
    }

    func testRefreshFallbackKeepsRefreshTokenWhenResponseOmitsIt() throws {
        // Spotify's refresh response can omit refresh_token; we must keep the old one.
        let json = #"{"access_token":"AT2","expires_in":3600,"token_type":"Bearer"}"#
        let tokens = try SpotifyTokens(responseData: Data(json.utf8), refreshFallback: "RT", now: Date())
        XCTAssertEqual(tokens.refreshToken, "RT")
    }

    func testShouldRefreshWithinSkew() {
        let now = Date()
        let tokens = SpotifyTokens(accessToken: "AT", refreshToken: "RT", expiresAt: now.addingTimeInterval(120))
        XCTAssertFalse(tokens.shouldRefresh(now: now))                 // 120s left
        XCTAssertTrue(tokens.shouldRefresh(now: now.addingTimeInterval(80)))  // 40s left < 60s skew
    }
}
```

- [ ] **Step 2: Run it, verify it fails.**

- [ ] **Step 3: Implement** — `CodeEdit/Features/Spotify/SpotifyTokens.swift`:

```swift
//
//  SpotifyTokens.swift
//  CodeEdit
//

import Foundation

/// Persisted Spotify OAuth tokens.
struct SpotifyTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    private struct Response: Decodable {
        let access_token: String           // swiftlint:disable:this identifier_name
        let refresh_token: String?         // swiftlint:disable:this identifier_name
        let expires_in: Int                // swiftlint:disable:this identifier_name
    }

    init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// Decode a `/api/token` response. `refreshFallback` is the previously-held refresh token,
    /// kept when the response omits one (Spotify does this on refresh).
    init(responseData: Data, refreshFallback: String?, now: Date = Date()) throws {
        let response = try JSONDecoder().decode(Response.self, from: responseData)
        guard let refresh = response.refresh_token ?? refreshFallback else {
            throw SpotifyError.missingRefreshToken
        }
        self.accessToken = response.access_token
        self.refreshToken = refresh
        self.expiresAt = now.addingTimeInterval(TimeInterval(response.expires_in))
    }

    /// True when the access token is expired or within a 60s safety skew.
    func shouldRefresh(now: Date = Date()) -> Bool {
        now >= expiresAt.addingTimeInterval(-60)
    }
}

enum SpotifyError: Error, Equatable {
    case missingRefreshToken
    case notAuthorized
    case noActiveDevice
    case http(Int)
}
```

- [ ] **Step 4: Run it, verify it passes.**

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyTokens.swift \
        CodeEditTests/Features/Spotify/SpotifyTokensTests.swift
git commit -m "feat(spotify): token model with decode + expiry"
```

---

## Task 3: `SpotifyAuthCallback` (parse redirect)

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyAuthCallback.swift`
- Test: `CodeEditTests/Features/Spotify/SpotifyAuthCallbackTests.swift`

- [ ] **Step 1: Write the failing test:**

```swift
@testable import CodeEdit
import XCTest

final class SpotifyAuthCallbackTests: XCTestCase {
    func testExtractsCodeWhenStateMatches() {
        let url = URL(string: "codeedit://spotify-callback?code=ABC123&state=xyz")!
        XCTAssertEqual(SpotifyAuthCallback.code(from: url, expectedState: "xyz"), "ABC123")
    }

    func testRejectsMismatchedState() {
        let url = URL(string: "codeedit://spotify-callback?code=ABC123&state=other")!
        XCTAssertNil(SpotifyAuthCallback.code(from: url, expectedState: "xyz"))
    }

    func testReturnsNilOnError() {
        let url = URL(string: "codeedit://spotify-callback?error=access_denied&state=xyz")!
        XCTAssertNil(SpotifyAuthCallback.code(from: url, expectedState: "xyz"))
    }
}
```

- [ ] **Step 2: Run it, verify it fails.**

- [ ] **Step 3: Implement** — `CodeEdit/Features/Spotify/SpotifyAuthCallback.swift`:

```swift
//
//  SpotifyAuthCallback.swift
//  CodeEdit
//

import Foundation

/// Parses the OAuth redirect (`codeedit://spotify-callback?code=...&state=...`).
enum SpotifyAuthCallback {
    /// Returns the authorization `code` only when `state` matches and no `error` is present.
    static func code(from url: URL, expectedState: String) -> String? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.first(where: { $0.name == "error" }) == nil,
              items.first(where: { $0.name == "state" })?.value == expectedState else {
            return nil
        }
        return items.first(where: { $0.name == "code" })?.value
    }
}
```

- [ ] **Step 4: Run it, verify it passes.**

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyAuthCallback.swift \
        CodeEditTests/Features/Spotify/SpotifyAuthCallbackTests.swift
git commit -m "feat(spotify): OAuth callback parser"
```

---

## Task 4: `SpotifyPlaybackState` (decode `/me/player`)

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyPlaybackState.swift`
- Test: `CodeEditTests/Features/Spotify/SpotifyPlaybackStateTests.swift`

- [ ] **Step 1: Write the failing test:**

```swift
@testable import CodeEdit
import XCTest

final class SpotifyPlaybackStateTests: XCTestCase {
    func testDecodesPlayerJSON() throws {
        let json = """
        {
          "is_playing": true,
          "progress_ms": 12000,
          "device": {"name": "MacBook", "volume_percent": 55},
          "item": {
            "id": "track1",
            "name": "Song",
            "duration_ms": 200000,
            "artists": [{"name": "A"}, {"name": "B"}],
            "album": {"images": [{"url": "https://img/large.jpg", "width": 640}]}
          }
        }
        """
        let state = try SpotifyPlaybackState(data: Data(json.utf8))
        XCTAssertEqual(state.isPlaying, true)
        XCTAssertEqual(state.trackID, "track1")
        XCTAssertEqual(state.title, "Song")
        XCTAssertEqual(state.artist, "A, B")
        XCTAssertEqual(state.albumArtURL?.absoluteString, "https://img/large.jpg")
        XCTAssertEqual(state.progressMs, 12000)
        XCTAssertEqual(state.durationMs, 200000)
        XCTAssertEqual(state.volumePercent, 55)
        XCTAssertEqual(state.deviceName, "MacBook")
    }

    func testEmptyBodyMeansNothingPlaying() throws {
        // Spotify returns 204 / empty body when nothing is active.
        XCTAssertNil(try SpotifyPlaybackState(dataOrEmpty: Data()))
    }
}
```

- [ ] **Step 2: Run it, verify it fails.**

- [ ] **Step 3: Implement** — `CodeEdit/Features/Spotify/SpotifyPlaybackState.swift`:

```swift
//
//  SpotifyPlaybackState.swift
//  CodeEdit
//

import Foundation

/// A snapshot of the user's current Spotify playback.
struct SpotifyPlaybackState: Equatable {
    var isPlaying: Bool
    var trackID: String?
    var title: String
    var artist: String
    var albumArtURL: URL?
    var progressMs: Int
    var durationMs: Int
    var volumePercent: Int
    var deviceName: String?

    private struct Payload: Decodable {
        struct Device: Decodable {
            let name: String?
            let volumePercent: Int?
            enum CodingKeys: String, CodingKey { case name, volumePercent = "volume_percent" }
        }
        struct Item: Decodable {
            struct Artist: Decodable { let name: String }
            struct Album: Decodable { struct Image: Decodable { let url: String }; let images: [Image] }
            let id: String
            let name: String
            let durationMs: Int
            let artists: [Artist]
            let album: Album
            enum CodingKeys: String, CodingKey { case id, name, durationMs = "duration_ms", artists, album }
        }
        let isPlaying: Bool
        let progressMs: Int?
        let device: Device?
        let item: Item?
        enum CodingKeys: String, CodingKey {
            case isPlaying = "is_playing", progressMs = "progress_ms", device, item
        }
    }

    init(data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        self.isPlaying = payload.isPlaying
        self.progressMs = payload.progressMs ?? 0
        self.volumePercent = payload.device?.volumePercent ?? 0
        self.deviceName = payload.device?.name
        self.trackID = payload.item?.id
        self.title = payload.item?.name ?? "—"
        self.artist = (payload.item?.artists.map(\.name).joined(separator: ", ")) ?? ""
        self.durationMs = payload.item?.durationMs ?? 0
        self.albumArtURL = (payload.item?.album.images.first?.url).flatMap(URL.init(string:))
    }

    /// Returns nil for an empty body (nothing playing / 204).
    init?(dataOrEmpty data: Data) throws {
        guard !data.isEmpty else { return nil }
        try self.init(data: data)
    }
}
```

- [ ] **Step 4: Run it, verify it passes.**

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyPlaybackState.swift \
        CodeEditTests/Features/Spotify/SpotifyPlaybackStateTests.swift
git commit -m "feat(spotify): playback-state decoding"
```

---

## Task 5: `SpotifyRequest` (pure request builders)

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyRequest.swift`
- Test: `CodeEditTests/Features/Spotify/SpotifyRequestTests.swift`

- [ ] **Step 1: Write the failing test:**

```swift
@testable import CodeEdit
import XCTest

final class SpotifyRequestTests: XCTestCase {
    private func assertAuth(_ request: URLRequest, _ token: String = "TK") {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
    }

    func testPlayerIsGet() {
        let request = SpotifyRequest.player(token: "TK")
        XCTAssertEqual(request.url?.absoluteString, "https://api.spotify.com/v1/me/player")
        XCTAssertEqual(request.httpMethod, "GET")
        assertAuth(request)
    }

    func testPauseIsPut() {
        let request = SpotifyRequest.pause(token: "TK")
        XCTAssertEqual(request.url?.absoluteString, "https://api.spotify.com/v1/me/player/pause")
        XCTAssertEqual(request.httpMethod, "PUT")
    }

    func testNextIsPost() {
        XCTAssertEqual(SpotifyRequest.next(token: "TK").httpMethod, "POST")
        XCTAssertEqual(SpotifyRequest.next(token: "TK").url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/next")
    }

    func testSeekCarriesPositionQuery() {
        XCTAssertEqual(SpotifyRequest.seek(toMs: 4200, token: "TK").url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/seek?position_ms=4200")
    }

    func testVolumeCarriesPercentQuery() {
        XCTAssertEqual(SpotifyRequest.volume(percent: 30, token: "TK").url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/volume?volume_percent=30")
    }

    func testLikeAndUnlikeAndContains() {
        XCTAssertEqual(SpotifyRequest.like(ids: ["a", "b"], token: "TK").httpMethod, "PUT")
        XCTAssertEqual(SpotifyRequest.unlike(ids: ["a"], token: "TK").httpMethod, "DELETE")
        let contains = SpotifyRequest.isLiked(ids: ["a", "b"], token: "TK")
        XCTAssertEqual(contains.httpMethod, "GET")
        XCTAssertEqual(contains.url?.absoluteString,
                       "https://api.spotify.com/v1/me/tracks/contains?ids=a,b")
    }
}
```

- [ ] **Step 2: Run it, verify it fails.**

- [ ] **Step 3: Implement** — `CodeEdit/Features/Spotify/SpotifyRequest.swift`:

```swift
//
//  SpotifyRequest.swift
//  CodeEdit
//

import Foundation

/// Pure builders for Spotify Web API requests (no networking — testable).
enum SpotifyRequest {
    static func player(token: String) -> URLRequest { make("/me/player", "GET", token) }
    static func play(token: String) -> URLRequest { make("/me/player/play", "PUT", token) }
    static func pause(token: String) -> URLRequest { make("/me/player/pause", "PUT", token) }
    static func next(token: String) -> URLRequest { make("/me/player/next", "POST", token) }
    static func previous(token: String) -> URLRequest { make("/me/player/previous", "POST", token) }
    static func seek(toMs ms: Int, token: String) -> URLRequest {
        make("/me/player/seek?position_ms=\(ms)", "PUT", token)
    }
    static func volume(percent: Int, token: String) -> URLRequest {
        make("/me/player/volume?volume_percent=\(percent)", "PUT", token)
    }
    static func devices(token: String) -> URLRequest { make("/me/player/devices", "GET", token) }
    static func transfer(deviceID: String, token: String) -> URLRequest {
        var request = make("/me/player", "PUT", token)
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["device_ids": [deviceID], "play": true])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    static func like(ids: [String], token: String) -> URLRequest {
        make("/me/tracks?ids=\(ids.joined(separator: ","))", "PUT", token)
    }
    static func unlike(ids: [String], token: String) -> URLRequest {
        make("/me/tracks?ids=\(ids.joined(separator: ","))", "DELETE", token)
    }
    static func isLiked(ids: [String], token: String) -> URLRequest {
        make("/me/tracks/contains?ids=\(ids.joined(separator: ","))", "GET", token)
    }

    private static func make(_ path: String, _ method: String, _ token: String) -> URLRequest {
        var request = URLRequest(url: URL(string: SpotifyConfiguration.apiBaseURL.absoluteString + path)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
```

- [ ] **Step 4: Run it, verify it passes.**

- [ ] **Step 5: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyRequest.swift \
        CodeEditTests/Features/Spotify/SpotifyRequestTests.swift
git commit -m "feat(spotify): pure Web API request builders"
```

---

## Task 6: `SpotifyAuthService` (OAuth + Keychain)

Integration (network + ASWebAuthenticationSession). No unit test — the pure parts it uses are already tested; verify by build + the manual login in Task 11.

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyAuthService.swift`

- [ ] **Step 1: Implement** — `CodeEdit/Features/Spotify/SpotifyAuthService.swift`:

```swift
//
//  SpotifyAuthService.swift
//  CodeEdit
//

import AppKit
import AuthenticationServices

/// Runs the Spotify Authorization-Code-with-PKCE flow, persists tokens in the Keychain, and
/// vends a valid access token (refreshing when needed).
@MainActor
final class SpotifyAuthService: NSObject {
    private let keychain = CodeEditKeychain()
    private var session: ASWebAuthenticationSession?

    private(set) var tokens: SpotifyTokens? {
        didSet { persist() }
    }

    override init() {
        super.init()
        if let raw = keychain.get(SpotifyConfiguration.keychainKey),
           let data = raw.data(using: .utf8),
           let stored = try? JSONDecoder().decode(SpotifyTokens.self, from: data) {
            self.tokens = stored
        }
    }

    var isAuthorized: Bool { tokens != nil }

    /// Interactive login. Throws on user cancel or token-exchange failure.
    func authorize() async throws {
        let verifier = SpotifyPKCE.makeVerifier()
        let challenge = SpotifyPKCE.challenge(for: verifier)
        let state = UUID().uuidString

        var comps = URLComponents(url: SpotifyConfiguration.authorizeURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "client_id", value: SpotifyConfiguration.clientID),
            .init(name: "response_type", value: "code"),
            .init(name: "redirect_uri", value: SpotifyConfiguration.redirectURI),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "state", value: state),
            .init(name: "scope", value: SpotifyConfiguration.scopes.joined(separator: " "))
        ]

        let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: comps.url!,
                callbackURLScheme: SpotifyConfiguration.callbackScheme
            ) { url, error in
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? SpotifyError.notAuthorized) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }

        guard let code = SpotifyAuthCallback.code(from: callbackURL, expectedState: state) else {
            throw SpotifyError.notAuthorized
        }
        try await exchange(code: code, verifier: verifier)
    }

    func logout() {
        tokens = nil
        keychain.delete(SpotifyConfiguration.keychainKey)
    }

    /// A valid access token, refreshing first if it is expiring.
    func validAccessToken() async throws -> String {
        guard var current = tokens else { throw SpotifyError.notAuthorized }
        if current.shouldRefresh() {
            current = try await refresh(current)
        }
        return current.accessToken
    }

    // MARK: - Token endpoints

    private func exchange(code: String, verifier: String) async throws {
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyConfiguration.redirectURI,
            "client_id": SpotifyConfiguration.clientID,
            "code_verifier": verifier
        ]
        let data = try await postForm(body)
        tokens = try SpotifyTokens(responseData: data, refreshFallback: nil)
    }

    @discardableResult
    private func refresh(_ current: SpotifyTokens) async throws -> SpotifyTokens {
        let body = [
            "grant_type": "refresh_token",
            "refresh_token": current.refreshToken,
            "client_id": SpotifyConfiguration.clientID
        ]
        let data = try await postForm(body)
        let refreshed = try SpotifyTokens(responseData: data, refreshFallback: current.refreshToken)
        tokens = refreshed
        return refreshed
    }

    private func postForm(_ fields: [String: String]) async throws -> Data {
        var request = URLRequest(url: SpotifyConfiguration.tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SpotifyError.http(http.statusCode)
        }
        return data
    }

    private func persist() {
        guard let tokens, let data = try? JSONEncoder().encode(tokens),
              let raw = String(data: data, encoding: .utf8) else { return }
        keychain.set(raw, forKey: SpotifyConfiguration.keychainKey)
    }
}

extension SpotifyAuthService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.keyWindow ?? ASPresentationAnchor()
    }
}

extension CharacterSet {
    /// Allowed characters for `application/x-www-form-urlencoded` values.
    static let urlQueryValueAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
```

- [ ] **Step 2: Build, verify it compiles** (full **Build** command → `** BUILD SUCCEEDED **`).

- [ ] **Step 3: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyAuthService.swift
git commit -m "feat(spotify): OAuth PKCE auth service with Keychain persistence"
```

---

## Task 7: `SpotifyAPIClient` (send + refresh)

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyAPIClient.swift`

- [ ] **Step 1: Implement** — `CodeEdit/Features/Spotify/SpotifyAPIClient.swift`:

```swift
//
//  SpotifyAPIClient.swift
//  CodeEdit
//

import Foundation

/// Sends Web API requests with a valid bearer token, refreshing once on 401.
@MainActor
final class SpotifyAPIClient {
    private let auth: SpotifyAuthService
    private let session: URLSession

    init(auth: SpotifyAuthService, session: URLSession = .shared) {
        self.auth = auth
        self.session = session
    }

    /// Current playback (nil when nothing is active / 204).
    func currentPlayback() async throws -> SpotifyPlaybackState? {
        let data = try await send { SpotifyRequest.player(token: $0) }
        return try SpotifyPlaybackState(dataOrEmpty: data)
    }

    func play() async throws { _ = try await send { SpotifyRequest.play(token: $0) } }
    func pause() async throws { _ = try await send { SpotifyRequest.pause(token: $0) } }
    func next() async throws { _ = try await send { SpotifyRequest.next(token: $0) } }
    func previous() async throws { _ = try await send { SpotifyRequest.previous(token: $0) } }
    func seek(toMs ms: Int) async throws { _ = try await send { SpotifyRequest.seek(toMs: ms, token: $0) } }
    func setVolume(_ percent: Int) async throws { _ = try await send { SpotifyRequest.volume(percent: percent, token: $0) } }
    func like(_ id: String) async throws { _ = try await send { SpotifyRequest.like(ids: [id], token: $0) } }
    func unlike(_ id: String) async throws { _ = try await send { SpotifyRequest.unlike(ids: [id], token: $0) } }

    func isLiked(_ id: String) async throws -> Bool {
        let data = try await send { SpotifyRequest.isLiked(ids: [id], token: $0) }
        return (try? JSONDecoder().decode([Bool].self, from: data))?.first ?? false
    }

    /// Builds the request with a fresh token, sends it, and refreshes+retries once on 401.
    private func send(_ build: (String) -> URLRequest, isRetry: Bool = false) async throws -> Data {
        let token = try await auth.validAccessToken()
        let (data, response) = try await session.data(for: build(token))
        guard let http = response as? HTTPURLResponse else { return data }
        switch http.statusCode {
        case 200...299:
            return data
        case 401 where !isRetry:
            return try await send(build, isRetry: true)
        case 404:
            throw SpotifyError.noActiveDevice
        default:
            throw SpotifyError.http(http.statusCode)
        }
    }
}
```

- [ ] **Step 2: Build, verify it compiles.**

- [ ] **Step 3: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyAPIClient.swift
git commit -m "feat(spotify): Web API client with 401-refresh + 404 handling"
```

---

## Task 8: `SpotifyPlayerModel` (shared state + polling)

**Files:**
- Create: `CodeEdit/Features/Spotify/SpotifyPlayerModel.swift`

- [ ] **Step 1: Implement** — `CodeEdit/Features/Spotify/SpotifyPlayerModel.swift`:

```swift
//
//  SpotifyPlayerModel.swift
//  CodeEdit
//

import Combine
import Foundation

/// Shared, app-wide Spotify player state. Music is global, so a single instance backs every
/// window's toolbar player.
@MainActor
final class SpotifyPlayerModel: ObservableObject {
    static let shared = SpotifyPlayerModel()

    @Published private(set) var isAuthorized: Bool
    @Published private(set) var state: SpotifyPlaybackState?
    @Published private(set) var isLiked = false
    @Published private(set) var hasActiveDevice = true
    @Published private(set) var localProgressMs = 0

    private let auth: SpotifyAuthService
    private let api: SpotifyAPIClient
    private var pollTask: Task<Void, Never>?
    private var ticker: Timer?
    private var lastLikedTrackID: String?

    init(auth: SpotifyAuthService = SpotifyAuthService()) {
        self.auth = auth
        self.api = SpotifyAPIClient(auth: auth)
        self.isAuthorized = auth.isAuthorized
    }

    // MARK: - Lifecycle

    /// Begin polling `/me/player` (call when a player view appears).
    func start() {
        guard pollTask == nil, isAuthorized else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        startTicker()
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        ticker?.invalidate(); ticker = nil
    }

    // MARK: - Auth

    func connect() {
        Task {
            do {
                try await auth.authorize()
                isAuthorized = auth.isAuthorized
                start()
                await refresh()
            } catch { /* user cancelled or failed; stay disconnected */ }
        }
    }

    func disconnect() {
        auth.logout()
        isAuthorized = false
        state = nil
        stop()
    }

    // MARK: - Commands (optimistic, then reconcile on next poll)

    func togglePlayPause() {
        let playing = state?.isPlaying ?? false
        command { playing ? try await self.api.pause() : try await self.api.play() }
    }
    func next() { command { try await self.api.next() } }
    func previous() { command { try await self.api.previous() } }
    func seek(toMs ms: Int) { localProgressMs = ms; command { try await self.api.seek(toMs: ms) } }
    func setVolume(_ percent: Int) { command { try await self.api.setVolume(percent) } }

    func toggleLike() {
        guard let id = state?.trackID else { return }
        let nowLiked = !isLiked
        isLiked = nowLiked
        command { nowLiked ? try await self.api.like(id) : try await self.api.unlike(id) }
    }

    // MARK: - Internals

    private func command(_ action: @escaping () async throws -> Void) {
        Task {
            do { try await action(); hasActiveDevice = true; await refresh() }
            catch SpotifyError.noActiveDevice { hasActiveDevice = false }
            catch SpotifyError.notAuthorized { isAuthorized = false }
            catch { /* transient; next poll reconciles */ }
        }
    }

    private func refresh() async {
        do {
            let playback = try await api.currentPlayback()
            self.state = playback
            self.hasActiveDevice = playback != nil
            self.localProgressMs = playback?.progressMs ?? 0
            if let id = playback?.trackID, id != lastLikedTrackID {
                lastLikedTrackID = id
                self.isLiked = (try? await api.isLiked(id)) ?? false
            }
        } catch SpotifyError.notAuthorized {
            self.isAuthorized = false
        } catch SpotifyError.noActiveDevice {
            self.hasActiveDevice = false
        } catch { /* keep last state */ }
    }

    /// Advances the local progress between polls for a smooth scrubber.
    private func startTicker() {
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state?.isPlaying == true else { return }
                self.localProgressMs = min(self.localProgressMs + 1000, self.state?.durationMs ?? 0)
            }
        }
    }
}
```

- [ ] **Step 2: Build, verify it compiles.**

- [ ] **Step 3: Commit**

```bash
git add CodeEdit/Features/Spotify/SpotifyPlayerModel.swift
git commit -m "feat(spotify): shared player model with polling + commands"
```

---

## Task 9: `SpotifyPlayerView` + popover

**Files:**
- Create: `CodeEdit/Features/Spotify/Views/SpotifyPlayerView.swift`, `CodeEdit/Features/Spotify/Views/SpotifyPlayerPopover.swift`

- [ ] **Step 1: Implement** — `CodeEdit/Features/Spotify/Views/SpotifyPlayerView.swift`:

```swift
//
//  SpotifyPlayerView.swift
//  CodeEdit
//

import SwiftUI

/// Toolbar mini-player. Shows now-playing + transport; a click opens the extended popover.
struct SpotifyPlayerView: View {
    @ObservedObject private var model = SpotifyPlayerModel.shared
    @State private var showPopover = false

    var body: some View {
        Group {
            if model.isAuthorized {
                player
            } else {
                Button {
                    model.connect()
                } label: {
                    Label("Connect Spotify", systemImage: "music.note")
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var player: some View {
        HStack(spacing: 8) {
            artwork
            VStack(alignment: .leading, spacing: 0) {
                Text(model.state?.title ?? "Not playing")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(model.state?.artist ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 90, alignment: .leading)
            Button { model.previous() } label: { Image(systemName: "backward.fill") }
            Button {
                model.togglePlayPause()
            } label: {
                Image(systemName: model.state?.isPlaying == true ? "pause.fill" : "play.fill")
            }
            Button { model.next() } label: { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.icon(size: 22))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: 360)
        .background {
            if #available(macOS 26, *) {
                GlassEffectView().clipShape(Capsule())
            } else {
                Capsule().fill(.quaternary)
            }
        }
        .contentShape(Capsule())
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            SpotifyPlayerPopover(model: model)
        }
        .help(model.hasActiveDevice ? (model.state?.title ?? "Spotify") : "No active Spotify device — open Spotify")
    }

    @ViewBuilder private var artwork: some View {
        if let url = model.state?.albumArtURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "music.note")
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)
        }
    }
}
```

`CodeEdit/Features/Spotify/Views/SpotifyPlayerPopover.swift`:

```swift
//
//  SpotifyPlayerPopover.swift
//  CodeEdit
//

import SwiftUI

/// Extended controls: scrubber, like, volume.
struct SpotifyPlayerPopover: View {
    @ObservedObject var model: SpotifyPlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(model.state?.title ?? "Not playing").font(.headline).lineLimit(1)
                Spacer()
                Button {
                    model.toggleLike()
                } label: {
                    Image(systemName: model.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(model.isLiked ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Like")
            }

            if !model.hasActiveDevice {
                Label("No active device — open Spotify and press play once.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Scrubber
            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { Double(model.localProgressMs) },
                        set: { model.seek(toMs: Int($0)) }
                    ),
                    in: 0...Double(max(model.state?.durationMs ?? 1, 1))
                )
                HStack {
                    Text(Self.time(model.localProgressMs)).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.time(model.state?.durationMs ?? 0)).font(.caption2).foregroundStyle(.secondary)
                }
            }

            // Volume
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(model.state?.volumePercent ?? 0) },
                        set: { model.setVolume(Int($0)) }
                    ),
                    in: 0...100
                )
                Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private static func time(_ ms: Int) -> String {
        let total = ms / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
```

- [ ] **Step 2: Build, verify it compiles.**

- [ ] **Step 3: Commit**

```bash
git add CodeEdit/Features/Spotify/Views/SpotifyPlayerView.swift \
        CodeEdit/Features/Spotify/Views/SpotifyPlayerPopover.swift
git commit -m "feat(spotify): toolbar mini-player view + extended popover"
```

---

## Task 10: Toolbar integration (remove Tasks, add Spotify)

**Files:**
- Modify: `CodeEdit/Features/Documents/Controllers/CodeEditWindowControllerExtensions.swift` (identifier)
- Modify: `CodeEdit/Features/Documents/Controllers/CodeEditWindowController+Toolbar.swift` (item lists + builder)

- [ ] **Step 1: Add the identifier.** In `CodeEditWindowControllerExtensions.swift`, inside `extension NSToolbarItem.Identifier`, add:

```swift
    static let spotifyPlayer = NSToolbarItem.Identifier("SpotifyPlayer")
```

- [ ] **Step 2: Swap the centered item and drop the task items.** In `CodeEditWindowController+Toolbar.swift`:

In `makeToolbar()` (the `centeredItemIdentifiers` line), replace:
```swift
            toolbar.centeredItemIdentifiers = [.activityViewer, .notificationItem]
```
with:
```swift
            toolbar.centeredItemIdentifiers = [.spotifyPlayer]
```

In `toolbarDefaultItemIdentifiers(_:)`, remove the task block and the activity/notification block so the body reads:
```swift
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        var items: [NSToolbarItem.Identifier] = [
            .toggleFirstSidebarItem,
            .flexibleSpace,
            .sidebarTrackingSeparator,
            .branchPicker,
            .flexibleSpace,
            .spotifyPlayer,
            .flexibleSpace,
            .itemListTrackingSeparator,
            .flexibleSpace,
            .editorAgentModeItem,
            .toggleLastSidebarItem
        ]
        return items
    }
```

In `toolbarAllowedItemIdentifiers(_:)`, remove `.activityViewer`, `.notificationItem`, and the task identifiers (`.taskSidebarItem`, `.startTaskSidebarItem`, `.stopTaskSidebarItem`) and add `.spotifyPlayer`. The base array becomes:
```swift
        var items: [NSToolbarItem.Identifier] = [
            .toggleFirstSidebarItem,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            .itemListTrackingSeparator,
            .toggleLastSidebarItem,
            .editorAgentModeItem,
            .branchPicker,
            .spotifyPlayer,
        ]
```
…and delete the `if #available(macOS 26, *) { items += [.taskSidebarItem] } else { items += [.startTaskSidebarItem, .stopTaskSidebarItem] }` block that followed it.

- [ ] **Step 3: Build the toolbar item.** In `toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)`, replace the `case .activityViewer:` / `.notificationItem:` / task cases with a single Spotify case (delete `case .activityViewer: return activityViewerItem()`, `case .notificationItem: return notificationItem()`, `case .stopTaskSidebarItem:`, `case .startTaskSidebarItem:`, and the `case .taskSidebarItem:` group), and add:

```swift
        case .spotifyPlayer:
            return spotifyPlayerItem()
```

Add the builder method (mirroring `activityViewerItem()`), next to it:

```swift
    private func spotifyPlayerItem() -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: .spotifyPlayer)
        toolbarItem.visibilityPriority = .user
        let view = NSHostingView(rootView: SpotifyPlayerView())
        let lowWidth = view.widthAnchor.constraint(equalToConstant: 360)
        lowWidth.priority = .defaultLow
        let minWidth = view.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        minWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([lowWidth, minWidth])
        toolbarItem.view = view
        return toolbarItem
    }
```

(Leave `activityViewerItem()`, `notificationItem()`, `startTaskSidebarItem()`, `stopTaskSidebarItem()` defined but unused, or delete them — deleting is cleaner since the spec says remove the Tasks UI. If deleting causes unrelated build errors from other references, leave them defined; they are simply no longer wired into the toolbar.)

- [ ] **Step 4: Build, verify success.** Run the **Build** command → `** BUILD SUCCEEDED **`. If removing a task case leaves an unused-private-function warning, delete that function; if a deletion breaks an unrelated reference, restore the function body but keep it out of the identifier lists.

- [ ] **Step 5: Manual verification.** Launch the app: the toolbar center shows the Spotify mini-player (Connect button when signed out); the task run/stop/scheme/activity items and the notification bell are gone.

- [ ] **Step 6: Commit**

```bash
git add CodeEdit/Features/Documents/Controllers/CodeEditWindowControllerExtensions.swift \
        CodeEdit/Features/Documents/Controllers/CodeEditWindowController+Toolbar.swift
git commit -m "feat(spotify): put the player in the toolbar, remove the Tasks UI"
```

---

## Task 11: Integration verification

**Files:** none (verification only).

- [ ] **Step 1: Full build** → `** BUILD SUCCEEDED **`.
- [ ] **Step 2: Run all Spotify unit suites:**
  `-only-testing:CodeEditTests/SpotifyPKCETests -only-testing:CodeEditTests/SpotifyTokensTests -only-testing:CodeEditTests/SpotifyAuthCallbackTests -only-testing:CodeEditTests/SpotifyPlaybackStateTests -only-testing:CodeEditTests/SpotifyRequestTests` → all pass.
- [ ] **Step 3: One-time Spotify dashboard setup (user).** Confirm the app's Redirect URI is `codeedit://spotify-callback` (or, if rejected, `http://127.0.0.1:8888/spotify-callback` + switch the flow to the loopback fallback). Client ID already in `SpotifyConfiguration`.
- [ ] **Step 4: Manual end-to-end.** Launch → click **Connect Spotify** → log in → consent → returns authorized. Start playing on any Spotify device. The toolbar shows now-playing + art; play/pause, prev/next work; the popover scrubber seeks; volume slider changes device volume; like toggles the heart and saves/removes from the library. Quit & relaunch → still authorized (Keychain). With no active device, controls show the "open Spotify" hint.

---

## Self-Review

**Spec coverage:**
- OAuth PKCE + Keychain → Tasks 1–2, 6. ✓
- Web API control (play/pause/next/prev/seek/volume/like, /me/player) → Tasks 4–5, 7–8. ✓
- Now playing (title/artist/art) → Tasks 4, 9. ✓
- Toolbar replaces Tasks UI (incl. notification bell) → Task 10. ✓
- Shared model + polling → Task 8. ✓
- Premium control + no-active-device handling → Tasks 7 (404), 8, 9. ✓
- Loopback contingency → Tasks 6/11 (documented). ✓
- Tests for PKCE / token / callback / playback decode / request building → Tasks 1–5. ✓

**Placeholder scan:** No TBD/TODO; every code step is complete; commands have expected outputs.

**Type consistency:**
- `SpotifyConfiguration` (clientID, redirectURI, callbackScheme, scopes, authorize/token/apiBaseURL, keychainKey) — Task 1, used in 5/6.
- `SpotifyPKCE.makeVerifier()` / `challenge(for:)` + `Data.base64URLEncodedString()` — Task 1, used in 6.
- `SpotifyTokens(responseData:refreshFallback:now:)`, `init(accessToken:refreshToken:expiresAt:)`, `shouldRefresh(now:)`; `SpotifyError` — Task 2, used in 6. ✓
- `SpotifyAuthCallback.code(from:expectedState:)` — Task 3, used in 6. ✓
- `SpotifyPlaybackState(data:)` / `init?(dataOrEmpty:)`, fields (isPlaying, trackID, title, artist, albumArtURL, progressMs, durationMs, volumePercent, deviceName) — Task 4, used in 7/8/9. ✓
- `SpotifyRequest.{player,play,pause,next,previous,seek,volume,devices,transfer,like,unlike,isLiked}` — Task 5, used in 7. ✓
- `SpotifyAuthService.{authorize,logout,validAccessToken,isAuthorized,tokens}` — Task 6, used in 7/8. ✓
- `SpotifyAPIClient.{currentPlayback,play,pause,next,previous,seek,setVolume,like,unlike,isLiked}` — Task 7, used in 8. ✓
- `SpotifyPlayerModel.shared` + published props + commands — Task 8, used in 9. ✓
- `.spotifyPlayer` identifier + `spotifyPlayerItem()` — Task 10. ✓

**Green-build ordering:** Tasks 1–5 are independently green. Tasks 6–9 each build on the prior and stay green (they compile against already-created types). Task 10 wires the view into the toolbar. No task leaves the build broken.
