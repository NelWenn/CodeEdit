@testable import CodeEdit
import XCTest

final class SpotifyRequestTests: XCTestCase {
    private func assertAuth(_ request: URLRequest, _ token: String = "TK") {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(token)")
    }

    func testPlayerIsGet() {
        let request = SpotifyRequest.player(token: "TK")
        XCTAssertEqual(request.url?.absoluteString, "https://api.spotify.com/v1/me/player")
        XCTAssertEqual(request.httpMethod, "GET")
        assertAuth(request)
    }

    func testPauseIsPut() {
        let request = SpotifyRequest.pause(token: "TK")
        XCTAssertEqual(request.url?.absoluteString, "https://api.spotify.com/v1/me/player/pause")
        XCTAssertEqual(request.httpMethod, "PUT")
    }

    func testNextIsPost() {
        XCTAssertEqual(SpotifyRequest.next(token: "TK").httpMethod, "POST")
        XCTAssertEqual(SpotifyRequest.next(token: "TK").url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/next")
    }

    func testSeekCarriesPositionQuery() {
        XCTAssertEqual(SpotifyRequest.seek(toMs: 4200, token: "TK").url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/seek?position_ms=4200")
    }

    func testVolumeCarriesPercentQuery() {
        XCTAssertEqual(SpotifyRequest.volume(percent: 30, token: "TK").url?.absoluteString,
                       "https://api.spotify.com/v1/me/player/volume?volume_percent=30")
    }

    func testLikeAndUnlikeAndContains() {
        XCTAssertEqual(SpotifyRequest.like(ids: ["a", "b"], token: "TK").httpMethod, "PUT")
        XCTAssertEqual(SpotifyRequest.unlike(ids: ["a"], token: "TK").httpMethod, "DELETE")
        let contains = SpotifyRequest.isLiked(ids: ["a", "b"], token: "TK")
        XCTAssertEqual(contains.httpMethod, "GET")
        XCTAssertEqual(contains.url?.absoluteString,
                       "https://api.spotify.com/v1/me/tracks/contains?ids=a,b")
    }
}
