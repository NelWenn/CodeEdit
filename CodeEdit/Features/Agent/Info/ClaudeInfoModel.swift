//
//  ClaudeInfoModel.swift
//  CodeEdit
//

import Foundation
import Combine

/// Aggregates Claude account, live session state, and usage for the Agent-mode Inspector.
@MainActor
final class ClaudeInfoModel: ObservableObject {
    @Published private(set) var account: ClaudeAccount?
    @Published private(set) var liveState = ClaudeLiveState()
    @Published private(set) var usage = ClaudeUsage()
    @Published private(set) var usageIsStale = false

    private let settingsStore = ClaudeSettingsStore()
    private let installer = ClaudeUsageStatuslineInstaller()
    private var fileTimer: AnyCancellable?
    private var lastEndpointFetch = Date.distantPast
    private weak var session: ClaudeSession?

    func start(session: ClaudeSession?) {
        self.session = session
        try? installer.ensureInstalled()
        account = try? ClaudeAccountReader.read()
        readLiveState()
        Task { await refreshUsage() }
        fileTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func stop() {
        fileTimer?.cancel()
        fileTimer = nil
    }

    private func tick() {
        readLiveState()
        // Usage windows change slowly: hit the endpoint at most once per minute.
        if Date().timeIntervalSince(lastEndpointFetch) > 60 {
            Task { await refreshUsage() }
        }
        objectWillChange.send() // keep "Resets in …" countdowns ticking
    }

    private func readLiveState() {
        if let data = try? Data(contentsOf: installer.statusFileURL),
           let parsed = try? ClaudeLiveState(statuslineData: data) {
            liveState = parsed
        }
    }

    func refreshUsage() async {
        lastEndpointFetch = Date()
        if let parsed = try? await ClaudeUsageEndpointClient.fetchUsage() {
            usage = parsed
            usageIsStale = false
        } else {
            usageIsStale = true
        }
    }

    // MARK: - Controls

    /// The model to show as selected (live session value, else the configured setting).
    var currentModel: String? { liveState.modelDisplayName ?? settingsStore.read()?.model }
    /// The effort to show as selected (live session value, else the configured setting).
    var currentEffort: String? { liveState.effortLevel ?? settingsStore.read()?.effort }

    func setModel(_ model: String) {
        try? settingsStore.update(model: model, effort: nil)
        session?.restart() // soft-restart: `claude --continue` picks up the new model, no visible command
    }

    func setEffort(_ effort: String) {
        try? settingsStore.update(model: nil, effort: effort)
        session?.restart() // soft-restart: `claude --continue` picks up the new effort
    }
}
