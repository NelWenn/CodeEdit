//
//  DiscordSocketLocator.swift
//  CodeEdit
//

import Foundation

/// Builds the ordered list of candidate Discord IPC socket paths (`<base>/discord-ipc-0…9`) from the
/// environment. Pure (env is injected) so it is unit-testable.
enum DiscordSocketLocator {
    static func candidatePaths(environment: [String: String]) -> [String] {
        let envBases = ["XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TMP_DIR"].compactMap { environment[$0] }
        var seen = Set<String>()
        var result: [String] = []
        for base in envBases + ["/tmp"] {
            let trimmed = base.hasSuffix("/") ? String(base.dropLast()) : base
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            for index in 0...9 {
                result.append("\(trimmed)/discord-ipc-\(index)")
            }
        }
        return result
    }
}
