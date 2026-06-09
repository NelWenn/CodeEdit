//
//  SpotifyTokens.swift
//  CodeEdit
//

import Foundation

/// Persisted Spotify OAuth tokens.
struct SpotifyTokens: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date

    private struct Response: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: Int
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
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
        guard let refresh = response.refreshToken ?? refreshFallback else {
            throw SpotifyError.missingRefreshToken
        }
        self.accessToken = response.accessToken
        self.refreshToken = refresh
        self.expiresAt = now.addingTimeInterval(TimeInterval(response.expiresIn))
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
