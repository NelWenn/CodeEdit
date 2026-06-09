//
//  CodeEditSplitViewController.swift
//  CodeEdit
//
//  Created by YAPRYNTSEV Aleksey on 31.12.2022.
//

import Cocoa
import SwiftUI

final class CodeEditSplitViewController: NSSplitViewController {
    static let minSidebarWidth: CGFloat = 200
    /// Compact upper bound for the navigator so it reads like a normal IDE sidebar
    /// rather than taking over the window.
    static let maxSidebarWidth: CGFloat = 400
    static let maxSnapWidth: CGFloat = snapWidth + 10
    static let snapWidth: CGFloat = 272
    static let minSnapWidth: CGFloat = snapWidth - 10

    private weak var workspace: WorkspaceDocument?
    private weak var navigatorViewModel: NavigatorAreaViewModel?
    private weak var windowRef: NSWindow?
    private unowned var hapticPerformer: NSHapticFeedbackPerformer
    private var saveNavigatorWorkItem: DispatchWorkItem?

    // MARK: - Initialization

    init(
        workspace: WorkspaceDocument,
        navigatorViewModel: NavigatorAreaViewModel,
        windowRef: NSWindow,
        hapticPerformer: NSHapticFeedbackPerformer = NSHapticFeedbackManager.defaultPerformer
    ) {
        self.workspace = workspace
        self.navigatorViewModel = navigatorViewModel
        self.windowRef = windowRef
        self.hapticPerformer = hapticPerformer
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let windowRef else {
            // swiftlint:disable:next line_length
            assertionFailure("No WindowRef found, not initialized properly or the window was dereferenced and the controller was not.")
            return
        }

        guard let workspace,
              let navigatorViewModel,
              let editorManager = workspace.editorManager,
              let statusBarViewModel = workspace.statusBarViewModel,
              let utilityAreaModel = workspace.utilityAreaModel,
              let taskManager = workspace.taskManager else {
            // swiftlint:disable:next line_length
            assertionFailure("Missing a workspace model: workspace=\(workspace == nil), navigator=\(navigatorViewModel == nil), editorManager=\(workspace?.editorManager == nil), statusBarModel=\(workspace?.statusBarViewModel == nil), utilityAreaModel=\(workspace?.utilityAreaModel == nil), taskManager=\(workspace?.taskManager == nil)")
            return
        }

        splitView.translatesAutoresizingMaskIntoConstraints = false

        let navigator = makeNavigator(view: SettingsInjector {
            NavigatorAreaView(workspace: workspace, viewModel: navigatorViewModel)
                .environmentObject(workspace)
                .environmentObject(editorManager)
        })

        addSplitViewItem(navigator)

        let workspaceView = SettingsInjector {
            WindowObserver(window: WindowBox(value: windowRef)) {
                WorkspaceView()
                    .environmentObject(workspace)
                    .environmentObject(editorManager)
                    .environmentObject(statusBarViewModel)
                    .environmentObject(utilityAreaModel)
                    .environmentObject(taskManager)
                    .environmentObject(workspace.undoRegistration)
            }
        }

        let mainContent = NSSplitViewItem(viewController: NSHostingController(rootView: workspaceView))
        mainContent.titlebarSeparatorStyle = .line
        mainContent.minimumThickness = 200

        addSplitViewItem(mainContent)

        let inspector = makeInspector(view: SettingsInjector {
            InspectorAreaView(viewModel: InspectorAreaViewModel())
                .environmentObject(workspace)
                .environmentObject(editorManager)
        })

        addSplitViewItem(inspector)
    }

