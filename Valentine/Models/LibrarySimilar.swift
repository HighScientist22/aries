//
//  LibrarySimilar.swift
//  Aries
//

import Foundation

enum LibrarySimilar {
    static func tracks(for seed: LibraryTrack, in library: LibraryStore, limit: Int = 40) -> [LibraryTrack] {
        var picks: [LibraryTrack] = []
        var seen = Set<UUID>([seed.id])

        func append(_ candidates: [LibraryTrack]) {
            for track in candidates where picks.count < limit {
                guard seen.insert(track.id).inserted else { continue }
                picks.append(track)
            }
        }

        let seedTags = Set(splitGenreTags(from: seed.genre))

        if let album = library.albumGroup(for: seed) {
            append(album.tracks.filter { $0.id != seed.id })
        }

        append(
            library.tracks
                .filter { $0.albumArtist == seed.albumArtist && $0.id != seed.id }
                .shuffled()
        )

        if !seedTags.isEmpty {
            append(
                library.tracks.filter { track in
                    let tags = Set(splitGenreTags(from: track.genre))
                    return !tags.isDisjoint(with: seedTags)
                }.shuffled()
            )

            append(
                library.tracks.filter { track in
                    guard library.rating(for: track.id) >= 4 else { return false }
                    let tags = Set(splitGenreTags(from: track.genre))
                    return !tags.isDisjoint(with: seedTags)
                }.shuffled()
            )

            append(
                library.tracks
                    .filter { track in
                        let tags = Set(splitGenreTags(from: track.genre))
                        return !tags.isDisjoint(with: seedTags) && library.playCount(for: track.id) > 0
                    }
                    .sorted { library.playCount(for: $0.id) > library.playCount(for: $1.id) }
            )
        }

        if library.isFavorite(track: seed) {
            append(library.favoriteTracks.shuffled())
        }

        append(library.tracks.shuffled())
        return picks
    }
}
