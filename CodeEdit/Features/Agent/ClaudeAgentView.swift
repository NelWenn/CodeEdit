//
//  ClaudeAgentView.swift
//  CodeEdit
//

import SwiftUI
import SwiftTerm

/// Full-frame view hosting the `claude` CLI for Agent mode.
///
/// Themed to match the app's integrated terminal: a transparent background (so the
/// workspace material shows through, instead of raw black) and the selected theme's
/// colors. Mirrors the relevant parts of `TerminalEmulatorView.configureView`.
struct ClaudeAgentView: NSViewRepresentable {
    /// Observed so the terminal re-themes live when the user changes the theme.
    @ObservedObject private var themeModel: ThemeModel = .shared

    let session: ClaudeSession
    let workspaceURL: URL?

    func makeNSView(context: Context) -> CELocalShellTerminalView {
        let view = session.makeOrReuseTerminal(workspaceURL: workspaceURL)
        configure(view)
        return view
    }

    func updateNSView(_ nsView: CELocalShellTerminalView, context: Context) {
        configure(nsView)
    }

    // MARK: - Theming

    private var font: NSFont {
        let terminal = Settings.shared.preferences.terminal
        return terminal.useTextEditorFont
            ? Settings.shared.preferences.textEditing.font.current
            : terminal.font.current
    }

    /// Index of the active theme in `themeModel.themes`, honoring the dark-appearance setting.
    private var themeIndex: Int? {
        let useDark = Settings[\.theme].matchAppearance && Settings[\.terminal].darkAppearance
        guard let selected = useDark ? themeModel.selectedDarkTheme : themeModel.selectedTheme else {
            return nil
        }
        return themeModel.themes.firstIndex(of: selected)
    }

    private var ansiColors: [SwiftTerm.Color] {
        guard let index = themeIndex else { return [] }
        return themeModel.themes[index].terminal.ansiColors.map { SwiftTerm.Color(hex: $0) }
    }

    private var cursorColor: NSColor {
        guard let index = themeIndex else { return NSColor(.accentColor) }
        return NSColor(themeModel.themes[index].terminal.cursor.swiftColor)
    }

    private var selectionColor: NSColor {
        guard let index = themeIndex else { return NSColor(.accentColor) }
        return NSColor(themeModel.themes[index].terminal.selection.swiftColor)
    }

    private var textColor: NSColor {
        guard let index = themeIndex else { return NSColor(.primary) }
        return NSColor(themeModel.themes[index].terminal.text.swiftColor)
    }

    private func configure(_ terminal: CELocalShellTerminalView) {
        terminal.getTerminal().silentLog = true
        terminal.appearance = Settings.shared.preferences.terminal.darkAppearance
            ? NSAppearance(named: .darkAqua)
            : nil
        terminal.font = font
        terminal.installColors(ansiColors)
        terminal.caretColor = cursorColor.withAlphaComponent(0.5)
        terminal.caretTextColor = cursorColor.withAlphaComponent(0.5)
        terminal.selectedTextBackgroundColor = selectionColor
        terminal.nativeForegroundColor = textColor
        // Transparent so the workspace material behind the view shows through, matching
        // the integrated terminal rather than rendering an opaque black box.
        terminal.nativeBackgroundColor = .clear
        terminal.layer?.backgroundColor = .clear
        terminal.optionAsMetaKey = Settings.shared.preferences.terminal.optionAsMeta
    }
}
