//
//  SpotifyPlaybackState.swift
//  CodeEdit
//

import Foundation

/// A snapshot of the user's current Spotify playback.
struct SpotifyPlaybackState: Equatable {
    let isPlaying: Bool
    let trackID: String?
    let title: String
    let artist: String
    let albumArtURL: URL?
    let progressMs: Int
    let durationMs: Int
    let volumePercent: Int
    let deviceName: String?

    private struct Payload: Decodable {
        struct Device: Decodable {
            let name: String?
            let volumePercent: Int?
            enum CodingKeys: String, CodingKey { case name, volumePercent = "volume_percent" }
        }
        struct Item: Decodable {
            struct Artist: Decodable { let name: String }
            struct Album: Decodable { struct Image: Decodable { let url: String }; let images: [Image] }
            let id: String
            let name: String
            let durationMs: Int
            let artists: [Artist]
            let album: Album
            enum CodingKeys: String, CodingKey { case id, name, durationMs = "duration_ms", artists, album }
        }
        let isPlaying: Bool
        let progressMs: Int?
        let device: Device?
        let item: Item?
        enum CodingKeys: String, CodingKey {
            case isPlaying = "is_playing", progressMs = "progress_ms", device, item
        }
    }

    init(data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        self.isPlaying = payload.isPlaying
        self.progressMs = payload.progressMs ?? 0
        self.volumePercent = payload.device?.volumePercent ?? 0
        self.deviceName = payload.device?.name
        self.trackID = payload.item?.id
        self.title = payload.item?.name ?? "—"
        self.artist = (payload.item?.artists.map(\.name).joined(separator: ", ")) ?? ""
        self.durationMs = payload.item?.durationMs ?? 0
        self.albumArtURL = (payload.item?.album.images.first?.url).flatMap(URL.init(string:))
    }

    /// Returns nil for an empty body (nothing playing / 204).
    init?(dataOrEmpty data: Data) throws {
        guard !data.isEmpty else { return nil }
        try self.init(data: data)
    }
}
