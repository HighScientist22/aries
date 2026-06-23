//
//  FocusMixRow.swift
//  Aries
//

import SwiftUI

struct FocusMixRow: View {
    let mixes: [FocusMix]
    let accent: Color
    let artworkURL: (String?) -> URL?
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    let onPlay: (FocusMix, Bool) -> Void

    var body: some View {
        HomeSectionRow(title: "Focus") {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(mixes) { mix in
                        FocusMixCard(
                            mix: mix,
                            accent: accent,
                            artworkURL: artworkURL(mix.artworkFile),
                            onPlay: { onPlay(mix, false) },
                            onShuffle: { onPlay(mix, true) }
                        )
                        .libraryPlaybackMenu(
                            engine: engine,
                            library: library,
                            tracks: mix.tracks,
                            shuffleTracks: mix.id == "genre-focus" || mix.id == "favorites-focus" || mix.id == "discover"
                        )
                    }
                }
            }
            .scrollClipDisabled()
        }
        .frame(height: 210)
    }
}

private struct FocusMixCard: View {
    let mix: FocusMix
    let accent: Color
    let artworkURL: URL?
    let onPlay: () -> Void
    let onShuffle: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: onPlay) {
                    CachedArtwork(url: artworkURL, size: 130, rounded: false)
                        .scaleEffect(isHovered ? 1.02 : 1)
                }
                .buttonStyle(.plain)

                if isHovered {
                    HStack(spacing: 8) {
                        Button(action: onShuffle) {
                            Image(systemName: "shuffle")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onPlay) {
                            Image(systemName: "play.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(accent.opacity(0.95), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                }
            }

            Button(action: onPlay) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mix.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(mix.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(width: 130)
        .onHover { isHovered = $0 }
    }
}
