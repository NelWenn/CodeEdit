//
//  ClaudeAgentView.swift
//  CodeEdit
//

import SwiftUI
import SwiftTerm

/// Full-frame view hosting the `claude` CLI for Agent mode.
struct ClaudeAgentView: NSViewRepresentable {
    @ObservedObject var session: ClaudeSession
    let workspaceURL: URL?

    func makeNSView(context: Context) -> CELocalShellTerminalView {
        let view = session.makeOrReuseTerminal(workspaceURL: workspaceURL)
        view.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        return view
    }

    func updateNSView(_ nsView: CELocalShellTerminalView, context: Context) { }
}
