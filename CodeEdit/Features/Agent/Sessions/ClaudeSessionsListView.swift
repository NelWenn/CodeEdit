//
//  ClaudeSessionsListView.swift
//  CodeEdit
//

import SwiftUI

/// Lists the project's past Claude sessions. Clicking opens in the current tab; the context
/// menu offers a new tab. Defaults to the current tab. Styled like CodeEdit's navigator: a
/// sidebar list with a bottom action/filter toolbar.
struct ClaudeSessionsListView: View {
    @ObservedObject var manager: ClaudeSessionManager
    let workspaceURL: URL?

    @State private var sessions: [ClaudeSessionInfo] = []
    @State private var query: String = ""

    private let settingsStore = ClaudeSettingsStore()

    private var filtered: [ClaudeSessionInfo] {
        guard !query.isEmpty else { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            if filtered.isEmpty {
                CEContentUnavailableView(sessions.isEmpty ? "No Sessions" : "No Matches")
            } else {
                List {
                    ForEach(filtered) { session in
                        row(session)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private func row(_ session: ClaudeSessionInfo) -> some View {
        let isOpen = manager.tabs.contains { $0.claudeSessionId == session.id }
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
            if isOpen {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .help("Open in a tab")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { open(session, mode: .currentTab) }
        .contextMenu {
            Button("Open in Current Tab") { open(session, mode: .currentTab) }
            Button("Open in New Tab") { open(session, mode: .newTab) }
        }
    }

    /// Bottom toolbar styled like CodeEdit's navigator/utility pane toolbars.
    private var bottomBar: some View {
        HStack(spacing: 2) {
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
            Divider().frame(height: 14).padding(.horizontal, 3)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            TextField("Filter", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
        }
        .buttonStyle(.icon(size: 24))
        .padding(.horizontal, 5)
        .padding(.vertical, 6)
        .frame(height: 28)
        .background(EffectView(.contentBackground))
        .overlay(alignment: .top) { Divider() }
    }

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
