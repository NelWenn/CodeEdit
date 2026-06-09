@testable import CodeEdit
import XCTest

final class SpotifyPlaybackStateTests: XCTestCase {
    func testDecodesPlayerJSON() throws {
        let json = """
        {
          "is_playing": true,
          "progress_ms": 12000,
          "device": {"name": "MacBook", "volume_percent": 55},
          "item": {
            "id": "track1",
            "name": "Song",
            "duration_ms": 200000,
            "artists": [{"name": "A"}, {"name": "B"}],
            "album": {"images": [{"url": "https://img/large.jpg", "width": 640}]}
          }
        }
        """
        let state = try SpotifyPlaybackState(data: Data(json.utf8))
        XCTAssertEqual(state.isPlaying, true)
        XCTAssertEqual(state.trackID, "track1")
        XCTAssertEqual(state.title, "Song")
        XCTAssertEqual(state.artist, "A, B")
        XCTAssertEqual(state.albumArtURL?.absoluteString, "https://img/large.jpg")
        XCTAssertEqual(state.progressMs, 12000)
        XCTAssertEqual(state.durationMs, 200000)
        XCTAssertEqual(state.volumePercent, 55)
        XCTAssertEqual(state.deviceName, "MacBook")
    }

    func testEmptyBodyMeansNothingPlaying() throws {
        // Spotify returns 204 / empty body when nothing is active.
        XCTAssertNil(try SpotifyPlaybackState(dataOrEmpty: Data()))
    }
}
