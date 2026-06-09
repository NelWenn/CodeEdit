//
//  ClaudeSessionsReader.swift
//  CodeEdit
//

import Foundation

/// Metadata about one persisted Claude Code session for a project.
struct ClaudeSessionInfo: Identifiable, Equatable {
    /// The Claude session UUID — also the `.jsonl` filename stem.
    let id: String
    let title: String
    let lastModified: Date
}

/// Reads Claude Code session files from `~/.claude/projects/<encoded-cwd>/`.
/// Filesystem-only and side-effect-free so it can be unit-tested with a temp base directory.
struct ClaudeSessionsReader {
    /// Base `~/.claude/projects` directory (overridable for tests).
    let projectsBaseURL: URL

    init(projectsBaseURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/projects", isDirectory: true)) {
        self.projectsBaseURL = projectsBaseURL
    }

    /// Encodes a working-directory path the way Claude Code names its project folders:
    /// every character that is not an ASCII letter or digit becomes `-`.
    static func encodedProjectDir(for cwd: URL) -> String {
        // Drop any trailing slash so a directory URL (which the workspace normalizes WITH a
        // trailing "/") encodes the same as Claude Code's own `process.cwd()` encoding, which
        // has no trailing separator. Otherwise the trailing "/" would become a stray "-".
        var path = cwd.standardizedFileURL.path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return String(path.map { character in
            (character.isASCII && (character.isLetter || character.isNumber)) ? character : "-"
        })
    }

    /// The directory holding the session `.jsonl` files for `cwd`.
    func sessionsDirectory(for cwd: URL) -> URL {
        projectsBaseURL.appendingPathComponent(Self.encodedProjectDir(for: cwd), isDirectory: true)
    }

    /// All sessions for `cwd`, newest first. Unreadable directories yield an empty array;
    /// individual malformed files still appear (with a date-based fallback title).
    func readSessions(for cwd: URL) -> [ClaudeSessionInfo] {
        let dir = sessionsDirectory(for: cwd)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls
            .filter { $0.pathExtension == "jsonl" }
            .compactMap { sessionInfo(at: $0) }
            .sorted { $0.lastModified > $1.lastModified }
    }

    private func sessionInfo(at url: URL) -> ClaudeSessionInfo? {
        let id = url.deletingPathExtension().lastPathComponent
        guard !id.isEmpty else { return nil }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? Date.distantPast
        let title = Self.deriveTitle(fromFileAt: url) ?? Self.fallbackTitle(for: modified)
        return ClaudeSessionInfo(id: id, title: title, lastModified: modified)
    }

    /// Scans the JSONL top (≤256 KB) and returns the first good title:
    /// a `summary` entry wins, else the first real user message's text (truncated).
    static func deriveTitle(fromFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: 256 * 1024)) ?? Data()
        // `String(decoding:as:)` substitutes U+FFFD for an invalid/truncated multi-byte
        // sequence at the 256 KB cut instead of returning nil (which would drop a valid title).
        // swiftlint:disable:next optional_data_string_conversion
        let text = String(decoding: data, as: UTF8.self)

        var firstUserText: String?
        for line in text.split(separator: "\n") {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                continue
            }
            if obj["type"] as? String == "summary", let summary = obj["summary"] as? String {
                let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return truncate(trimmed) }
            }
            if firstUserText == nil,
               obj["type"] as? String == "user",
               obj["attachment"] == nil,                       // skip hook/system injections
               (obj["isMeta"] as? Bool) != true,
               let message = obj["message"] as? [String: Any],
               let content = messageText(message) {
                firstUserText = content
            }
        }
        return firstUserText.map { truncate($0) }
    }

    /// Extracts plain text from a user message's `content` (a string or an array of blocks).
    private static func messageText(_ message: [String: Any]) -> String? {
        if let str = message["content"] as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let blocks = message["content"] as? [[String: Any]] {
            for block in blocks where block["type"] as? String == "text" {
                if let str = block["text"] as? String {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }
        return nil
    }

    private static func truncate(_ text: String, limit: Int = 60) -> String {
        let oneLine = text.replacingOccurrences(of: "\n", with: " ")
        if oneLine.count <= limit { return oneLine }
        return String(oneLine.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static let fallbackFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    private static func fallbackTitle(for date: Date) -> String {
        "Session — \(fallbackFormatter.string(from: date))"
    }
}
