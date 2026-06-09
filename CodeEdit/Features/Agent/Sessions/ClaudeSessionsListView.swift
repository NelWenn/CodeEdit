//
//  ClaudeSessionsListView.swift
//  CodeEdit
//

import SwiftUI

/// Lists the project's past Claude sessions, styled like CodeEdit's project navigator: a translucent
/// sidebar list with a bottom filter toolbar (`PaneTextField`). The session shown in the active tab
/// gets a clean Liquid Glass selection box. Clicking opens in the current tab; the context menu
/// offers a new tab.
struct ClaudeSessionsListView: View {
    @ObservedObject var manager: ClaudeSessionManager
    let workspaceURL: URL?

    @State private var sessions: [ClaudeSessionInfo] = []
    @State private var query: String = ""
    @State private var hoveredSession: String?

    private let settingsStore = ClaudeSettingsStore()

    private var filtered: [ClaudeSessionInfo] {
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if filtered.isEmpty {
                    CEContentUnavailableView(sessions.isEmpty ? "No Sessions" : "No Matches")
                } else {
                    List {
                        ForEach(filtered) { session in
                            row(session)
                                .listRowBackground(rowBackground(for: session))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
        .onAppear(perform: reload)
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ session: ClaudeSessionInfo) -> some View {
        let isOpen = manager.tabs.contains { $0.claudeSessionId == session.id }
        let isActive = session.id == manager.activeSession?.claudeSessionId
        HStack(spacing: 6) {
            Image(systemName: "bubble.left")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(session.lastModified.formatted(.relative(presentation: .named)))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            // A subtle dot marks sessions open in another tab (the active one gets the selection box).
            if isOpen && !isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .help("Open in another tab")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { open(session, mode: .currentTab) }
        .onHover { hovering in
            hoveredSession = hovering ? session.id : (hoveredSession == session.id ? nil : hoveredSession)
        }
        .contextMenu {
            Button("Open in Current Tab") { open(session, mode: .currentTab) }
            Button("Open in New Tab") { open(session, mode: .newTab) }
        }
    }

    /// The row background: a Liquid Glass selection box for the active session, a faint hover fill
    /// otherwise.
    @ViewBuilder
    private func rowBackground(for session: ClaudeSessionInfo) -> some View {
        let isActive = session.id == manager.activeSession?.claudeSessionId
        if isActive {
            selectionBox
        } else if hoveredSession == session.id {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
        }
    }

    /// A clean Liquid Glass selection box (macOS 26+), falling back to the system selection material.
    @ViewBuilder private var selectionBox: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        Group {
            if #available(macOS 26, *) {
                GlassEffectView(tintColor: .controlAccentColor)
            } else {
                EffectView(.selection, blendingMode: .withinWindow, emphasized: true)
            }
        }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(Color(nsColor: .controlAccentColor).opacity(0.45), lineWidth: 1)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
    }

    // MARK: - Bottom toolbar (mirrors ProjectNavigatorToolbarBottom)

    private var bottomBar: some View {
        HStack(spacing: 5) {
            Button {
                manager.newTab()
            } label: {
                Image(systemName: "plus")
            }
            .help("New session")
            Button {
                reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh sessions")
            PaneTextField(
                "Filter",
                text: $query,
                clearable: true,
                hasValue: !query.isEmpty
            )
        }
        .buttonStyle(.icon)
        .padding(.horizontal, 5)
        .frame(height: 28, alignment: .center)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Actions

    private func open(_ session: ClaudeSessionInfo, mode: ClaudeSessionManager.OpenMode) {
        let config = settingsStore.read()
        manager.open(
            claudeId: session.id,
            title: session.title,
            mode: mode,
            model: config?.model,
            effort: config?.effort
        )
    }

    private func reload() {
        sessions = ClaudeSessionsReader().readSessions(
            for: workspaceURL ?? FileManager.default.homeDirectoryForCurrentUser
        )
    }
}
