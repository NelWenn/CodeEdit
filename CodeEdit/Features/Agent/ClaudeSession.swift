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
    /// The Claude session UUID this tab runs (the `.jsonl` filename stem).
    let claudeSessionId: String
    /// Tab label, shown in the tab bar.
    @Published private(set) var title: String
    /// Bumped on restart so the SwiftUI Agent view recreates the terminal.
    @Published private(set) var generation = 0

    private var terminalView: CELocalShellTerminalView?
    private var hasLaunchedClaude = false
    /// Model/effort to force on the next launch (e.g. resuming with the current settings).
    private var relaunchModel: String?
    private var relaunchEffort: String?
    private let reader = ClaudeSessionsReader()

    /// A fresh session with a newly-generated Claude session id.
    init(title: String = "New Session") {
        self.claudeSessionId = UUID().uuidString.lowercased()
        self.title = title
    }

    /// A session bound to an existing Claude session id (resumed from the list or restored).
    init(resuming claudeSessionId: String, title: String) {
        self.claudeSessionId = claudeSessionId
        self.title = title
    }

    func setTitle(_ newTitle: String) {
        guard newTitle != title else { return }
        title = newTitle
    }

    /// Set the model/effort to apply on the next (first) launch, without relaunching now.
    func prepareLaunch(model: String?, effort: String?) {
        relaunchModel = model
        relaunchEffort = effort
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
        let resume = sessionFileExists(workspaceURL: workspaceURL)
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
