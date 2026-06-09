//
//  ClaudeUsage.swift
//  CodeEdit
//

import Foundation

/// One usage window: how much of the quota is used and when it resets.
struct UsageWindow: Equatable {
    let usedPercent: Double
    let resetsAt: Date?
}

/// Live Claude usage across the session (5h), weekly (7d), and weekly-Sonnet windows,
/// decoded from the `GET /api/oauth/usage` response.
struct ClaudeUsage: Equatable {
    var session: UsageWindow?
    var weekly: UsageWindow?
    var weeklySonnet: UsageWindow?

    init() {}

    init(endpointData data: Data) throws {
        struct Window: Decodable { let utilization: Double?; let resets_at: String? }
        struct Payload: Decodable {
            let five_hour: Window?
            let seven_day: Window?
            let seven_day_sonnet: Window?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        func map(_ win: Window?) -> UsageWindow? {
            guard let win else { return nil }
            return UsageWindow(usedPercent: win.utilization ?? 0, resetsAt: ClaudeUsage.parseDate(win.resets_at))
        }
        session = map(payload.five_hour)
        weekly = map(payload.seven_day)
        weeklySonnet = map(payload.seven_day_sonnet)
    }

    /// Parses ISO8601 timestamps, tolerating the endpoint's 6-digit fractional seconds.
    static func parseDate(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFrac.date(from: iso) { return date }
        // Strip fractional seconds (e.g. ".270682") then parse.
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let dot = iso.firstIndex(of: "."),
           let tzMatch = iso.range(of: "[+Z-]", options: .regularExpression, range: iso.index(after: dot)..<iso.endIndex) {
            let stripped = iso.replacingCharacters(in: dot..<tzMatch.lowerBound, with: "")
            return plain.date(from: stripped)
        }
        return plain.date(from: iso)
    }
}
