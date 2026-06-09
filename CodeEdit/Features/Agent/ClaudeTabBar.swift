//
//  ClaudeTabBar.swift
//  CodeEdit
//

import SwiftUI

/// Tab strip atop the Agent area, styled like CodeEdit's editor tab bar: one tab per open Claude
/// session (active tab raised on the content material), plus a trailing `+` to open a new one.
struct ClaudeTabBar: View {
    @ObservedObject var manager: ClaudeSessionManager

    /// Height of the bar, matching the editor tab bar.
    private static let height: CGFloat = 28

    @State private var hoveredTab: UUID?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(manager.tabs) { session in
                        tab(session)
                    }
                }
            }
            Divider()
            Button {
                manager.newTab()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.icon(size: Self.height))
            .help("New Claude session")
        }
        .frame(height: Self.height)
        .background(EffectView(.headerView))
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func tab(_ session: ClaudeSession) -> some View {
        let isActive = manager.activeTabID == session.id
        let isHovering = hoveredTab == session.id
        HStack(spacing: 0) {
            ZStack {
                Text(session.title)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                HStack {
                    Button {
                        manager.closeTab(session.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .buttonStyle(.icon(size: 16))
                    .help("Close session")
                    .opacity(isActive || isHovering ? 1 : 0)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 4)
            }
            .frame(width: 150)
            Divider().opacity(isActive ? 0 : 1)
        }
        .frame(height: Self.height)
        .background {
            if isActive {
                EffectView(.contentBackground)
            } else if isHovering {
                Color(nsColor: .controlColor).opacity(0.4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { manager.activate(session.id) }
        .onHover { hovering in
            hoveredTab = hovering ? session.id : (hoveredTab == session.id ? nil : hoveredTab)
        }
    }
}
