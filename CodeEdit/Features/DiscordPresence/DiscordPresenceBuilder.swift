//
//  DiscordPresenceBuilder.swift
//  CodeEdit
//

import Foundation

/// Inputs for building the presence (folder-only — never a file name).
struct DiscordPresenceContext: Equatable {
    var folder: String?
    var branch: String?
    var isEditing: Bool
    var startTimestamp: Int
}

/// Turns a `DiscordPresenceContext` into a folder-only `DiscordActivity`.
enum DiscordPresenceBuilder {
    static func build(_ context: DiscordPresenceContext) -> DiscordActivity {
        guard let folder = context.folder, !folder.isEmpty else {
            return DiscordActivity(
                details: "CodeEditAi",
                state: "Idle",
                startTimestamp: context.startTimestamp,
                largeImage: "logo",
                largeText: "CodeEditAi"
            )
        }
        let status = context.isEditing ? "Editing" : "Idle"
        let state: String
        if let branch = context.branch, !branch.isEmpty {
            state = "\(status) · \(branch)"
        } else {
            state = status
        }
        return DiscordActivity(
            details: folder,
            state: state,
            startTimestamp: context.startTimestamp,
            largeImage: "logo",
            largeText: "CodeEditAi"
        )
    }
}
