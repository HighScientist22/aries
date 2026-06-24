//
//  LibraryGrouping.swift
//  Aries
//

import Foundation

nonisolated struct AlbumGroup: Identifiable, Hashable, Sendable {
    let title: String
    let artist: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { "\(title)|\(artist)" }
}

nonisolated struct ArtistGroup: Identifiable, Hashable, Sendable {
    let name: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { name }
}

nonisolated struct GenreGroup: Identifiable, Hashable, Sendable {
    let name: String
    let tracks: [LibraryTrack]
    var id: String { name }
}

nonisolated struct YearGroup: Identifiable, Hashable, Sendable {
    let year: Int
    let tracks: [LibraryTrack]
    var id: Int { year }
}

nonisolated struct ComposerGroup: Identifiable, Hashable, Sendable {
    let name: String
    let tracks: [LibraryTrack]
    var id: String { name }
}

nonisolated struct FolderGroup: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let tracks: [LibraryTrack]
    var id: String { path }
}

nonisolated func groupAlbums(from tracks: [LibraryTrack]) -> [AlbumGroup] {
    let grouped = Dictionary(grouping: tracks) { track in
        "\(track.album ?? track.title)|\(track.albumArtist)"
    }
    return grouped.map { _, group in
        let ordered = group.sorted(by: sortTracksForAlbum)
        let first = ordered.first
        return AlbumGroup(
            title: first?.album ?? first?.title ?? "Unknown Album",
            artist: first?.albumArtist ?? first?.artist ?? "Unknown Artist",
            artworkFile: ordered.first(where: { $0.artworkFile != nil })?.artworkFile,
            tracks: ordered
        )
    }
    .sorted {
        let artistOrder = $0.artist.localizedCaseInsensitiveCompare($1.artist)
        if artistOrder != .orderedSame {
            return artistOrder == .orderedAscending
        }
        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
    }
}

nonisolated func groupArtists(from tracks: [LibraryTrack]) -> [ArtistGroup] {
    let grouped = Dictionary(grouping: tracks) { $0.albumArtist }
    return grouped.map { name, artistTracks in
        ArtistGroup(
            name: name,
            artworkFile: artistTracks.first(where: { $0.artworkFile != nil })?.artworkFile,
            tracks: artistTracks.sorted(by: sortTracksForAlbum)
        )
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

nonisolated func groupGenres(from tracks: [LibraryTrack]) -> [GenreGroup] {
    var grouped: [String: [LibraryTrack]] = [:]
    for track in tracks {
        let tags = splitGenreTags(from: track.genre)
        guard !tags.isEmpty else { continue }
        for name in tags {
            grouped[name, default: []].append(track)
        }
    }
    return grouped.map { name, genreTracks in
        GenreGroup(name: name, tracks: genreTracks.sorted(by: sortTracksForAlbum))
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

nonisolated func groupYears(from tracks: [LibraryTrack]) -> [YearGroup] {
    let withYears = tracks.compactMap { track -> (Int, LibraryTrack)? in
        guard let year = track.year else { return nil }
        return (year, track)
    }
    let grouped = Dictionary(grouping: withYears, by: \.0)
    return grouped.map { year, pairs in
        YearGroup(year: year, tracks: pairs.map(\.1).sorted(by: sortTracksForAlbum))
    }
    .sorted { $0.year > $1.year }
}

nonisolated func groupComposers(from tracks: [LibraryTrack]) -> [ComposerGroup] {
    let withComposer = tracks.compactMap { track -> (String, LibraryTrack)? in
        guard let composer = track.composer?.trimmingCharacters(in: .whitespacesAndNewlines),
              !composer.isEmpty else { return nil }
        return (composer, track)
    }
    let grouped = Dictionary(grouping: withComposer, by: \.0)
    return grouped.map { name, pairs in
        ComposerGroup(name: name, tracks: pairs.map(\.1).sorted(by: sortTracksForAlbum))
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

func albumsForGenre(_ genre: GenreGroup, from albumGroups: [AlbumGroup]) -> [AlbumGroup] {
    let trackIDs = Set(genre.tracks.map(\.id))
    return albumGroups.filter { album in
        album.tracks.contains { trackIDs.contains($0.id) }
    }
}

func albumGroup(for track: LibraryTrack, in albumGroups: [AlbumGroup]) -> AlbumGroup? {
    albumGroups.first { group in
        group.tracks.contains { $0.id == track.id }
    }
}

func albumGroup(for track: LibraryTrack, in tracks: [LibraryTrack]) -> AlbumGroup? {
    let albumTitle = track.album ?? track.title
    let matching = tracks.filter {
        ($0.album ?? $0.title) == albumTitle
            && ($0.albumArtist == track.albumArtist || $0.artist == track.artist)
    }
    guard !matching.isEmpty else { return nil }
    let ordered = matching.sorted(by: sortTracksForAlbum)
    return AlbumGroup(
        title: albumTitle,
        artist: track.albumArtist,
        artworkFile: ordered.first(where: { $0.artworkFile != nil })?.artworkFile,
        tracks: ordered
    )
}

nonisolated func sortTracksForAlbum(_ lhs: LibraryTrack, _ rhs: LibraryTrack) -> Bool {
    if let leftDisc = lhs.discNumber, let rightDisc = rhs.discNumber, leftDisc != rightDisc {
        return leftDisc < rightDisc
    }
    if let leftTrack = lhs.trackNumber, let rightTrack = rhs.trackNumber, leftTrack != rightTrack {
        return leftTrack < rightTrack
    }
    return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
}

func artistGroup(named name: String, from tracks: [LibraryTrack]) -> ArtistGroup {
    let matching = tracks.filter { $0.albumArtist == name || $0.artist == name }
    return ArtistGroup(
        name: name,
        artworkFile: matching.first(where: { $0.artworkFile != nil })?.artworkFile,
        tracks: matching.sorted(by: sortTracksForAlbum)
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
