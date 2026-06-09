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
