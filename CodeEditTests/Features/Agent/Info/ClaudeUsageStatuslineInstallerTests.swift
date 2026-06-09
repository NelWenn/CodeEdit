@testable import CodeEdit
import XCTest

final class ClaudeUsageStatuslineInstallerTests: XCTestCase {
    func testInstallsWhenAbsent() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = dir.appendingPathComponent("settings.json")
        try "{}".write(to: settings, atomically: true, encoding: .utf8)
        let installer = ClaudeUsageStatuslineInstaller(claudeDir: dir)
        XCTAssertEqual(try installer.ensureInstalled(), .installed)
        let raw = try String(contentsOf: settings, encoding: .utf8)
        XCTAssertTrue(raw.contains("statusLine"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("codeeditai-statusline.sh").path))
    }

    func testDoesNotClobberExisting() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = dir.appendingPathComponent("settings.json")
        try #"{"statusLine":{"type":"command","command":"mytool"}}"#.write(to: settings, atomically: true, encoding: .utf8)
        let installer = ClaudeUsageStatuslineInstaller(claudeDir: dir)
        XCTAssertEqual(try installer.ensureInstalled(), .foreignStatuslinePresent)
        XCTAssertTrue(try String(contentsOf: settings, encoding: .utf8).contains("mytool"))
    }
}
