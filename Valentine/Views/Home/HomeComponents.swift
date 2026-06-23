//
//  HomeComponents.swift
//  Aries
//

import SwiftUI

struct HomeStatCard: View {
    let icon: String
    let label: String
    let value: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ActivityAlbumTile: View {
    let title: String
    let subtitle: String
    let badge: String?
    let artworkURL: URL?
    let accent: Color
    let onOpen: () -> Void
    let onPlay: () -> Void
    @State private var isHovered = false

    private let artSize: CGFloat = 136

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: onOpen) {
                    CachedArtwork(url: artworkURL, size: artSize, rounded: false)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            if let badge {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text(badge)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.black.opacity(0.55), in: Capsule())
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                            }
                        }
                }
                .buttonStyle(.plain)

                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(accent.opacity(0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                .frame(width: artSize, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(width: artSize)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.85)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

struct LibraryTrackRow: View {
    let track: LibraryTrack
    let artworkURL: URL?
    let accent: Color
    var isFavorite: Bool = false
    var onFavorite: (() -> Void)? = nil
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CachedArtwork(url: artworkURL, size: 44, rounded: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(track.duration.formatTime())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let onFavorite {
                    Button(action: onFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(isFavorite ? accent : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(accent)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.small, style: .continuous)
                    .fill(isHovered ? accent.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct HomeSectionRow<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            content
        }
    }
}

struct LibraryMediaTile: View {
    enum Style { case album, artist }

    let title: String
    let subtitle: String
    let artworkURL: URL?
    let style: Style
    let accent: Color
    let onOpen: () -> Void
    let onPlay: () -> Void
    @State private var isHovered = false

    private let artSize: CGFloat = 148

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: onOpen) {
                    CachedArtwork(url: artworkURL, size: artSize, rounded: style == .artist)
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)

                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(accent.opacity(0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: artSize, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
