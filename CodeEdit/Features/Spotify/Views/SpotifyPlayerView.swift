//
//  SpotifyPlayerView.swift
//  CodeEdit
//

import SwiftUI

/// Toolbar mini-player. Shows now-playing + transport; a click opens the extended popover.
struct SpotifyPlayerView: View {
    @ObservedObject private var model = SpotifyPlayerModel.shared
    @Environment(\.colorScheme)
    private var colorScheme
    @State private var showPopover = false
    @State private var isHoveringPlayer = false

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

    private var player: some View {
        HStack(spacing: 8) {
            Image("SpotifyLogo")
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .accessibilityLabel("Spotify")
            artwork
            VStack(alignment: .leading, spacing: 0) {
                Text(model.state?.title ?? "Not playing")
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(model.state?.artist ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 90, alignment: .leading)
            SpotifyTransportButton(systemName: "backward.fill") { model.previous() }
            SpotifyTransportButton(
                systemName: model.state?.isPlaying == true ? "pause.fill" : "play.fill"
            ) {
                model.togglePlayPause()
            }
            SpotifyTransportButton(systemName: "forward.fill") { model.next() }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: 380)
        .background {
            ZStack {
                if #available(macOS 26, *) {
                    GlassEffectView().clipShape(Capsule()).clipped()
                } else {
                    Capsule().fill(.quaternary)
                }
                Capsule()
                    .fill(Color(nsColor: colorScheme == .dark ? .white : .black))
                    .opacity(isHoveringPlayer ? 0.06 : 0)
            }
        }
        .contentShape(Capsule())
        .onHover { isHoveringPlayer = $0 }
        .animation(.easeInOut(duration: 0.08), value: isHoveringPlayer)
        .onTapGesture { showPopover = true }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            SpotifyPlayerPopover(model: model)
        }
        .help(model.hasActiveDevice ? (model.state?.title ?? "Spotify") : "No active Spotify device — open Spotify")
    }

    @ViewBuilder private var artwork: some View {
        if let url = model.state?.albumArtURL {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.secondary.opacity(0.2)
            }
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 13))
                .frame(width: 26, height: 26)
                .foregroundStyle(.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15))
                )
        }
    }
}

/// Signed-out call-to-action: Spotify logo + label in a rounded Liquid Glass button with a hover effect.
private struct SpotifyConnectButton: View {
    let action: () -> Void
    @Environment(\.colorScheme)
    private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image("SpotifyLogo")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 17, height: 17)
                Text("Connect Spotify")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            ZStack {
                if #available(macOS 26, *) {
                    GlassEffectView().clipShape(Capsule()).clipped()
                } else {
                    Capsule().fill(.quaternary)
                }
                Capsule()
                    .fill(Color(nsColor: colorScheme == .dark ? .white : .black))
                    .opacity(isHovering ? 0.08 : 0)
            }
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.08), value: isHovering)
        .help("Connect your Spotify account")
    }
}

/// Transport control with a larger, accessible icon and a subtle circular hover highlight.
private struct SpotifyTransportButton: View {
    let systemName: String
    let action: () -> Void
    @Environment(\.colorScheme)
    private var colorScheme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(.icon(size: CGFloat(26)))
        .background {
            Circle()
                .fill(Color(nsColor: colorScheme == .dark ? .white : .black))
                .opacity(isHovering ? 0.10 : 0)
        }
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.08), value: isHovering)
    }
}
