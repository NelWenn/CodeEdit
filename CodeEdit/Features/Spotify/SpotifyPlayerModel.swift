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
    @Published private(set) var localVolumePercent = 0

    private let auth: SpotifyAuthService
    private let api: SpotifyAPIClient
    private var pollTask: Task<Void, Never>?
    private var ticker: Task<Void, Never>?
    private var lastLikedTrackID: String?
    /// Number of visible player views. Polling runs while ≥1, so closing one window's toolbar
    /// doesn't freeze the player in another open window.
    private var viewerCount = 0
    /// True while the user drags the scrubber, so the poll/ticker don't fight the thumb.
    private var isScrubbing = false
    /// Debounces volume API calls so dragging the slider doesn't flood the Web API (which lags).
    private var volumeDebounce: Task<Void, Never>?
    private var lastVolumeChange = Date.distantPast

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
        ticker?.cancel(); ticker = nil
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
        localVolumePercent = 0
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

    // Scrubbing: move the thumb locally during the drag; seek once on release (no immediate
    // refresh, so the thumb doesn't snap back to a not-yet-updated server position).
    func beginScrubbing() { isScrubbing = true }
    func scrub(toMs positionMs: Int) { localProgressMs = positionMs }
    func endScrubbing(toMs positionMs: Int) {
        isScrubbing = false
        localProgressMs = positionMs
        runDeviceCommand { try await self.api.seek(toMs: positionMs) }
    }

    /// Optimistic + debounced: `localVolumePercent` updates immediately so the slider stays
    /// smooth, while the API call is coalesced instead of firing on every pixel (which lags).
    func setVolume(_ percent: Int) {
        localVolumePercent = percent
        lastVolumeChange = Date()
        volumeDebounce?.cancel()
        volumeDebounce = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled, let self else { return }
            await self.sendVolume(percent)
        }
    }

    private func sendVolume(_ percent: Int) async {
        do {
            try await api.setVolume(percent)
            hasActiveDevice = true
        } catch SpotifyError.noActiveDevice {
            hasActiveDevice = false
        } catch SpotifyError.notAuthorized {
            isAuthorized = false
        } catch {
            /* transient */
        }
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
            do {
                try await action()
                hasActiveDevice = true
                await refresh()
            } catch SpotifyError.noActiveDevice {
                hasActiveDevice = false
            } catch SpotifyError.notAuthorized {
                isAuthorized = false
            } catch {
                /* transient; next poll reconciles */
            }
        }
    }

    /// Like `command` but without the immediate `refresh()` — used for seek/volume so a local
    /// optimistic value isn't overwritten by a server position that hasn't caught up yet.
    private func runDeviceCommand(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                hasActiveDevice = true
            } catch SpotifyError.noActiveDevice {
                hasActiveDevice = false
            } catch SpotifyError.notAuthorized {
                isAuthorized = false
            } catch {
                /* transient; next poll reconciles */
            }
        }
    }

    private func refresh() async {
        do {
            let playback = try await api.currentPlayback()
            self.state = playback
            self.hasActiveDevice = playback != nil
            if !self.isScrubbing {
                self.localProgressMs = playback?.progressMs ?? 0
            }
            // Don't yank the volume thumb back while the user is actively adjusting it.
            if Date().timeIntervalSince(self.lastVolumeChange) > 1.5 {
                self.localVolumePercent = playback?.volumePercent ?? 0
            }
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
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                guard self.state?.isPlaying == true, !self.isScrubbing else { continue }
                self.localProgressMs = min(self.localProgressMs + 1000, self.state?.durationMs ?? 0)
            }
        }
    }
}
