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
