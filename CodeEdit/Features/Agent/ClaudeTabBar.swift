//
//  ClaudeTabBar.swift
//  CodeEdit
//

import SwiftUI

/// Tab strip shown atop the Agent area: one pill per open Claude session, plus a `+` to add one.
struct ClaudeTabBar: View {
    @ObservedObject var manager: ClaudeSessionManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(manager.tabs) { session in
                    tab(session)
                }
                Button {
                    manager.newTab()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("New Claude session")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .background(EffectView(.headerView))
    }

    @ViewBuilder
    private func tab(_ session: ClaudeSession) -> some View {
        let isActive = manager.activeTabID == session.id
        HStack(spacing: 6) {
            Text(session.title)
                .lineLimit(1)
                .font(.system(size: 11))
            Button {
                manager.closeTab(session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Close session")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(maxWidth: 180)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.25) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { manager.activate(session.id) }
    }
}
