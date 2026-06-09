//
//  ClaudeAgentInspectorView.swift
//  CodeEdit
//

import SwiftUI

/// The Agent-mode inspector: a small segmented switcher between the live Info panel and the
/// project's session list.
struct ClaudeAgentInspectorView: View {
    @ObservedObject var infoModel: ClaudeInfoModel
    @ObservedObject var manager: ClaudeSessionManager
    let workspaceURL: URL?

    enum Tab: String, CaseIterable { case info = "Info", sessions = "Sessions" }
    @State private var tab: Tab = .info

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)
            Divider()
            switch tab {
            case .info:
                ClaudeInfoInspectorView(model: infoModel)
            case .sessions:
                ClaudeSessionsListView(manager: manager, workspaceURL: workspaceURL)
            }
        }
    }
}
