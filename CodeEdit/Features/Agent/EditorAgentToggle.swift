//
//  EditorAgentToggle.swift
//  CodeEdit
//

import SwiftUI

/// Toolbar segmented control that switches the workspace between Editor and Agent modes.
struct EditorAgentToggle: View {
    @EnvironmentObject private var workspace: WorkspaceDocument

    var body: some View {
        Picker(
            "Editor or Agent",
            selection: Binding(
                get: { workspace.workspaceMode },
                set: { workspace.workspaceMode = $0 }
            )
        ) {
            ForEach(WorkspaceMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}
