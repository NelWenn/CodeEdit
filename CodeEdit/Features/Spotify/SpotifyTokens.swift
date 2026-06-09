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
