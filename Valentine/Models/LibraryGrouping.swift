//
//  LibraryGrouping.swift
//  Aries
//

import Foundation

struct AlbumGroup: Identifiable, Hashable {
    let title: String
    let artist: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { "\(title)|\(artist)" }
}

struct ArtistGroup: Identifiable, Hashable {
    let name: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { name }
}

func groupAlbums(from tracks: [LibraryTrack]) -> [AlbumGroup] {
    let grouped = Dictionary(grouping: tracks) { track in
        "\(track.album ?? track.title)|\(track.albumArtist)"
    }
    return grouped.map { _, group in
        let ordered = group.sorted { lhs, rhs in
            lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
        let first = ordered.first
        return AlbumGroup(
            title: first?.album ?? first?.title ?? "Unknown Album",
            artist: first?.albumArtist ?? first?.artist ?? "Unknown Artist",
            artworkFile: ordered.first(where: { $0.artworkFile != nil })?.artworkFile,
            tracks: ordered
        )
    }
    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
}

func groupArtists(from tracks: [LibraryTrack]) -> [ArtistGroup] {
    let grouped = Dictionary(grouping: tracks) { $0.albumArtist }
    return grouped.map { name, artistTracks in
        ArtistGroup(
            name: name,
            artworkFile: artistTracks.first(where: { $0.artworkFile != nil })?.artworkFile,
            tracks: artistTracks.sorted {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        )
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

func artistGroup(named name: String, from tracks: [LibraryTrack]) -> ArtistGroup {
    let matching = tracks.filter { $0.albumArtist == name || $0.artist == name }
    return ArtistGroup(
        name: name,
        artworkFile: matching.first(where: { $0.artworkFile != nil })?.artworkFile,
        tracks: matching.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    )
}

func libraryArtist(matching name: String, from tracks: [LibraryTrack]) -> ArtistGroup? {
    let direct = artistGroup(named: name, from: tracks)
    if !direct.tracks.isEmpty { return direct }

    let lowered = name.lowercased()
    guard let match = tracks.first(where: {
        $0.artist.lowercased() == lowered || $0.albumArtist.lowercased() == lowered
    }) else { return nil }

    return artistGroup(named: match.albumArtist, from: tracks)
}

func matchingAlbums(forArtist artist: ArtistGroup, in albumGroups: [AlbumGroup]) -> [AlbumGroup] {
    albumGroups.filter { album in
        album.tracks.contains { $0.albumArtist == artist.name || $0.artist == artist.name }
    }
}
