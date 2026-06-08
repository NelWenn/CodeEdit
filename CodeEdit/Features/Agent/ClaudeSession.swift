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
