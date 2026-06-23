//
//  ArtistDetailView.swift
//  Aries
//

import SwiftUI
import AppKit

struct ArtistDetailView: View {
    let artist: ArtistGroup
    let albums: [AlbumGroup]
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    let onBack: () -> Void

    @State private var detail: EnrichedArtistDetail?
    @State private var isLoading = true

    private var libraryArtwork: URL? {
        library.artworkURL(for: artist.artworkFile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerBar

                HStack(alignment: .top, spacing: 24) {
                    Group {
                        if let url = detail?.imageURL ?? libraryArtwork {
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
                    .shadow(color: theme.accent.opacity(0.3), radius: 20, y: 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(artist.name)
                            .font(.system(size: 36, weight: .bold, design: .serif))
                            .lineLimit(2)

                        Text("\(artist.tracks.count) tracks · \(albums.count) albums")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button(action: playArtist) {
                            Label("Play Artist", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        if let tags = detail?.tags, !tags.isEmpty {
                            ArtistTagRow(tags: tags, accent: theme.accent)
                        }
                    }

                    Spacer(minLength: 0)
                }

                if let summary = detail?.summary, !summary.isEmpty {
                    glassCard {
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(4)
                    }
                }

                if let similar = detail?.similarArtists, !similar.isEmpty {
                    glassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Similar Artists")
                                .font(.headline)
                            Text(similar.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                glassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Discography")
                            .font(.headline)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 18)],
                            spacing: 20
                        ) {
                            ForEach(albums) { album in
                                Button {
                                    playAlbum(album)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        CachedArtwork(
                                            url: library.artworkURL(for: album.artworkFile),
                                            size: 140,
                                            rounded: false
                                        )
                                        Text(album.title)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Text("\(album.tracks.count) tracks")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .overlay {
            if isLoading && detail == nil {
                ProgressView("Loading artist info…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task(id: artist.id) {
            isLoading = true
            let loaded = await MetadataService.shared.artistDetail(for: artist, libraryArtwork: libraryArtwork)
            detail = loaded
            isLoading = false
            if let url = loaded.imageURL, let image = NSImage(contentsOf: url) {
                theme.update(from: image, key: "artist-\(artist.id)")
            } else if let url = libraryArtwork, let image = NSImage(contentsOf: url) {
                theme.update(from: image, key: "artist-\(artist.id)")
            }
        }
    }

    private var headerBar: some View {
        Button(action: onBack) {
            Label("Back", systemImage: "chevron.left")
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.accent)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.45))
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
    }

    private func playArtist() {
        engine.playFromLibrary(artist.tracks, startIndex: 0, store: library)
    }

    private func playAlbum(_ album: AlbumGroup) {
        engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
    }
}

private struct ArtistTagRow: View {
    let tags: [String]
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tags.prefix(5), id: \.self) { tag in
                Text(tag)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(accent)
            }
        }
    }
}
