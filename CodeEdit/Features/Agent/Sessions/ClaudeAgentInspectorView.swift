//
//  ClaudeAgentInspectorView.swift
//  CodeEdit
//

import SwiftUI

/// The Agent-mode inspector: a native icon tab bar switching between the live Info panel and the
/// project's session list. Translucent (behind-window) background like the project navigator, with
/// the tab bar laid out above the content (not as a scroll inset) so content never bleeds into it.
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
        VStack(spacing: 0) {
            tabBar
            Divider()
            Group {
                switch selection {
                case .info:
                    ClaudeInfoInspectorView(model: infoModel)
                case .sessions:
                    ClaudeSessionsListView(manager: manager, workspaceURL: workspaceURL)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Translucent material like the navigator (left sidebar): blurs the desktop behind the
        // window, and being behind-window it does not show the in-window content scrolling under it.
        .background(EffectView(.sidebar, blendingMode: .behindWindow).ignoresSafeArea())
    }

    /// Icon tab bar with no opaque fill — it shows the translucent material behind it, so it is the
    /// exact same colour as the panel background.
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
    }
}
