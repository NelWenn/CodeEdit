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
    /// Number of visible player views. Polling runs while ≥1, so closing one window's toolbar
    /// doesn't freeze the player in another open window.
    private var viewerCount = 0

    convenience init() {
        self.init(auth: SpotifyAuthService())
    }

    init(auth: SpotifyAuthService) {
        self.auth = auth
        self.api = SpotifyAPIClient(auth: auth)
        self.isAuthorized = auth.isAuthorized
    }

    // MARK: - Lifecycle

    /// Register a visible player view (call from `onAppear`) and begin polling if needed.
    func start() {
        viewerCount += 1
        beginPollingIfNeeded()
    }

    /// Unregister a player view (call from `onDisappear`); tears down polling once none remain.
    func stop() {
        viewerCount = max(0, viewerCount - 1)
        guard viewerCount == 0 else { return }
        teardownPolling()
    }

    private func beginPollingIfNeeded() {
        guard pollTask == nil, isAuthorized else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        startTicker()
    }

    private func teardownPolling() {
        pollTask?.cancel(); pollTask = nil
        ticker?.invalidate(); ticker = nil
    }

    // MARK: - Auth

    func connect() {
        Task {
            do {
                try await auth.authorize()
                isAuthorized = auth.isAuthorized
                beginPollingIfNeeded()
                await refresh()
            } catch { /* user cancelled or failed; stay disconnected */ }
        }
    }

    func disconnect() {
        auth.logout()
        isAuthorized = false
        state = nil
        isLiked = false
        hasActiveDevice = true
        localProgressMs = 0
        lastLikedTrackID = nil
        teardownPolling()
    }

    // MARK: - Commands (optimistic, then reconcile on next poll)

    func togglePlayPause() {
        let playing = state?.isPlaying ?? false
        command { playing ? try await self.api.pause() : try await self.api.play() }
    }
    func next() { command { try await self.api.next() } }
    func previous() { command { try await self.api.previous() } }

    func seek(toMs positionMs: Int) {
        localProgressMs = positionMs
        command { try await self.api.seek(toMs: positionMs) }
    }

    func setVolume(_ percent: Int) {
        command { try await self.api.setVolume(percent) }
    }

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
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self, self.state?.isPlaying == true else { return }
                self.localProgressMs = min(self.localProgressMs + 1000, self.state?.durationMs ?? 0)
            }
        }
    }
}
