@testable import CodeEdit
import XCTest

final class ClaudeSessionsReaderTests: XCTestCase {
    private func makeTempProjectsDir() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ceai-reader-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    func testEncodedProjectDirReplacesNonAlphanumericWithDash() {
        let cwd = URL(fileURLWithPath: "/Users/theo/Documents/Smaacks/smaacks-app")
        XCTAssertEqual(
            ClaudeSessionsReader.encodedProjectDir(for: cwd),
            "-Users-theo-Documents-Smaacks-smaacks-app"
        )
    }

    func testReadsSessionsSortedNewestFirstWithDerivedTitles() throws {
        let base = try makeTempProjectsDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let cwd = URL(fileURLWithPath: "/tmp/proj")
        let dir = base.appendingPathComponent(ClaudeSessionsReader.encodedProjectDir(for: cwd), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Session A: has a summary line.
        let idA = "aaaaaaaa-0000-0000-0000-000000000001"
        try ("{\"type\":\"summary\",\"summary\":\"Refactor the auth flow\"}\n")
            .write(to: dir.appendingPathComponent("\(idA).jsonl"), atomically: true, encoding: .utf8)
        // Session B: no summary, first user message text.
        let idB = "bbbbbbbb-0000-0000-0000-000000000002"
        try ("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"Fix the navbar spacing please\"}}\n")
            .write(to: dir.appendingPathComponent("\(idB).jsonl"), atomically: true, encoding: .utf8)
        // Malformed file: must be skipped (its content), not crash.
        let idC = "cccccccc-0000-0000-0000-000000000003"
        try ("not json at all\n")
            .write(to: dir.appendingPathComponent("\(idC).jsonl"), atomically: true, encoding: .utf8)

        // Make A newest, B middle, C oldest.
        let now = Date()
        try setModificationDate(now, at: dir.appendingPathComponent("\(idA).jsonl"))
        try setModificationDate(now.addingTimeInterval(-60), at: dir.appendingPathComponent("\(idB).jsonl"))
        try setModificationDate(now.addingTimeInterval(-120), at: dir.appendingPathComponent("\(idC).jsonl"))

        let reader = ClaudeSessionsReader(projectsBaseURL: base)
        let sessions = reader.readSessions(for: cwd)

        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[0].id, idA)
        XCTAssertEqual(sessions[0].title, "Refactor the auth flow")
        XCTAssertEqual(sessions[1].id, idB)
        XCTAssertEqual(sessions[1].title, "Fix the navbar spacing please")
        // Malformed file still listed with a fallback (date) title, not a crash.
        XCTAssertTrue(sessions[2].title.hasPrefix("Session —"))
    }

    func testReturnsEmptyWhenDirMissing() {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("ceai-missing-\(UUID().uuidString)", isDirectory: true)
        let reader = ClaudeSessionsReader(projectsBaseURL: base)
        XCTAssertEqual(reader.readSessions(for: URL(fileURLWithPath: "/tmp/none")).count, 0)
    }

    func testDerivesTitleFromArrayOfTextBlocks() throws {
        let base = try makeTempProjectsDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let cwd = URL(fileURLWithPath: "/tmp/proj-blocks")
        let dir = base.appendingPathComponent(ClaudeSessionsReader.encodedProjectDir(for: cwd), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = "dddddddd-0000-0000-0000-000000000004"
        try ("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":" +
             "[{\"type\":\"text\",\"text\":\"Help me refactor this module\"}]}}\n")
            .write(to: dir.appendingPathComponent("\(id).jsonl"), atomically: true, encoding: .utf8)
        let sessions = ClaudeSessionsReader(projectsBaseURL: base).readSessions(for: cwd)
        XCTAssertEqual(sessions.first?.title, "Help me refactor this module")
    }

    func testEncodedProjectDirIgnoresTrailingSlash() {
        // Workspace folder URLs are normalized WITH a trailing slash; the encoded dir must match
        // Claude's no-trailing-separator encoding (and equal the no-slash form).
        let withSlash = URL(filePath: "/Users/theo/Developer/CodeEdit/")
        let withoutSlash = URL(filePath: "/Users/theo/Developer/CodeEdit")
        XCTAssertEqual(
            ClaudeSessionsReader.encodedProjectDir(for: withSlash),
            "-Users-theo-Developer-CodeEdit"
        )
        XCTAssertEqual(
            ClaudeSessionsReader.encodedProjectDir(for: withSlash),
            ClaudeSessionsReader.encodedProjectDir(for: withoutSlash)
        )
    }

    func testLongTitleIsTruncatedWithEllipsis() throws {
        let base = try makeTempProjectsDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let cwd = URL(fileURLWithPath: "/tmp/proj-trunc")
        let dir = base.appendingPathComponent(ClaudeSessionsReader.encodedProjectDir(for: cwd), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = "eeeeeeee-0000-0000-0000-000000000005"
        let longText = String(repeating: "a", count: 100)
        try ("{\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"\(longText)\"}}\n")
            .write(to: dir.appendingPathComponent("\(id).jsonl"), atomically: true, encoding: .utf8)
        let title = ClaudeSessionsReader(projectsBaseURL: base).readSessions(for: cwd).first?.title
        XCTAssertNotNil(title)
        XCTAssertTrue(title?.hasSuffix("…") ?? false)
        XCTAssertEqual(title?.count, 61) // 60 chars + ellipsis
    }

    /// Sets a file's modification date (helper keeps call sites within line/bracket lint limits).
    private func setModificationDate(_ date: Date, at url: URL) throws {
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
    }
}
