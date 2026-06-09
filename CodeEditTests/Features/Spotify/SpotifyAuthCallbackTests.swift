@testable import CodeEdit
import XCTest

final class SpotifyAuthCallbackTests: XCTestCase {
    func testExtractsCodeWhenStateMatches() {
        let url = URL(string: "codeedit://spotify-callback?code=ABC123&state=xyz")!
        XCTAssertEqual(SpotifyAuthCallback.code(from: url, expectedState: "xyz"), "ABC123")
    }

    func testRejectsMismatchedState() {
        let url = URL(string: "codeedit://spotify-callback?code=ABC123&state=other")!
        XCTAssertNil(SpotifyAuthCallback.code(from: url, expectedState: "xyz"))
    }

    func testReturnsNilOnError() {
        let url = URL(string: "codeedit://spotify-callback?error=access_denied&state=xyz")!
        XCTAssertNil(SpotifyAuthCallback.code(from: url, expectedState: "xyz"))
    }
}
