//
//  ClaudeLiveState.swift
//  CodeEdit
//

import Foundation

/// Live Claude session state, decoded from the statusline JSON written to
/// `~/.claude/codeeditai-status.json`.
struct ClaudeLiveState: Equatable {
    var modelDisplayName: String?
    var effortLevel: String?
    var thinkingEnabled: Bool?
    var contextUsedPercent: Double?

    init() {}

    init(statuslineData data: Data) throws {
        struct Payload: Decodable {
            struct Model: Decodable { let display_name: String? }
            struct Effort: Decodable { let level: String? }
            struct Thinking: Decodable { let enabled: Bool? }
            struct Context: Decodable { let used_percentage: Double? }
            let model: Model?
            let effort: Effort?
            let thinking: Thinking?
            let context_window: Context?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        modelDisplayName = payload.model?.display_name
        effortLevel = payload.effort?.level
        thinkingEnabled = payload.thinking?.enabled
        contextUsedPercent = payload.context_window?.used_percentage
    }
}
