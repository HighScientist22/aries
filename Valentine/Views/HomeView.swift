//
//  HomeView.swift
//  Aries
//

import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore

    private var albums: [AlbumGroup] {
        groupAlbums(from: library.tracks)
    }

    private var artists: [ArtistGroup] {
        let grouped = Dictionary(grouping: library.tracks) { $0.albumArtist }
        return grouped.map { name, tracks in
            ArtistGroup(
                name: name,
                artworkFile: tracks.first(where: { $0.artworkFile != nil })?.artworkFile,
                tracks: tracks.sorted { $0.dateAdded < $1.dateAdded }
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                header

                if library.tracks.isEmpty {
                    emptyLibrary
                } else {
                    if let hero = library.recentlyPlayed.first ?? library.tracks.first {
                        HeroCard(track: hero, artworkURL: library.artworkURL(for: hero)) {
                            play(hero)
                        }
                    }

                    if !library.recentlyPlayed.isEmpty {
                        carousel("Recently Played", tracks: library.recentlyPlayed)
                    }

                    carousel("Recently Added", tracks: Array(library.tracks.prefix(15)))

                    albumCarousel("Albums", albums: albums)

                    artistCarousel("Artists", artists: artists)
                }
            }
            .padding(.vertical, 28)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Home")
                    .font(.largeTitle.weight(.bold))
                Text("\(library.tracks.count) tracks · \(albums.count) albums")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                importToLibrary()
            } label: {
                Label("Add Music", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)
            .disabled(library.isImporting)
        }
        .padding(.horizontal, 28)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Your library is empty")
                .font(.title3.weight(.semibold))
            Text("Add a folder of music to build your library. It stays here between launches.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Music") { importToLibrary() }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                .disabled(library.isImporting)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func carousel(_ title: LocalizedStringKey, tracks: [LibraryTrack]) -> some View {
        HomeSection(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(tracks) { track in
                        TrackTile(track: track, artworkURL: library.artworkURL(for: track)) {
                            play(track)
                        }
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private func albumCarousel(_ title: LocalizedStringKey, albums: [AlbumGroup]) -> some View {
        HomeSection(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(albums) { album in
                        Tile(
                            title: album.title,
                            subtitle: album.artist,
                            artworkURL: library.artworkURL(for: album.artworkFile),
                            rounded: false
                        ) {
                            playAlbum(album)
                        }
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }

    private func artistCarousel(_ title: LocalizedStringKey, artists: [ArtistGroup]) -> some View {
        HomeSection(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists) { artist in
                        Tile(
                            title: artist.name,
                            subtitle: "\(artist.tracks.count) tracks",
                            artworkURL: library.artworkURL(for: artist.artworkFile),
                            rounded: true
                        ) {
                            playArtist(artist)
                        }
                    }
                }
                .padding(.horizontal, 28)
            }
        }
    }

    // MARK: - Actions

    private func play(_ track: LibraryTrack) {
        guard let start = library.tracks.firstIndex(of: track) else { return }
        engine.playFromLibrary(library.tracks, startIndex: start, store: library)
    }

    private func playAlbum(_ album: AlbumGroup) {
        engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
    }

    private func playArtist(_ artist: ArtistGroup) {
        engine.playFromLibrary(artist.tracks, startIndex: 0, store: library)
    }

    private func importToLibrary() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .folder]
        if panel.runModal() == .OK {
            library.importFiles(panel.urls)
        }
    }
}

// MARK: - Grouping

struct AlbumGroup: Identifiable {
    let title: String
    let artist: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { title + artist }
}

struct ArtistGroup: Identifiable {
    let name: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { name }
}

func groupAlbums(from tracks: [LibraryTrack]) -> [AlbumGroup] {
    let grouped = Dictionary(grouping: tracks) { $0.album ?? $0.artist }
    return grouped.map { key, group in
        let ordered = group.sorted { $0.dateAdded < $1.dateAdded }
        return AlbumGroup(
            title: key,
            artist: ordered.first?.artist ?? "Unknown Artist",
            artworkFile: ordered.first(where: { $0.artworkFile != nil })?.artworkFile,
            tracks: ordered
        )
    }
    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
}

extension LibraryStore {
    func artworkURL(for file: String?) -> URL? {
        artworkURL(forFilename: file)
    }
}

// MARK: - Components

private struct HomeSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.bold))
                .padding(.horizontal, 28)
            content
        }
    }
}

private struct HeroCard: View {
    let track: LibraryTrack
    let artworkURL: URL?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                CachedArtwork(url: artworkURL, size: 140, rounded: false)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pick up where you left off")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(track.title)
                        .font(.title.weight(.bold))
                        .lineLimit(2)
                    Text(track.artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Label("Play", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                }
                Spacer()
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 28)
    }
}

private struct Tile: View {
    let title: String
    let subtitle: String
    let artworkURL: URL?
    let rounded: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                CachedArtwork(url: artworkURL, size: 150, rounded: rounded)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, .black.opacity(0.5))
                            .padding(8)
                            .opacity(isHovered ? 1 : 0)
                    }
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 150)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct TrackTile: View {
    let track: LibraryTrack
    let artworkURL: URL?
    let action: () -> Void

    var body: some View {
        Tile(title: track.title, subtitle: track.artist, artworkURL: artworkURL, rounded: false, action: action)
    }
}
