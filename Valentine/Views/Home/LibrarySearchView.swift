//
//  LibrarySearchView.swift
//  Aries
//

import SwiftUI

struct LibrarySearchView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var navigation: AppNavigation
    @EnvironmentObject var theme: AlbumTheme
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var results: LibrarySearchResults {
        library.search(query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search tracks, albums, artists…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
            }
            .padding(16)
            .background(.ultraThinMaterial)

            Divider()

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("Search your library")
                        .font(.headline)
                    Text("Find tracks, albums, and artists")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if results.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("No results")
                        .font(.headline)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if !results.tracks.isEmpty {
                            searchSection("Tracks") {
                                ForEach(results.tracks) { track in
                                    searchTrackRow(track)
                                }
                            }
                        }
                        if !results.albums.isEmpty {
                            searchSection("Albums") {
                                ForEach(results.albums) { album in
                                    searchAlbumRow(album)
                                }
                            }
                        }
                        if !results.artists.isEmpty {
                            searchSection("Artists") {
                                ForEach(results.artists) { artist in
                                    searchArtistRow(artist)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear { isFocused = true }
    }

    private func searchSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func searchTrackRow(_ track: LibraryTrack) -> some View {
        LibraryTrackRow(
            track: track,
            artworkURL: library.artworkURL(for: track),
            accent: theme.accent
        ) {
            engine.playFromLibrary([track], startIndex: 0, store: library)
            dismiss()
        }
        .libraryPlaybackMenu(engine: engine, library: library, tracks: [track])
    }

    private func searchAlbumRow(_ album: AlbumGroup) -> some View {
        Button {
            engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                CachedArtwork(url: library.artworkURL(for: album.artworkFile), size: 44, rounded: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(album.title)
                        .font(.subheadline.weight(.medium))
                    Text(album.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(album.tracks.count) tracks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .libraryPlaybackMenu(engine: engine, library: library, tracks: album.tracks)
    }

    private func searchArtistRow(_ artist: ArtistGroup) -> some View {
        Button {
            navigation.openArtist(artist.name)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                CachedArtwork(url: library.artworkURL(for: artist.artworkFile), size: 44, rounded: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(artist.name)
                        .font(.subheadline.weight(.medium))
                    Text("\(artist.tracks.count) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .libraryPlaybackMenu(engine: engine, library: library, tracks: artist.tracks)
    }
}
