//
//  CodeEditWindowController+Toolbar.swift
//  CodeEdit
//
//  Created by Daniel Zhu on 5/10/24.
//

import AppKit
import SwiftUI
import Combine

extension CodeEditWindowController {
    internal func setupToolbar() {
        let toolbar = NSToolbar(identifier: UUID().uuidString)
        toolbar.delegate = self
        toolbar.showsBaselineSeparator = false
        self.window?.titleVisibility = toolbarCollapsed ? .visible : .hidden
        if #available(macOS 26, *) {
            self.window?.toolbarStyle = .automatic
            toolbar.centeredItemIdentifiers = [.spotifyPlayer]
            toolbar.displayMode = .iconOnly
            self.window?.titlebarAppearsTransparent = true
        } else {
            self.window?.toolbarStyle = .unifiedCompact
            toolbar.displayMode = .labelOnly
        }
        self.window?.titlebarSeparatorStyle = .automatic
        self.window?.toolbar = toolbar
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let items: [NSToolbarItem.Identifier] = [
            .toggleFirstSidebarItem,
            .flexibleSpace,
            .sidebarTrackingSeparator,
            .branchPicker,
            .flexibleSpace,
            .spotifyPlayer,
            .flexibleSpace,
            .itemListTrackingSeparator,
            .flexibleSpace,
            .editorAgentModeItem,
            .toggleLastSidebarItem
        ]
        return items
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        let items: [NSToolbarItem.Identifier] = [
            .toggleFirstSidebarItem,
            .sidebarTrackingSeparator,
            .flexibleSpace,
            .itemListTrackingSeparator,
            .toggleLastSidebarItem,
            .editorAgentModeItem,
            .branchPicker,
            .spotifyPlayer,
        ]

        return items
    }

    func toggleToolbar() {
        toolbarCollapsed.toggle()
        workspace?.addToWorkspaceState(key: .toolbarCollapsed, value: toolbarCollapsed)
        updateToolbarVisibility()
    }

    func updateToolbarVisibility() {
        if toolbarCollapsed {
            window?.titleVisibility = .visible
            window?.title = workspace?.workspaceFileManager?.folderUrl.lastPathComponent ?? "Empty"
            window?.toolbar = nil
        } else {
            window?.titleVisibility = .hidden
            setupToolbar()
        }
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .itemListTrackingSeparator:
            guard let splitViewController else { return nil }

            return NSTrackingSeparatorToolbarItem(
                identifier: .itemListTrackingSeparator,
                splitView: splitViewController.splitView,
                dividerIndex: 1
            )
        case .toggleFirstSidebarItem:
            let toolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.toggleFirstSidebarItem)
            toolbarItem.paletteLabel = " Navigator Sidebar"
            toolbarItem.toolTip = "Hide or show the Navigator"
            toolbarItem.isBordered = true
            toolbarItem.target = self
            toolbarItem.action = #selector(self.objcToggleFirstPanel)
            toolbarItem.image = NSImage(
                systemSymbolName: "sidebar.leading",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(.init(scale: .large))

            return toolbarItem
        case .toggleLastSidebarItem:
            let toolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier.toggleLastSidebarItem)
            toolbarItem.paletteLabel = "Inspector Sidebar"
            toolbarItem.toolTip = "Hide or show the Inspectors"
            toolbarItem.isBordered = true
            toolbarItem.target = self
            toolbarItem.action = #selector(self.objcToggleLastPanel)
            toolbarItem.image = NSImage(
                systemSymbolName: "sidebar.trailing",
                accessibilityDescription: nil
            )?.withSymbolConfiguration(.init(scale: .large))

            return toolbarItem
        case .branchPicker:
            let toolbarItem = NSToolbarItem(itemIdentifier: .branchPicker)
            let view = NSHostingView(
                rootView: ToolbarBranchPicker(
                    workspaceFileManager: workspace?.workspaceFileManager
                )
            )
            toolbarItem.view = view
            toolbarItem.isBordered = false
            return toolbarItem
        case .spotifyPlayer:
            return spotifyPlayerItem()
        case .editorAgentModeItem:
            return editorAgentModeItem()
        default:
            return NSToolbarItem(itemIdentifier: itemIdentifier)
        }
    }

    private func spotifyPlayerItem() -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: .spotifyPlayer)
        toolbarItem.visibilityPriority = .user
        let view = NSHostingView(rootView: SpotifyPlayerView())
        let lowWidth = view.widthAnchor.constraint(equalToConstant: 540)
        lowWidth.priority = .defaultLow
        let minWidth = view.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        minWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([lowWidth, minWidth])
        toolbarItem.view = view
        return toolbarItem
    }

    private func editorAgentModeItem() -> NSToolbarItem? {
        let toolbarItem = NSToolbarItem(itemIdentifier: .editorAgentModeItem)
        toolbarItem.paletteLabel = "Editor / Agent"
        toolbarItem.toolTip = "Switch between the editor and the Claude agent"
        guard let workspace else { return nil }
        let view = NSHostingView(rootView: EditorAgentToggle().environmentObject(workspace))
        toolbarItem.view = view
        return toolbarItem
    }
}
