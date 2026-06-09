//
//  ClaudeSession.swift
//  CodeEdit
//

import AppKit
import SwiftTerm

/// Owns the long-lived `claude` terminal for a workspace so the session survives
/// toggling between Editor and Agent modes.
final class ClaudeSession: ObservableObject {
    private var terminalView: CELocalShellTerminalView?
    private var hasLaunchedClaude = false

    /// Returns the existing terminal view, or creates one rooted at `workspaceURL`,
    /// starts the login shell, and launches the Claude Code CLI inside it.
    func makeOrReuseTerminal(workspaceURL: URL?) -> CELocalShellTerminalView {
        if let terminalView {
            return terminalView
        }
        let view = CELocalShellTerminalView(frame: .zero)
        view.startProcess(workspaceURL: workspaceURL)
        terminalView = view
        launchClaudeIfNeeded(in: view)
        return view
    }

    /// Whether the claude process is currently running.
    var isRunning: Bool { terminalView?.process.running ?? false }

    /// Sends raw text (e.g. a slash command) to the running claude TUI.
    func send(_ text: String) {
        guard let view = terminalView, view.process.running else { return }
        view.process.send(data: Array(text.utf8)[...])
    }

    /// Restarts the claude session in place, continuing the same conversation. Used after a
    /// model/effort change (already written to `~/.claude/settings.json`) so the new setting
    /// takes effect — `claude --continue` re-reads settings.json and resumes the conversation.
    func restart() {
        guard let view = terminalView, view.process.running else { return }
        let interrupt: [UInt8] = [0x03] // Ctrl-C
        view.process.send(data: interrupt[...]) // clear/interrupt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak view] in
            view?.process.send(data: interrupt[...]) // second Ctrl-C quits the claude TUI
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak view] in
            guard let view, view.process.running else { return }
            view.process.send(data: Array("claude --continue\n".utf8)[...])
        }
    }

    private func launchClaudeIfNeeded(in view: CELocalShellTerminalView) {
        guard !hasLaunchedClaude else { return }
        hasLaunchedClaude = true
        // Let the login shell finish initializing (PATH, rc files) before running claude.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak view] in
            guard let view, view.process.running else { return }
            view.process.send(data: Array("claude\n".utf8)[...])
        }
    }
}
