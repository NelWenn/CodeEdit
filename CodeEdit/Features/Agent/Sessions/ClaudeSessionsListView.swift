//
//  ClaudeSessionsListView.swift
//  CodeEdit
//

import SwiftUI

/// Lists the project's past Claude sessions. Clicking opens in the current tab; the context
/// menu offers a new tab. Defaults to the current tab.
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
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search sessions", text: $query)
                    .textFieldStyle(.plain)
                Button {
                    manager.newTab()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
                .help("New session")
                Button {
                    reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }
            .padding(8)
            Divider()
            if filtered.isEmpty {
                Spacer()
                Text(sessions.isEmpty ? "No sessions yet" : "No matches")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List(filtered) { session in
                    row(session)
                }
                .listStyle(.sidebar)
            }
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private func row(_ session: ClaudeSessionInfo) -> some View {
        let isOpen = manager.tabs.contains { $0.claudeSessionId == session.id }
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(session.title).lineLimit(1)
                if isOpen {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.green)
                }
            }
            Text(session.lastModified.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { open(session, mode: .currentTab) }
        .contextMenu {
            Button("Open in Current Tab") { open(session, mode: .currentTab) }
            Button("Open in New Tab") { open(session, mode: .newTab) }
        }
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
