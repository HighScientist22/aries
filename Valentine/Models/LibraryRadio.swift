//
//  LibraryRadio.swift
//  Aries
//

import Foundation

enum RadioSeed: Sendable {
    case track(LibraryTrack)
    case album(AlbumGroup)
    case artist(ArtistGroup)
}

struct RadioSession: Sendable {
    let seed: RadioSeed
    var playedTrackIDs: Set<UUID> = []
    var similarArtistNames: [String] = []
}

@MainActor
enum LibraryRadio {
    static func displayTitle(for seed: RadioSeed) -> String {
        switch seed {
        case .track(let track):
            return "\(track.title) Radio"
        case .album(let album):
            return "\(album.title) Radio"
        case .artist(let artist):
            return "\(artist.name) Radio"
        }
    }

    static func initialTracks(seed: RadioSeed, library: LibraryStore, limit: Int = 15) -> [LibraryTrack] {
        var session = RadioSession(seed: seed)
        return nextTracks(session: &session, library: library, limit: limit)
    }

    static func nextTracks(
        session: inout RadioSession,
        library: LibraryStore,
        limit: Int = 8
    ) -> [LibraryTrack] {
        var picks: [LibraryTrack] = []
        var seen = session.playedTrackIDs

        func appendUnique(_ candidates: [LibraryTrack]) {
            for track in candidates where picks.count < limit {
                guard !seen.contains(track.id) else { continue }
                picks.append(track)
                seen.insert(track.id)
            }
        }

        switch session.seed {
        case .track(let seedTrack):
            if let album = library.albumGroup(for: seedTrack) {
                appendUnique(album.tracks.filter { $0.id != seedTrack.id }.shuffled())
            }
            appendUnique(library.tracks.filter {
                $0.albumArtist == seedTrack.albumArtist && $0.id != seedTrack.id
            }.shuffled())
            appendUnique(tracksFromSimilarArtists(session.similarArtistNames, library: library, excluding: seen))
            appendUnique(genreMatches(for: seedTrack, in: library, excluding: seen))
            appendUnique(library.tracks.shuffled())

        case .album(let album):
            appendUnique(album.tracks.shuffled())
            let artistAlbums = library.albumGroups.filter {
                $0.id != album.id
                    && ($0.artist == album.artist || $0.tracks.contains { $0.albumArtist == album.artist })
            }.shuffled()
            for other in artistAlbums {
                appendUnique(other.tracks.shuffled())
                if picks.count >= limit { break }
            }
            appendUnique(tracksFromSimilarArtists(session.similarArtistNames, library: library, excluding: seen))
            appendUnique(genreMatches(for: album.tracks.first, in: library, excluding: seen))

        case .artist(let artist):
            appendUnique(artist.tracks.shuffled())
            appendUnique(tracksFromSimilarArtists(session.similarArtistNames, library: library, excluding: seen))
            let relatedArtists = library.artistGroups.filter {
                $0.id != artist.id && sharesGenre(artist, with: $0)
            }.shuffled()
            for related in relatedArtists.prefix(4) {
                appendUnique(related.tracks.shuffled())
                if picks.count >= limit { break }
            }
            appendUnique(library.tracks.shuffled())
        }

        session.playedTrackIDs.formUnion(picks.map(\.id))
        return picks
    }

    private static func tracksFromSimilarArtists(
        _ names: [String],
        library: LibraryStore,
        excluding seen: Set<UUID>
    ) -> [LibraryTrack] {
        guard !names.isEmpty else { return [] }

        var tracks: [LibraryTrack] = []
        for name in names {
            guard let artist = library.artistGroup(named: name) else { continue }
            tracks.append(contentsOf: artist.tracks)
        }

        return tracks
            .filter { !seen.contains($0.id) }
            .shuffled()
    }

    private static func genreMatches(
        for seed: LibraryTrack?,
        in library: LibraryStore,
        excluding seen: Set<UUID>
    ) -> [LibraryTrack] {
        guard let seed else { return [] }
        let seedTags = Set(splitGenreTags(from: seed.genre))
        guard !seedTags.isEmpty else { return [] }

        return library.tracks.filter { track in
            guard !seen.contains(track.id) else { return false }
            let tags = Set(splitGenreTags(from: track.genre))
            return !tags.isDisjoint(with: seedTags)
        }.shuffled()
    }

    private static func sharesGenre(_ lhs: ArtistGroup, with rhs: ArtistGroup) -> Bool {
        let left = Set(lhs.tracks.flatMap { splitGenreTags(from: $0.genre) })
        let right = Set(rhs.tracks.flatMap { splitGenreTags(from: $0.genre) })
        return !left.isDisjoint(with: right)
    }
}
