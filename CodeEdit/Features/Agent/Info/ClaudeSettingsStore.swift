//
//  ClaudeSettingsStore.swift
//  CodeEdit
//

import Foundation

/// The Claude model + effort read from `~/.claude/settings.json`.
struct ClaudeModelConfig: Equatable {
    var model: String?
    var effort: String?
}

/// Reads and updates `model` / `effortLevel` in `~/.claude/settings.json`,
/// preserving every other key.
struct ClaudeSettingsStore {
    let url: URL

    init(url: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")) {
        self.url = url
    }

    func read() -> ClaudeModelConfig? {
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return ClaudeModelConfig(model: obj["model"] as? String, effort: obj["effortLevel"] as? String)
    }

    func update(model: String?, effort: String?) throws {
        let data = (try? Data(contentsOf: url)) ?? Data("{}".utf8)
        var obj = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if let model { obj["model"] = model }
        if let effort { obj["effortLevel"] = effort }
        let out = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: url, options: .atomic)
    }

    /// Enables the Workflows feature in settings.json (required for the `ultracode` effort, which
    /// is xhigh + dynamic-workflow orchestration). Preserves every other key.
    func setEnableWorkflows(_ enabled: Bool) {
        let data = (try? Data(contentsOf: url)) ?? Data("{}".utf8)
        guard var obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        obj["enableWorkflows"] = enabled
        if let out = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
            try? out.write(to: url, options: .atomic)
        }
    }
}
