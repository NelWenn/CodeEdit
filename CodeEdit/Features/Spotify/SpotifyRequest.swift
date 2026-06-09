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
    static func seek(toMs positionMs: Int, token: String) -> URLRequest {
        make("/me/player/seek?position_ms=\(positionMs)", "PUT", token)
    }
    static func volume(percent: Int, token: String) -> URLRequest {
        make("/me/player/volume?volume_percent=\(percent)", "PUT", token)
    }
    static func devices(token: String) -> URLRequest { make("/me/player/devices", "GET", token) }
    static func transfer(deviceID: String, token: String) -> URLRequest {
        var request = make("/me/player", "PUT", token)
        request.httpBody = try? JSONSerialization.data(
            withJSONObject: ["device_ids": [deviceID], "play": true]
        )
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
        // swiftlint:disable:next force_unwrapping
        var request = URLRequest(url: URL(string: SpotifyConfiguration.apiBaseURL.absoluteString + path)!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
