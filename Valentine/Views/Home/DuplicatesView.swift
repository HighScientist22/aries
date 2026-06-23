//
//  DuplicatesView.swift
//  Aries
//

import SwiftUI

struct DuplicatesView: View {
    @ObservedObject var library: LibraryStore
    let accent: Color
    var onOpenAlbum: (LibraryTrack) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Duplicates")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                if library.duplicateGroups.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No duplicates found")
                                .font(.headline)
                            Text("Identify your library in Settings → Library to match tracks with MusicBrainz and surface duplicate recordings.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("\(library.duplicateGroups.count) duplicate groups")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(library.duplicateGroups) { group in
                        duplicateGroupCard(group)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func duplicateGroupCard(_ group: DuplicateTrackGroup) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(group.reason)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(group.trackIDs, id: \.self) { trackID in
                    if let track = library.tracks.first(where: { $0.id == trackID }) {
                        duplicateRow(track, group: group)
                    }
                }
            }
        }
    }

    private func duplicateRow(_ track: LibraryTrack, group: DuplicateTrackGroup) -> some View {
        HStack(spacing: 12) {
            CachedArtwork(url: library.artworkURL(for: track), size: 44, rounded: false)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(track.artist) · \(track.album ?? "Unknown Album")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let path = library.resolveURL(for: track)?.path {
                    Text((path as NSString).lastPathComponent)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if let identification = library.identification(for: track.id), identification.source != .unknown {
                    Text(identification.source == .acoustID ? "AcoustID match" : "MusicBrainz match")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if group.preferredTrackID == track.id {
                Text("Primary")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.15), in: Capsule())
            } else {
                Button("Keep") {
                    library.setPreferredDuplicate(trackID: track.id, in: group.id)
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.medium))
                .foregroundStyle(accent)
            }

            Button {
                onOpenAlbum(track)
            } label: {
                Image(systemName: "square.stack")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Album")
        }
        .padding(.vertical, 4)
    }
}
