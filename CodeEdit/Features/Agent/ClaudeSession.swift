//
//  ClaudeSession.swift
//  CodeEdit
//

import AppKit
import SwiftTerm

/// Owns one long-lived `claude` terminal for a single Agent tab. The session survives toggling
/// between Editor and Agent modes and switching between tabs (the process runs independently of
/// view attachment).
final class ClaudeSession: ObservableObject, Identifiable {
    /// Stable tab identity (for SwiftUI `id()` and manager lookup).
    let id = UUID()
    /// The Claude session UUID this tab runs (the `.jsonl` filename stem). Mutable because a fresh
    /// session relaunched before it has any conversation is restarted under a new id (see
    /// `launchClaudeIfNeeded`).
    private(set) var claudeSessionId: String
    /// Tab label, shown in the tab bar.
    @Published private(set) var title: String
    /// Bumped on restart so the SwiftUI Agent view recreates the terminal.
    @Published private(set) var generation = 0

    /// Set once the user renames the tab, so auto-naming stops overriding their choice.
    private var isManuallyTitled = false
    /// True when this tab was opened from an existing on-disk session (list/restore), so it must
    /// always `--resume` its id rather than ever minting a new one.
    private let isResuming: Bool

    private var terminalView: CELocalShellTerminalView?
    private var hasLaunchedClaude = false
    /// True once `claude` has been launched at least once for this tab (used to decide between
    /// resuming and starting fresh on a model/effort change).
    private var hasEverLaunched = false
    /// Model/effort to force on the next launch (e.g. resuming with the current settings).
    private var relaunchModel: String?
    private var relaunchEffort: String?
    private let reader = ClaudeSessionsReader()

    /// A fresh session with a newly-generated Claude session id.
    init(title: String = "New Session") {
        self.claudeSessionId = UUID().uuidString.lowercased()
        self.title = title
        self.isResuming = false
    }

    /// A session bound to an existing Claude session id (resumed from the list or restored).
    init(resuming claudeSessionId: String, title: String) {
        self.claudeSessionId = claudeSessionId
        self.title = title
        self.isResuming = true
    }

    /// Set the model/effort to apply on the next (first) launch, without relaunching now.
    func prepareLaunch(model: String?, effort: String?) {
        relaunchModel = model
        relaunchEffort = effort
    }

    // MARK: - Title

    /// Whether auto-naming may still update this tab's title (false once the user renames it).
    var canAutoTitle: Bool { !isManuallyTitled }

    /// Rename the tab explicitly (from the UI). Pins the title against auto-naming.
    func rename(to newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isManuallyTitled = true
        if trimmed != title { title = trimmed }
    }

    /// Apply a title derived from the conversation subject, unless the user has renamed the tab.
    func applyAutoTitle(_ newTitle: String) {
        guard !isManuallyTitled, newTitle != title else { return }
        title = newTitle
    }

    /// Returns the existing terminal view, or creates one rooted at `workspaceURL`, starts the
    /// login shell, and launches `claude` (fresh or resuming this tab's session).
    func makeOrReuseTerminal(workspaceURL: URL?) -> CELocalShellTerminalView {
        if let terminalView { return terminalView }
        let view = CELocalShellTerminalView(frame: .zero)
        view.startProcess(workspaceURL: workspaceURL)
        terminalView = view
        launchClaudeIfNeeded(in: view, workspaceURL: workspaceURL)
        return view
    }

    /// Whether the claude process is currently running.
    var isRunning: Bool { terminalView?.process.running ?? false }

    /// Sends raw text (e.g. a slash command) to the running claude TUI.
    func send(_ text: String) {
        guard let view = terminalView, view.process.running else { return }
        view.process.send(data: Array(text.utf8)[...])
    }

    /// Relaunch this tab (e.g. after a model/effort change), resuming the same conversation.
    func restart(model: String?, effort: String?) {
        relaunchModel = model
        relaunchEffort = effort
        terminalView?.process.terminate()
        terminalView = nil
        hasLaunchedClaude = false
        generation += 1
    }

    /// Terminate this tab's process (on tab close). The session stays on disk and is resumable.
    func terminate() {
        terminalView?.process.terminate()
        terminalView = nil
    }

    private func launchClaudeIfNeeded(in view: CELocalShellTerminalView, workspaceURL: URL?) {
        guard !hasLaunchedClaude else { return }
        hasLaunchedClaude = true
        let resume: Bool
        if isResuming || sessionFileExists(workspaceURL: workspaceURL) {
            // A real conversation exists on disk (opened from the list/restored, or this tab has
            // already exchanged messages) → resume it.
            resume = true
        } else if hasEverLaunched {
            // Launched before but it never produced a conversation — e.g. the model/effort was
            // changed before the first message. The id is already registered, so reusing
            // `--session-id` would collide and `--resume` has nothing to resume ("No conversation
            // found with session ID"). Start fresh under a new id — nothing was said, nothing lost.
            claudeSessionId = UUID().uuidString.lowercased()
            resume = false
        } else {
            // First-ever launch of a brand-new session.
            resume = false
        }
        hasEverLaunched = true
        let command = Self.launchCommand(
            sessionId: claudeSessionId,
            resume: resume,
            model: relaunchModel,
            effort: relaunchEffort
        ) + "\n"
        // Let the login shell finish initializing (PATH, rc files) before running claude.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak view] in
            guard let view, view.process.running else { return }
            view.process.send(data: Array(command.utf8)[...])
        }
    }

    /// True when this tab's session already has a `.jsonl` on disk (so we `--resume` it rather
    /// than starting it with `--session-id`).
    private func sessionFileExists(workspaceURL: URL?) -> Bool {
        guard let workspaceURL else { return false }
        let file = reader.sessionsDirectory(for: workspaceURL)
            .appendingPathComponent("\(claudeSessionId).jsonl")
        return FileManager.default.fileExists(atPath: file.path(percentEncoded: false))
    }
}

extension ClaudeSession {
    /// Builds the shell command that launches `claude` for one tab.
    /// - `resume == false` → start a new session with a known id (`--session-id`).
    /// - `resume == true`  → resume an existing session (`--resume`).
    /// `--continue`/`--resume` keep a conversation's model/effort, so pass them explicitly when set.
    static func launchCommand(sessionId: String, resume: Bool, model: String?, effort: String?) -> String {
        var command = "claude"
        command += resume ? " --resume \(sessionId)" : " --session-id \(sessionId)"
        if let model, !model.isEmpty { command += " --model \(model)" }
        if let effort, !effort.isEmpty {
            if effort == "ultracode" {
                // `ultracode` is not a --effort value (claude rejects it); it's a session setting
                // (xhigh effort + dynamic-workflow orchestration) enabled via --settings.
                command += " --settings '{\"ultracode\": true}'"
            } else {
                command += " --effort \(effort)"
            }
        }
        return command
    }
}
