//
//  ArtistDetailView.swift
//  Aries
//

import SwiftUI

struct ArtistDetailView: View {
    let artist: ArtistGroup
    let albums: [AlbumGroup]
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    @EnvironmentObject var navigation: AppNavigation
    let onBack: () -> Void
    let onOpenAlbum: (AlbumGroup) -> Void

    @State private var detail: EnrichedArtistDetail?
    @State private var isLoading = true

    private var libraryArtwork: URL? {
        library.artworkURL(for: artist.artworkFile)
    }

    private var portraitURL: URL? {
        libraryArtwork ?? detail?.imageURL
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailBackBar(title: artist.name, accent: theme.accent, onBack: onBack) {
                FavoriteHeartButton(
                    isFavorite: library.isFavorite(artist: artist),
                    accent: theme.accent
                ) {
                    library.toggleFavorite(artist: artist)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    heroSection

                    if let summary = detail?.summary, !summary.isEmpty {
                        GlassCard {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if let similar = detail?.similarArtists, !similar.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Similar Artists")
                                    .font(.headline)
                                SimilarArtistsRow(
                                    names: similar,
                                    tracks: library.tracks,
                                    accent: theme.accent,
                                    onSelect: openSimilarArtist
                                )
                            }
                        }
                    }

                    if !albums.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Discography")
                                    .font(.headline)

                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 18)],
                                    spacing: 20
                                ) {
                                    ForEach(albums) { album in
                                        LibraryMediaTile(
                                            title: album.title,
                                            subtitle: "\(album.tracks.count) tracks",
                                            artworkURL: library.artworkURL(for: album.artworkFile),
                                            style: .album,
                                            accent: theme.accent,
                                            onOpen: { onOpenAlbum(album) },
                                            onPlay: { playAlbum(album) }
                                        )
                                        .libraryPlaybackMenu(
                                            engine: engine,
                                            library: library,
                                            tracks: album.tracks,
                                            album: album
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background.opacity(0.72))
        .overlay {
            if isLoading && detail == nil {
                ProgressView("Loading artist info…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onExitCommand(perform: onBack)
        .task(id: artist.id) {
            isLoading = true
            let loaded = await MetadataService.shared.artistDetail(for: artist, libraryArtwork: libraryArtwork)
            detail = loaded
            isLoading = false
            await applyTheme(from: libraryArtwork ?? loaded.imageURL)
        }
    }

    private var heroSection: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(artist.name)
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .lineLimit(3)

                Text("\(artist.tracks.count) tracks · \(albums.count) albums")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button(action: playArtist) {
                        Label("Play Artist", systemImage: "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(theme.accent, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.startRadio(seed: .artist(artist), store: library)
                    } label: {
                        Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .ariesGlass(.regular, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)

                if let tags = detail?.tags, !tags.isEmpty {
                    TagPillRow(tags: tags, accent: theme.accent, maxCount: 5)
                }
            }

            Spacer(minLength: 0)

            portraitView
        }
    }

    @ViewBuilder
    private var portraitView: some View {
        Group {
            if let url = portraitURL {
                CachedArtwork(url: url, size: 180, rounded: true)
            } else {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 180, height: 180)
                    .overlay {
                        Image(systemName: "person.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 180, height: 180)
        .shadow(color: theme.accent.opacity(0.3), radius: 20, y: 8)
    }

    private func applyTheme(from url: URL?) async {
        guard let url, let image = await ArtworkLoader.shared.image(at: url) else { return }
        theme.update(from: image, key: "artist-\(artist.id)")
    }

    private func playArtist() {
        engine.playFromLibrary(artist.tracks, startIndex: 0, store: library)
    }

    private func playAlbum(_ album: AlbumGroup) {
        engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
    }

    private func openSimilarArtist(_ name: String) {
        guard libraryArtist(matching: name, from: library.tracks) != nil else { return }
        navigation.openArtist(name)
    }
}

private struct SimilarArtistsRow: View {
    let names: [String]
    let tracks: [LibraryTrack]
    let accent: Color
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(names, id: \.self) { name in
                if libraryArtist(matching: name, from: tracks) != nil {
                    Button { onSelect(name) } label: {
                        Text(name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                    .help("View in library")
                } else {
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
