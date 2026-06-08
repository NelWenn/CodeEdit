//
//  WorkspaceMode.swift
//  CodeEdit
//

import Foundation

/// Whether the workspace's central area shows the code editor or the Claude agent.
enum WorkspaceMode: String, CaseIterable, Identifiable {
    case editor
    case agent

    var id: Self { self }

    var title: String {
        switch self {
        case .editor: return "Editor"
        case .agent: return "Agent"
        }
    }

    var systemImage: String {
        switch self {
        case .editor: return "doc.text"
        case .agent: return "sparkles"
        }
    }
}
