//
//  DiscordActivity.swift
//  CodeEdit
//

import Foundation

/// A Discord Rich Presence activity payload (encodes to the snake_case shape the API expects).
struct DiscordActivity: Encodable, Equatable {
    var details: String?
    var state: String?
    /// Unix epoch seconds when the activity started (drives the "elapsed" timer).
    var startTimestamp: Int?
    var largeImage: String?
    var largeText: String?

    private enum CodingKeys: String, CodingKey {
        case details, state, timestamps, assets
    }
    private struct Timestamps: Encodable { let start: Int }
    private struct Assets: Encodable {
        let largeImage: String?
        let largeText: String?
        enum CodingKeys: String, CodingKey {
            case largeImage = "large_image"
            case largeText = "large_text"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(details, forKey: .details)
        try container.encodeIfPresent(state, forKey: .state)
        if let startTimestamp {
            try container.encode(Timestamps(start: startTimestamp), forKey: .timestamps)
        }
        if largeImage != nil || largeText != nil {
            try container.encode(Assets(largeImage: largeImage, largeText: largeText), forKey: .assets)
        }
    }
}
