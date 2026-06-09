@testable import CodeEdit
import XCTest

final class DiscordSocketLocatorTests: XCTestCase {
    func testBuildsTenCandidatesPerBaseDeduplicatedAndOrdered() {
        let paths = DiscordSocketLocator.candidatePaths(environment: [
            "XDG_RUNTIME_DIR": "/run/u",
            "TMPDIR": "/var/t/",       // trailing slash trimmed
            "TMP": "/run/u"            // duplicate of XDG base -> skipped
        ])
        XCTAssertEqual(paths.first, "/run/u/discord-ipc-0")
        XCTAssertTrue(paths.contains("/run/u/discord-ipc-9"))
        XCTAssertTrue(paths.contains("/var/t/discord-ipc-0"))
        XCTAssertTrue(paths.contains("/tmp/discord-ipc-3"))     // /tmp always appended
        // 3 unique bases (/run/u, /var/t, /tmp) × 10
        XCTAssertEqual(paths.count, 30)
        XCTAssertEqual(Set(paths).count, paths.count)           // no duplicates
    }
}
