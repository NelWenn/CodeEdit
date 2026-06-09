//
//  ClaudeAgentView.swift
//  CodeEdit
//

import SwiftUI
import SwiftTerm

/// Full-frame view hosting the `claude` CLI for Agent mode.
///
/// Themed to follow the app's current light/dark appearance: it uses the matching theme's
/// terminal palette and a solid themed background, so the `claude` CLI detects the background
/// and renders its UI to match (a dark terminal on a light theme looked wrong and gave black
/// input highlights).
struct ClaudeAgentView: NSViewRepresentable {
    /// Observed so the terminal re-themes live when the user changes the theme.
    @ObservedObject private var themeModel: ThemeModel = .shared
    /// Re-configure when the system/app appearance flips between light and dark.
    @Environment(\.colorScheme) private var colorScheme

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

    private var isDarkAppearance: Bool {
        colorScheme == .dark
    }

    /// Index of the theme matching the app's current light/dark appearance, so the terminal is
    /// never dark while the editor is light (the previous logic used the raw `selectedTheme`,
    /// which could be a dark theme even in light mode).
    private var themeIndex: Int? {
        let selected = Settings[\.theme].matchAppearance
            ? (isDarkAppearance ? themeModel.selectedDarkTheme : themeModel.selectedLightTheme)
            : themeModel.selectedTheme
        guard let selected, let index = themeModel.themes.firstIndex(of: selected) else { return nil }
        return index
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

    private var backgroundColor: NSColor {
        guard let index = themeIndex else { return isDarkAppearance ? .black : .white }
        return NSColor(themeModel.themes[index].terminal.background.swiftColor)
    }

    private func configure(_ terminal: CELocalShellTerminalView) {
        terminal.getTerminal().silentLog = true
        terminal.appearance = NSAppearance(named: isDarkAppearance ? .darkAqua : .aqua)
        terminal.font = font
        terminal.installColors(ansiColors)
        terminal.caretColor = cursorColor.withAlphaComponent(0.5)
        terminal.caretTextColor = cursorColor.withAlphaComponent(0.5)
        terminal.selectedTextBackgroundColor = selectionColor
        terminal.nativeForegroundColor = textColor
        // Solid themed background so `claude` detects the light/dark background (a transparent
        // background made it render its TUI dark on light themes).
        terminal.nativeBackgroundColor = backgroundColor
        terminal.layer?.backgroundColor = backgroundColor.cgColor
        terminal.optionAsMetaKey = Settings.shared.preferences.terminal.optionAsMeta
    }
}
