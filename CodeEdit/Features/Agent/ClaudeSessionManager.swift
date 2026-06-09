//
//  ClaudeSessionManager.swift
//  CodeEdit
//

import Combine
import Foundation

/// Owns the open Claude tabs for a workspace. Each tab is a ``ClaudeSession``.
final class ClaudeSessionManager: ObservableObject {
    enum OpenMode { case currentTab, newTab }

    @Published private(set) var tabs: [ClaudeSession] = []
    @Published var activeTabID: UUID?

    /// Re-publishes each child session's changes (title/generation) as our own.
    private var cancellables: [UUID: AnyCancellable] = [:]

    /// The active session (falls back to the first tab if the id is stale).
    var activeSession: ClaudeSession? {
        tabs.first { $0.id == activeTabID } ?? tabs.first
    }

    /// Open session ids in tab order (for persistence).
    var openSessionIds: [String] { tabs.map(\.claudeSessionId) }

    /// Index of the active tab (for persistence).
    var activeIndex: Int {
        guard let activeTabID, let idx = tabs.firstIndex(where: { $0.id == activeTabID }) else { return 0 }
        return idx
    }

    /// Ensure there is at least one tab (called when entering Agent mode).
    func ensureAtLeastOneTab() {
        if tabs.isEmpty { newTab() }
    }

    @discardableResult
    func newTab(resuming claudeId: String? = nil, title: String? = nil) -> ClaudeSession {
        let session = claudeId.map { ClaudeSession(resuming: $0, title: title ?? "Session") }
            ?? ClaudeSession(title: title ?? "New Session")
        track(session)
        tabs.append(session)
        activeTabID = session.id
        return session
    }

    func activate(_ id: UUID) { activeTabID = id }

    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs[idx].terminate()
        cancellables[id] = nil
        tabs.remove(at: idx)
        if activeTabID == id {
            let newIdx = min(idx, tabs.count - 1)
            activeTabID = tabs.indices.contains(newIdx) ? tabs[newIdx].id : nil
        }
        if tabs.isEmpty { newTab() }   // Agent mode always keeps ≥1 tab
    }

    /// Open a session from the list. Activates an already-open tab rather than launching a
    /// second process on the same `.jsonl`.
    func open(claudeId: String, title: String, mode: OpenMode, model: String?, effort: String?) {
        if let existing = tabs.first(where: { $0.claudeSessionId == claudeId }) {
            activeTabID = existing.id
            return
        }
        switch mode {
        case .newTab:
            newTab(resuming: claudeId, title: title).prepareLaunch(model: model, effort: effort)
        case .currentTab:
            guard let active = activeSession, let idx = tabs.firstIndex(where: { $0.id == active.id }) else {
                newTab(resuming: claudeId, title: title).prepareLaunch(model: model, effort: effort)
                return
            }
            active.terminate()
            cancellables[active.id] = nil
            let replacement = ClaudeSession(resuming: claudeId, title: title)
            replacement.prepareLaunch(model: model, effort: effort)
            track(replacement)
            tabs[idx] = replacement
            activeTabID = replacement.id
        }
    }

    /// Rebuild tabs from persisted state (each becomes a resuming tab).
    func restore(sessions: [(id: String, title: String)], activeIndex: Int) {
        tabs.forEach { $0.terminate() }
        cancellables.removeAll()
        tabs = sessions.map { entry in
            let session = ClaudeSession(resuming: entry.id, title: entry.title)
            track(session)
            return session
        }
        if tabs.isEmpty { newTab() }
        let idx = tabs.indices.contains(activeIndex) ? activeIndex : 0
        activeTabID = tabs[idx].id
    }

    private func track(_ session: ClaudeSession) {
        cancellables[session.id] = session.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }
}
