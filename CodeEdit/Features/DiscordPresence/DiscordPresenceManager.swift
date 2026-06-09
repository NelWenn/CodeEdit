//
//  DiscordPresenceManager.swift
//  CodeEdit
//

import AppKit
import Combine

/// Shared, app-wide Discord Rich Presence. Observes the frontmost workspace and pushes a
/// folder-only activity to Discord while the setting is enabled and Discord is running.
@MainActor
final class DiscordPresenceManager {
    static let shared = DiscordPresenceManager(clientID: "1513992493396525148")

    private let clientID: String
    private var client: DiscordRPCClient?
    private var loopTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var keyWindowObserver: AnyCancellable?
    private var startedAt = Int(Date().timeIntervalSince1970)
    private(set) var isRunning = false

    init(clientID: String) {
        self.clientID = clientID
    }

    /// Start presence if the setting is enabled (called at app launch).
    func start() {
        guard !isRunning, Settings[\.general].discordRichPresenceEnabled else { return }
        isRunning = true
        startedAt = Int(Date().timeIntervalSince1970)
        keyWindowObserver = NotificationCenter.default
            .publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { [weak self] _ in self?.scheduleUpdate() }
        runLoop()
    }

    /// Tear down presence and clear the Discord activity.
    func stop() {
        isRunning = false
        loopTask?.cancel(); loopTask = nil
        debounceTask?.cancel(); debounceTask = nil
        keyWindowObserver = nil
        client?.setActivity(nil)
        client?.close()
        client = nil
    }

    /// Re-evaluate the enabled setting (call when the toggle changes).
    func settingChanged() {
        if Settings[\.general].discordRichPresenceEnabled {
            start()
        } else {
            stop()
        }
    }

    // MARK: - Internals

    /// Reconnects if needed and refreshes the activity every 10s (also catches branch/file changes).
    private func runLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                if !(self.client?.isConnected ?? false) {
                    let candidate = DiscordRPCClient(clientID: self.clientID)
                    self.client = candidate.connect() ? candidate : nil
                }
                self.update()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    private func scheduleUpdate() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            self?.update()
        }
    }

    private func update() {
        guard isRunning, Settings[\.general].discordRichPresenceEnabled else { return }
        client?.setActivity(DiscordPresenceBuilder.build(currentContext()))
    }

    private func currentContext() -> DiscordPresenceContext {
        let workspace = (NSApp.keyWindow?.windowController as? CodeEditWindowController)?.workspace
            ?? NSDocumentController.shared.currentDocument as? WorkspaceDocument
        let folder = workspace?.fileURL?.lastPathComponent ?? workspace?.displayName
        let branch = workspace?.sourceControlManager?.currentBranch?.name
        let isEditing = workspace?.editorManager?.activeEditor.selectedTab != nil
        return DiscordPresenceContext(
            folder: folder,
            branch: branch,
            isEditing: isEditing,
            startTimestamp: startedAt
        )
    }
}
