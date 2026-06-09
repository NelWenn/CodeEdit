//
//  SpotifyPlayerView.swift
//  CodeEdit
//

import SwiftUI

/// Toolbar mini-player: a native Liquid Glass capsule with now-playing + all inline controls
/// (transport, scrubber, like, volume).
struct SpotifyPlayerView: View {
    @ObservedObject private var model = SpotifyPlayerModel.shared

    var body: some View {
        Group {
            if model.isAuthorized {
                player
            } else {
                SpotifyConnectButton { model.connect() }
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var hasTrack: Bool { model.state != nil }

    private var player: some View {
        HStack(spacing: 10) {
            Image("SpotifyLogo")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .accessibilityLabel("Spotify")

            artwork

            VStack(alignment: .leading, spacing: 1) {
                Text(model.state?.title ?? "Not playing")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(model.state?.artist ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 92, alignment: .leading)

            HStack(spacing: 2) {
                SpotifyIconButton(systemName: "backward.fill", iconSize: 13) { model.previous() }
                SpotifyIconButton(
                    systemName: model.state?.isPlaying == true ? "pause.fill" : "play.fill",
                    iconSize: 18
                ) { model.togglePlayPause() }
                SpotifyIconButton(systemName: "forward.fill", iconSize: 13) { model.next() }
            }

            scrubber

            SpotifyIconButton(
                systemName: model.isLiked ? "heart.fill" : "heart",
                iconSize: 15,
                tint: model.isLiked ? .green : .secondary
            ) { model.toggleLike() }
            .disabled(!hasTrack)

            volume
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: 680)
        .glassCapsule()
        .help(
            model.hasActiveDevice
            ? (model.state?.title ?? "Spotify")
            : "No active Spotify device — open Spotify and press play once"
        )
    }

    private var scrubber: some View {
        HStack(spacing: 6) {
            Text(Self.time(model.localProgressMs))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(model.localProgressMs) },
                    set: { model.scrub(toMs: Int($0)) }
                ),
                in: 0...Double(max(model.state?.durationMs ?? 1, 1)),
                onEditingChanged: { editing in
                    if editing {
                        model.beginScrubbing()
                    } else {
                        model.endScrubbing(toMs: model.localProgressMs)
                    }
                }
            )
            .controlSize(.mini)
            Text(Self.time(model.state?.durationMs ?? 0))
                .font(.system(size: 9, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 130)
        .disabled(!hasTrack)
        .opacity(hasTrack ? 1 : 0.45)
    }

    private var volume: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(model.localVolumePercent) },
                    set: { model.setVolume(Int($0)) }
                ),
                in: 0...100
            )
            .controlSize(.mini)
            .frame(width: 56)
        }
        .disabled(!hasTrack)
        .opacity(hasTrack ? 1 : 0.45)
    }

    @ViewBuilder private var artwork: some View {
        if let url = model.state?.albumArtURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.15)))
        }
    }

    private static func time(_ milliseconds: Int) -> String {
        let total = max(0, milliseconds) / 1000
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

// MARK: - Liquid Glass capsule

private struct GlassCapsule: ViewModifier {
    var interactive: Bool

    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(macOS 26, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: Capsule())
        } else {
            content.background(Capsule().fill(.quaternary))
        }
#else
        content.background(Capsule().fill(.quaternary))
#endif
    }
}

private extension View {
    /// Wraps the view in the native macOS Liquid Glass material clipped to a capsule (with a
    /// pre-26 fallback). `interactive` adds the system hover/press response.
    func glassCapsule(interactive: Bool = false) -> some View {
        modifier(GlassCapsule(interactive: interactive))
    }
}

// MARK: - Buttons

/// Signed-out call-to-action: Spotify logo + label in a native interactive Liquid Glass capsule.
private struct SpotifyConnectButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image("SpotifyLogo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                Text("Connect Spotify")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassCapsule(interactive: true)
        .help("Connect your Spotify account")
    }
}

/// Round icon button with an accessible glyph and a subtle circular hover highlight.
private struct SpotifyIconButton: View {
    let systemName: String
    var iconSize: CGFloat = 13
    var tint: Color?
    let action: () -> Void

    @Environment(\.colorScheme)
    private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(tint ?? .primary)
                .frame(width: iconSize + 15, height: iconSize + 15)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .background {
            Circle()
                .fill(Color(nsColor: colorScheme == .dark ? .white : .black))
                .opacity(isHovering ? 0.12 : 0)
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.08), value: isHovering)
    }
}
