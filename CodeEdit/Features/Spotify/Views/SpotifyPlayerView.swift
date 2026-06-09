//
//  SpotifyPlayerView.swift
//  CodeEdit
//

import SwiftUI

/// Toolbar mini-player. Shows now-playing + transport; a click opens the extended popover.
struct SpotifyPlayerView: View {
    @ObservedObject private var model = SpotifyPlayerModel.shared
    @State private var showPopover = false

    var body: some View {
        Group {
            if model.isAuthorized {
                player
            } else {
                Button {
                    model.connect()
                } label: {
                    Label("Connect Spotify", systemImage: "music.note")
                }
                .buttonStyle(.borderless)
            }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var player: some View {
        HStack(spacing: 8) {
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
            Button { model.previous() } label: { Image(systemName: "backward.fill") }
            Button {
                model.togglePlayPause()
            } label: {
                Image(systemName: model.state?.isPlaying == true ? "pause.fill" : "play.fill")
            }
            Button { model.next() } label: { Image(systemName: "forward.fill") }
        }
        .buttonStyle(.icon(size: CGFloat(22)))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(maxWidth: 360)
        .background {
            if #available(macOS 26, *) {
                GlassEffectView().clipShape(Capsule())
            } else {
                Capsule().fill(.quaternary)
            }
        }
        .contentShape(Capsule())
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
            .frame(width: 22, height: 22)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "music.note")
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)
        }
    }
}
