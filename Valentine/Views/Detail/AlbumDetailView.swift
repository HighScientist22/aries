//
//  AlbumDetailView.swift
//  Aries
//

import SwiftUI
import AppKit

struct AlbumDetailView: View {
    let album: AlbumGroup
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    let onBack: () -> Void

    @State private var detail: EnrichedAlbumDetail?
    @State private var isLoading = true

    private var libraryArtwork: URL? {
        library.artworkURL(for: album.artworkFile)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                headerBar

                HStack(alignment: .top, spacing: 28) {
                    CachedArtwork(
                        url: detail?.coverArtURL ?? libraryArtwork,
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
                                    .glassEffect(.regular, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 4)

                        if let tags = detail?.tags, !tags.isEmpty {
                            TagRow(tags: tags, accent: theme.accent)
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

                glassCard {
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
                        }
                    }
                }
            }
            .padding(32)
        }
        .overlay {
            if isLoading && detail == nil {
                ProgressView("Loading album info…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task(id: album.id) {
            isLoading = true
            let loaded = await MetadataService.shared.albumDetail(for: album, libraryArtwork: libraryArtwork)
            detail = loaded
            isLoading = false
            if let url = loaded.coverArtURL, let image = NSImage(contentsOf: url) {
                theme.update(from: image, key: "album-\(album.id)")
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

    private func playAlbum(shuffle: Bool) {
        engine.shuffleMode = shuffle
        engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
    }

    private func playTrack(at index: Int) {
        engine.playFromLibrary(album.tracks, startIndex: index, store: library)
    }
}

private struct TagRow: View {
    let tags: [String]
    let accent: Color

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
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

/// Simple left-to-right wrapping layout for genre/tag pills.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var frames: [CGRect] = []

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}
