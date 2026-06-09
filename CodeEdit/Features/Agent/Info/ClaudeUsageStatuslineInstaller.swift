//
//  ClaudeUsageStatuslineInstaller.swift
//  CodeEdit
//

import Foundation

/// Installs a statusLine command into `~/.claude/settings.json` that dumps Claude Code's
/// statusline JSON to `codeeditai-status.json`, without clobbering an existing statusLine.
struct ClaudeUsageStatuslineInstaller {
    enum InstallResult: Equatable { case installed, alreadyOurs, foreignStatuslinePresent, noSettings }

    let claudeDir: URL
    init(claudeDir: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")) {
        self.claudeDir = claudeDir
    }

    /// File where the full statusline JSON (live state + any rate_limits) is written.
    var statusFileURL: URL { claudeDir.appendingPathComponent("codeeditai-status.json") }
    private var scriptURL: URL { claudeDir.appendingPathComponent("codeeditai-statusline.sh") }
    private var settingsURL: URL { claudeDir.appendingPathComponent("settings.json") }
    private let marker = "codeeditai-statusline.sh"

    @discardableResult
    func ensureInstalled() throws -> InstallResult {
        guard let data = try? Data(contentsOf: settingsURL),
              var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .noSettings
        }
        if let statusLine = object["statusLine"] as? [String: Any],
           let command = statusLine["command"] as? String {
            return command.contains(marker) ? .alreadyOurs : .foreignStatuslinePresent
        }
        let script = """
        #!/bin/zsh
        input=$(cat)
        print -r -- "$input" > \(statusFileURL.path)
        print -rn -- "CodeEditAi"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        object["statusLine"] = ["type": "command", "command": scriptURL.path]
        let output = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try output.write(to: settingsURL, options: .atomic)
        return .installed
    }
}
