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

    func seek(toMs positionMs: Int) async throws {
        _ = try await send { SpotifyRequest.seek(toMs: positionMs, token: $0) }
    }

    func setVolume(_ percent: Int) async throws {
        _ = try await send { SpotifyRequest.volume(percent: percent, token: $0) }
    }

    func like(_ id: String) async throws { _ = try await send { SpotifyRequest.like(ids: [id], token: $0) } }
    func unlike(_ id: String) async throws { _ = try await send { SpotifyRequest.unlike(ids: [id], token: $0) } }

    func isLiked(_ id: String) async throws -> Bool {
        let data = try await send { SpotifyRequest.isLiked(ids: [id], token: $0) }
        return (try? JSONDecoder().decode([Bool].self, from: data))?.first ?? false
    }

    /// Builds the request with a fresh token, sends it, and refreshes+retries once on 401.
    private func send(_ build: @escaping (String) -> URLRequest, isRetry: Bool = false) async throws -> Data {
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
