//
//  ClaudeTabBar.swift
//  CodeEdit
//

import SwiftUI

/// Tab strip atop the Agent area, styled exactly like CodeEdit's editor tab bar: on macOS 26+
/// the tabs are Liquid Glass capsules (reusing `EditorTabBackground` / `GlassEffectView`), with a
/// trailing `+` to open a new session. Tabs can be renamed (double-click or the context menu).
struct ClaudeTabBar: View {
    @ObservedObject var manager: ClaudeSessionManager

    /// Height of the bar, matching the editor tab bar.
    private static let height: CGFloat = 28
    /// Max delay between two clicks on the same tab to count as a rename double-click.
    private static let doubleClickInterval: TimeInterval = 0.4

    @State private var hoveredTab: UUID?
    @State private var editingTab: UUID?
    @State private var draftTitle: String = ""
    @State private var lastClickTab: UUID?
    @State private var lastClickAt: Date?
    @FocusState private var renameFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Bool.tahoe ? 4 : 0) {
                    ForEach(manager.tabs) { session in
                        tab(session)
                    }
                }
                .padding(Bool.tahoe ? 3 : 0)
            }
            .if(.tahoe) {
                if #available(macOS 26.0, *) {
#if compiler(>=6.2)
                    $0.background(GlassEffectView(tintColor: .tertiarySystemFill))
                        .clipShape(Capsule())
                        .clipped()
#else
                    $0
#endif
                }
            }

            Button {
                manager.newTab()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.icon(size: Self.height))
            .help("New Claude session")
        }
        .frame(height: Self.height)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .environment(\.isActiveEditor, true)
    }

    @ViewBuilder
    private func tab(_ session: ClaudeSession) -> some View {
        let isActive = manager.activeTabID == session.id
        let isHovering = hoveredTab == session.id
        let isEditing = editingTab == session.id
        HStack(spacing: 0) {
            if !Bool.tahoe {
                EditorTabDivider().opacity(isActive ? 0 : 1)
            }
            ZStack {
                if isEditing {
                    TextField("Session name", text: $draftTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .multilineTextAlignment(.center)
                        .focused($renameFieldFocused)
                        .onSubmit { commitRename(session) }
                        .onExitCommand { editingTab = nil }
                        .onChange(of: renameFieldFocused) { _, focused in
                            if !focused, editingTab == session.id { commitRename(session) }
                        }
                        .padding(.horizontal, 10)
                } else {
                    Text(session.title)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 22)
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
            }
            .frame(width: 140)
            if !Bool.tahoe {
                EditorTabDivider().opacity(isActive ? 0 : 1)
            }
        }
        .frame(height: Self.height)
        .foregroundStyle(isActive ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .background {
            EditorTabBackground(isActive: isActive, isPressing: false, isDragging: false)
        }
        .if(.tahoe) {
            if #available(macOS 26, *) {
                $0.clipShape(Capsule()).clipped().containerShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap(session) }
        .contextMenu {
            Button("Rename") { beginRename(session) }
            Button("Close") { manager.closeTab(session.id) }
        }
        .onHover { hovering in
            hoveredTab = hovering ? session.id : (hoveredTab == session.id ? nil : hoveredTab)
        }
    }

    /// Single click activates immediately (no gesture delay); a second click on the same tab
    /// within `doubleClickInterval` starts a rename — matching Finder/browser-tab behavior.
    private func handleTap(_ session: ClaudeSession) {
        if let editingTab {
            if editingTab != session.id { manager.activate(session.id) }   // commit happens on blur
            return
        }
        let now = Date()
        if lastClickTab == session.id, let last = lastClickAt, now.timeIntervalSince(last) < Self.doubleClickInterval {
            beginRename(session)
            lastClickAt = nil
        } else {
            manager.activate(session.id)
            lastClickTab = session.id
            lastClickAt = now
        }
    }

    private func beginRename(_ session: ClaudeSession) {
        manager.activate(session.id)
        draftTitle = session.title
        editingTab = session.id
        DispatchQueue.main.async { renameFieldFocused = true }
    }

    private func commitRename(_ session: ClaudeSession) {
        manager.rename(session.id, to: draftTitle)
        editingTab = nil
    }
}