    private func makeNavigator(view: some View) -> NSSplitViewItem {
        let navigator = NSSplitViewItem(sidebarWithViewController: NSHostingController(rootView: view))
        if #unavailable(macOS 26) {
            navigator.titlebarSeparatorStyle = .none
        }
        navigator.isSpringLoaded = true
        navigator.minimumThickness = Self.minSidebarWidth
        navigator.collapseBehavior = .useConstraints
        return navigator
    }

    private func makeInspector(view: some View) -> NSSplitViewItem {
        let inspector = NSSplitViewItem(inspectorWithViewController: NSHostingController(rootView: view))
        inspector.titlebarSeparatorStyle = .none
        inspector.minimumThickness = Self.minSidebarWidth
        inspector.maximumThickness = .greatestFiniteMagnitude
        inspector.collapseBehavior = .useConstraints
        inspector.isSpringLoaded = true
        return inspector
    }

    override func viewWillAppear() {
        super.viewWillAppear()

        guard let workspace else { return }

        // Restore the saved navigator width only if it's within sane bounds; ignore stale
        // oversized values (older builds could persist a runaway width) and fall back to the
        // compact default so the sidebar never reopens dominating the window.
        let savedWidth = workspace.getFromWorkspaceState(.splitViewWidth) as? CGFloat
        let navigatorWidth: CGFloat
        if let savedWidth, savedWidth <= Self.maxSidebarWidth {
            navigatorWidth = max(savedWidth, Self.minSidebarWidth)
        } else {
            navigatorWidth = Self.minSidebarWidth
        }
        splitView.setPosition(navigatorWidth, ofDividerAt: 0)

        if let firstSplitView = splitViewItems.first {
            firstSplitView.isCollapsed = workspace.getFromWorkspaceState(
                .navigatorCollapsed
            ) as? Bool ?? false
        }

        if let lastSplitView = splitViewItems.last {
            lastSplitView.isCollapsed = workspace.getFromWorkspaceState(
                .inspectorCollapsed
            ) as? Bool ?? true
        }

        workspace.notificationPanel.updateToolbarItem()
    }

    /// Clamp a navigator width to a sane range so a stale/oversized persisted value (e.g. a
    /// width saved during a transient layout) or an over-eager drag can't let the sidebar take
    /// over the window. The upper bound is half the split view's width, with a fixed fallback
    /// for when the view has not been laid out yet.
    private func clampedNavigatorWidth(_ width: CGFloat) -> CGFloat {
        let available = view.bounds.width
        // Cap at a compact absolute width on normal/large windows; fall back to half the
        // window on very narrow ones so the navigator can never dominate the layout.
        let fractionCap = available > 0 ? available / 2 : Self.maxSidebarWidth
        let upperBound = max(Self.minSidebarWidth, min(Self.maxSidebarWidth, fractionCap))
        return min(max(width, Self.minSidebarWidth), upperBound)
    }

    // MARK: - NSSplitViewDelegate

    /// Perform the spring loaded navigator splits.
    /// - Note: This could be removed. The only additional functionality this provides over using just the
    ///         `NSSplitViewItem.isSpringLoaded` & `NSSplitViewItem.minimumThickness` is the haptic feedback we add.
    /// - Parameters:
    ///   - splitView: The split view to use.
    ///   - proposedPosition: The proposed drag position.
    ///   - dividerIndex: The index of the divider being dragged.
    /// - Returns: The position to move the divider to.
    override func splitView(
        _ splitView: NSSplitView,
        constrainSplitPosition proposedPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        switch dividerIndex {
        case 0:
            // Navigator
            if (Self.minSnapWidth...Self.maxSnapWidth).contains(proposedPosition) {
                return Self.snapWidth
            } else if proposedPosition <= Self.minSidebarWidth / 2 {
                hapticCollapse(splitViewItems.first, collapseAction: true)
                return 0
            } else {
                hapticCollapse(splitViewItems.first, collapseAction: false)
                return clampedNavigatorWidth(proposedPosition)
            }
        case 1:
            let proposedWidth = view.frame.width - proposedPosition
            if proposedWidth <= Self.minSidebarWidth / 2 {
                hapticCollapse(splitViewItems.last, collapseAction: true)
                return proposedPosition
            } else {
                hapticCollapse(splitViewItems.last, collapseAction: false)
                return min(view.frame.width - Self.minSidebarWidth, proposedPosition)
            }
        default:
            return proposedPosition
        }
    }

    /// Performs a haptic feedback while collapsing or revealing a split item.
    /// If the item was not previously in the new intended state, a haptic `.alignment` feedback is sent.
    /// - Parameters:
    ///   - item: The item to collapse or reveal
    ///   - collapseAction: Whether or not to collapse the item. Set to true to collapse it.
    private func hapticCollapse(_ item: NSSplitViewItem?, collapseAction: Bool) {
        if item?.isCollapsed == !collapseAction {
            hapticPerformer.perform(.alignment, performanceTime: .now)
        }
        item?.isCollapsed = collapseAction
    }

    /// Save the width of the inspector and navigator between sessions.
    override func splitViewDidResizeSubviews(_ notification: Notification) {
        super.splitViewDidResizeSubviews(notification)
        // Debounced save: persist 0.4s after resizing settles. Transient widths during a
        // window-resize / minimize are superseded by the final stable value, and this does not
        // depend on the `NSSplitViewDividerIndex` userInfo key (unreliable on macOS 26+), so the
        // user's chosen width is actually captured.
        saveNavigatorWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNavigatorWidth() }
        saveNavigatorWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    /// Persist the navigator's current (stable) width if it's a sane value.
    private func saveNavigatorWidth() {
        guard let navigatorItem = splitViewItems.first, !navigatorItem.isCollapsed,
              let navigatorView = splitView.subviews.first else { return }
        let width = navigatorView.frame.size.width
        if width >= Self.minSidebarWidth && width <= Self.maxSidebarWidth {
            workspace?.addToWorkspaceState(key: .splitViewWidth, value: width)
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        // Belt-and-suspenders: capture the final width on close/minimize too.
        saveNavigatorWidth()
    }

    func saveNavigatorCollapsedState(isCollapsed: Bool) {
        workspace?.addToWorkspaceState(key: .navigatorCollapsed, value: isCollapsed)
    }

    func saveInspectorCollapsedState(isCollapsed: Bool) {
        workspace?.addToWorkspaceState(key: .inspectorCollapsed, value: isCollapsed)
    }
}
