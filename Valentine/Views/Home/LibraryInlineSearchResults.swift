//
//  LibraryInlineSearchResults.swift
//  Aries
//

import SwiftUI

struct LibraryInlineSearchResults: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    let query: String

    private var results: LibrarySearchResults {
        library.search(query: query)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if results.isEmpty {
                    Text("No results for “\(query)”")
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                } else {
                    if !results.tracks.isEmpty {
                        section("Tracks") {
                            ForEach(Array(results.tracks.enumerated()), id: \.element.id) { index, track in
                                LibraryTrackRow(
                                    track: track,
                                    artworkURL: library.artworkURL(for: track.artworkFile),
                                    accent: theme.accent,
                                    playCount: library.playCount(for: track.id),
                                    lastPlayed: library.lastPlayed(for: track.id),
                                    isFavorite: library.isFavorite(track: track),
                                    onFavorite: { library.toggleFavorite(track: track) }
                                ) {
                                    engine.playFromLibrary(results.tracks, startIndex: index, store: library)
                                }
                                .libraryPlaybackMenu(
                                    engine: engine,
                                    library: library,
                                    tracks: results.tracks,
                                    startIndex: index
                                )
                            }
                        }
                    }
                    if !results.albums.isEmpty {
                        section("Albums") {
                            ForEach(results.albums) { album in
                                Button {
                                    NotificationCenter.default.post(name: .openAlbumFromSearch, object: album.id)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(album.title).font(.headline)
                                            Text(album.artist).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if !results.artists.isEmpty {
                        section("Artists") {
                            ForEach(results.artists) { artist in
                                Button {
                                    NotificationCenter.default.post(name: .openArtistFromSearch, object: artist.name)
                                } label: {
                                    Text(artist.name)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.weight(.semibold))
            content()
        }
    }
}
