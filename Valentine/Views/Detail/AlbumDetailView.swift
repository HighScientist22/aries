//
//  AlbumDetailView.swift
//  Aries
//

import SwiftUI

struct AlbumDetailView: View {
    let album: AlbumGroup
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    let onBack: () -> Void
    var onOpenAlbum: ((AlbumGroup) -> Void)? = nil

    @State private var detail: EnrichedAlbumDetail?
    @State private var isLoading = true

    private var libraryArtwork: URL? {
        library.artworkURL(for: album.artworkFile)
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailBackBar(title: album.title, accent: theme.accent, onBack: onBack) {
                FavoriteHeartButton(
                    isFavorite: library.isFavorite(album: album),
                    accent: theme.accent
                ) {
                    library.toggleFavorite(album: album)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(alignment: .top, spacing: 28) {
                        CachedArtwork(
                            url: libraryArtwork ?? detail?.coverArtURL,
                            size: 220,
                            rounded: false
                        )
                        .shadow(color: theme.accent.opacity(0.35), radius: 24, y: 10)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(album.title)
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .lineLimit(3)

                            Text(album.artist)
                                .font(.title2)
                                .foregroundStyle(.secondary)

                            metadataLine

                            HStack(spacing: 12) {
                                Button(action: { playAlbum(shuffle: false) }) {
                                    Label("Play Album", systemImage: "play.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(theme.accent, in: Capsule())
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)

                                Button(action: { playAlbum(shuffle: true) }) {
                                    Label("Shuffle", systemImage: "shuffle")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(.ultraThinMaterial, in: Capsule())
                                        .ariesGlass(.regular, in: Capsule())
                                }
                                .buttonStyle(.plain)

                                Button(action: { engine.startRadio(seed: .album(album), store: library) }) {
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
                                TagPillRow(tags: tags, accent: theme.accent)
                            }
                        }

                        Spacer(minLength: 0)
                    }

                    if let summary = detail?.summary, !summary.isEmpty {
                        GlassCard {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                    }

                    if let credits = detail?.credits, !credits.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Credits")
                                    .font(.headline)
                                ForEach(credits) { credit in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(credit.role)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 72, alignment: .leading)
                                        Text(credit.name)
                                            .font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    let alternateVersions = library.alternateAlbumVersions(for: album)
                    if !alternateVersions.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Other Versions")
                                    .font(.headline)
                                ForEach(alternateVersions) { version in
                                    Button {
                                        onOpenAlbum?(version)
                                    } label: {
                                        HStack(spacing: 12) {
                                            CachedArtwork(url: library.artworkURL(for: version.artworkFile), size: 48, rounded: false)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(version.title)
                                                    .font(.subheadline.weight(.medium))
                                                Text("\(version.tracks.count) tracks · \(version.artist)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracks")
                                .font(.headline)
                            ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                                Button {
                                    playTrack(at: index)
                                } label: {
                                    HStack(spacing: 14) {
                                        Text("\(index + 1)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                            .frame(width: 24, alignment: .trailing)
                                        CachedArtwork(url: library.artworkURL(for: track), size: 40, rounded: false)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(track.title)
                                                .font(.subheadline.weight(.medium))
                                                .lineLimit(1)
                                            if track.artist != album.artist {
                                                Text(track.artist)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Text(track.duration.formatTime())
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .libraryPlaybackMenu(
                                    engine: engine,
                                    library: library,
                                    tracks: album.tracks,
                                    startIndex: index,
                                    album: album
                                )
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
                ProgressView("Loading album info…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onExitCommand(perform: onBack)
        .task(id: album.id) {
            isLoading = true
            let releaseID = library.musicBrainzReleaseID(for: album)
            let loaded = await MetadataService.shared.albumDetail(
                for: album,
                libraryArtwork: libraryArtwork,
                preferredReleaseID: releaseID
            )
            detail = loaded
            isLoading = false
            if let url = libraryArtwork ?? loaded.coverArtURL,
               let image = await ArtworkLoader.shared.image(at: url) {
                theme.update(from: image, key: "album-\(album.id)")
            }
        }
    }

    @ViewBuilder
    private var metadataLine: some View {
        let parts = [
            detail?.releaseDate.map { String($0.prefix(4)) },
            detail?.label,
            "\(album.tracks.count) tracks"
        ].compactMap { $0 }.filter { !$0.isEmpty }

        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private func playAlbum(shuffle: Bool) {
        engine.playFromLibrary(album.tracks, startIndex: 0, store: library, shuffleTracks: shuffle)
    }

    private func playTrack(at index: Int) {
        engine.playFromLibrary(album.tracks, startIndex: index, store: library)
    }
}
