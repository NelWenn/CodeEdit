@testable import CodeEdit
import XCTest

final class SpotifyTokensTests: XCTestCase {
    func testDecodesTokenResponseAndComputesExpiry() throws {
        let json = #"{"access_token":"AT","refresh_token":"RT","expires_in":3600,"token_type":"Bearer"}"#
        let now = Date(timeIntervalSince1970: 1_000_000)
        let tokens = try SpotifyTokens(responseData: Data(json.utf8), refreshFallback: nil, now: now)
        XCTAssertEqual(tokens.accessToken, "AT")
        XCTAssertEqual(tokens.refreshToken, "RT")
        XCTAssertEqual(tokens.expiresAt, now.addingTimeInterval(3600))
    }

    func testRefreshFallbackKeepsRefreshTokenWhenResponseOmitsIt() throws {
        // Spotify's refresh response can omit refresh_token; we must keep the old one.
        let json = #"{"access_token":"AT2","expires_in":3600,"token_type":"Bearer"}"#
        let tokens = try SpotifyTokens(responseData: Data(json.utf8), refreshFallback: "RT", now: Date())
        XCTAssertEqual(tokens.refreshToken, "RT")
    }

    func testShouldRefreshWithinSkew() {
        let now = Date()
        let tokens = SpotifyTokens(accessToken: "AT", refreshToken: "RT", expiresAt: now.addingTimeInterval(120))
        XCTAssertFalse(tokens.shouldRefresh(now: now))                 // 120s left
        XCTAssertTrue(tokens.shouldRefresh(now: now.addingTimeInterval(80)))  // 40s left < 60s skew
    }
}
