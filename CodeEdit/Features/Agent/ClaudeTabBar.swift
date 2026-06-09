//
//  ClaudeTabBar.swift
//  CodeEdit
//

import SwiftUI

/// Tab strip atop the Agent area, styled exactly like CodeEdit's editor tab bar: on macOS 26+
/// the tabs are Liquid Glass capsules (reusing `EditorTabBackground` / `GlassEffectView`), with a
/// trailing `+` to open a new session.
struct ClaudeTabBar: View {
    @ObservedObject var manager: ClaudeSessionManager

    /// Height of the bar, matching the editor tab bar.
    private static let height: CGFloat = 28

    @State private var hoveredTab: UUID?

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
        HStack(spacing: 0) {
            if !Bool.tahoe {
                EditorTabDivider().opacity(isActive ? 0 : 1)
            }
            ZStack {
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
        .onTapGesture { manager.activate(session.id) }
        .onHover { hovering in
            hoveredTab = hovering ? session.id : (hoveredTab == session.id ? nil : hoveredTab)
        }
    }
}
