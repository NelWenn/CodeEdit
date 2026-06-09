//
//  ClaudeAccount.swift
//  CodeEdit
//

import Foundation

/// A Claude Code account parsed from `~/.claude.json`.
struct ClaudeAccount: Equatable {
    let email: String
    let displayName: String
    let planDisplayName: String
    let hasExtraUsage: Bool

    /// Maps a Claude rate-limit tier id (e.g. "default_claude_max_20x") to a display name.
    static func planDisplayName(forTier tier: String?) -> String {
        guard let tier, !tier.isEmpty else { return "Unknown" }
        switch tier {
        case "default_claude_max_20x": return "Max 20x"
        case "default_claude_max_5x": return "Max 5x"
        default:
            if tier.contains("pro") { return "Pro" }
            let cleaned = tier
                .replacingOccurrences(of: "default_", with: "")
                .replacingOccurrences(of: "claude_", with: "")
                .replacingOccurrences(of: "_", with: " ")
            return cleaned.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
        }
    }
}

/// Reads and decodes the `oauthAccount` object from `~/.claude.json`.
enum ClaudeAccountReader {
    struct DecodeError: Error {}

    private struct ClaudeJSON: Decodable {
        struct OAuthAccount: Decodable {
            let emailAddress: String?
            let displayName: String?
            let userRateLimitTier: String?
            let organizationRateLimitTier: String?
            let hasExtraUsageEnabled: Bool?
        }
        let oauthAccount: OAuthAccount?
    }

    static func defaultURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    static func read(claudeJSONURL url: URL = defaultURL()) throws -> ClaudeAccount {
        let data = try Data(contentsOf: url)
        guard let oauth = try JSONDecoder().decode(ClaudeJSON.self, from: data).oauthAccount else {
            throw DecodeError()
        }
        let tier = oauth.userRateLimitTier ?? oauth.organizationRateLimitTier
        return ClaudeAccount(
            email: oauth.emailAddress ?? "Unknown",
            displayName: oauth.displayName ?? oauth.emailAddress ?? "Claude",
            planDisplayName: ClaudeAccount.planDisplayName(forTier: tier),
            hasExtraUsage: oauth.hasExtraUsageEnabled ?? false
        )
    }
}
