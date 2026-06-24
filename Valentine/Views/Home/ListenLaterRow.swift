//
//  ListenLaterRow.swift
//  Aries
//

import SwiftUI

struct ListenLaterRow: View {
    let tracks: [LibraryTrack]
    let accent: Color
    let artworkURL: (LibraryTrack) -> URL?
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    var onViewAll: () -> Void

    var body: some View {
        HomeSectionRow(title: "Listen Later") {
            if tracks.isEmpty {
                Text("Save tracks to listen to later from the context menu.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(Array(tracks.prefix(12).enumerated()), id: \.element.id) { index, track in
                                ListenLaterTile(
                                    track: track,
                                    accent: accent,
                                    artworkURL: artworkURL(track),
                                    onPlay: {
                                        engine.playFromLibrary(tracks, startIndex: index, store: library)
                                    },
                                    onRemove: {
                                        library.removeFromListenLater(track)
                                    }
                                )
                                .libraryPlaybackMenu(
                                    engine: engine,
                                    library: library,
                                    tracks: [track],
                                    startIndex: index
                                )
                            }
                        }
                    }
                    .scrollClipDisabled()

                    if tracks.count > 12 {
                        Button("View All (\(tracks.count))", action: onViewAll)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(accent)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ListenLaterTile: View {
    let track: LibraryTrack
    let accent: Color
    let artworkURL: URL?
    let onPlay: () -> Void
    let onRemove: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button(action: onPlay) {
                    CachedArtwork(url: artworkURL, size: 100, rounded: false)
                        .scaleEffect(isHovered ? 1.02 : 1)
                }
                .buttonStyle(.plain)

                if isHovered {
                    HStack(spacing: 6) {
                        Button(action: onPlay) {
                            Image(systemName: "play.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(accent.opacity(0.95), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Button(action: onRemove) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(.black.opacity(0.55), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Mark as listened")
                    }
                    .padding(6)
                }
            }

            Button(action: onPlay) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 100, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 100)
        .onHover { isHovered = $0 }
    }
}
