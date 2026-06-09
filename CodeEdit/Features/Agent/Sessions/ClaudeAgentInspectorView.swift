//
//  ClaudeAgentInspectorView.swift
//  CodeEdit
//

import SwiftUI

/// The Agent-mode inspector: a native icon tab bar (matching the rest of the inspector) switching
/// between the live Info panel and the project's session list.
struct ClaudeAgentInspectorView: View {
    @ObservedObject var infoModel: ClaudeInfoModel
    @ObservedObject var manager: ClaudeSessionManager
    let workspaceURL: URL?

    enum Tab: String, CaseIterable, Identifiable {
        case info
        case sessions

        var id: String { rawValue }

        var title: String {
            switch self {
            case .info: return "Info"
            case .sessions: return "Sessions"
            }
        }

        var systemImage: String {
            switch self {
            case .info: return "info.circle"
            case .sessions: return "bubble.left.and.bubble.right"
            }
        }
    }

    @State private var selection: Tab = .info

    var body: some View {
        Group {
            switch selection {
            case .info:
                ClaudeInfoInspectorView(model: infoModel)
            case .sessions:
                ClaudeSessionsListView(manager: manager, workspaceURL: workspaceURL)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                tabBar
                Divider()
            }
        }
    }

    /// Icon tab bar styled like the inspector's own `WorkspacePanelTabBar` (top position).
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 12.5))
                        .symbolVariant(selection == tab ? .fill : .none)
                        .help(tab.title)
                }
                .buttonStyle(.icon(isActive: selection == tab, size: 24))
                .focusable(false)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("ClaudeInspectorTab-\(tab.title)")
                .accessibilityLabel(tab.title)
            }
        }
        .frame(maxWidth: .infinity, idealHeight: 27)
        .fixedSize(horizontal: false, vertical: true)
        .background(EffectView(.headerView))
    }
}
