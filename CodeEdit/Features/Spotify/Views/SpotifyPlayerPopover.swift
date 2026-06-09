//
//  SpotifyPlayerPopover.swift
//  CodeEdit
//

import SwiftUI

/// Extended controls: scrubber, like, volume.
struct SpotifyPlayerPopover: View {
    @ObservedObject var model: SpotifyPlayerModel

    @State private var isHoveringLike = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image("SpotifyLogo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .accessibilityLabel("Spotify")
                Text(model.state?.title ?? "Not playing").font(.headline).lineLimit(1)
                Spacer()
                Button {
                    model.toggleLike()
                } label: {
                    Image(systemName: model.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .foregroundStyle(model.isLiked ? .green : .secondary)
                        .frame(width: 26, height: 26)
                        .background {
                            Circle()
                                .fill(.primary)
                                .opacity(isHoveringLike ? 0.08 : 0)
                        }
                }
                .buttonStyle(.borderless)
                .onHover { isHoveringLike = $0 }
                .animation(.easeInOut(duration: 0.08), value: isHoveringLike)
                .help("Like")
            }

            if !model.hasActiveDevice {
                Label("No active device — open Spotify and press play once.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.secondary)
            }

            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: { Double(model.localProgressMs) },
                        set: { model.seek(toMs: Int($0)) }
                    ),
                    in: 0...Double(max(model.state?.durationMs ?? 1, 1))
                )
                HStack {
                    Text(Self.time(model.localProgressMs)).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(Self.time(model.state?.durationMs ?? 0)).font(.caption2).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(model.state?.volumePercent ?? 0) },
                        set: { model.setVolume(Int($0)) }
                    ),
                    in: 0...100
                )
                Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private static func time(_ milliseconds: Int) -> String {
        let total = milliseconds / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
