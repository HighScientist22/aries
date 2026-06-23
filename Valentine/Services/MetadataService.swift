//
//  MetadataService.swift
//  Aries
//

import Foundation

actor MetadataService {
    static let shared = MetadataService()

    private var albumCache: [String: EnrichedAlbumDetail] = [:]
    private var artistCache: [String: EnrichedArtistDetail] = [:]
    private let cacheURL: URL
    private var saveTask: Task<Void, Never>?

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = support.appendingPathComponent("Aries", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        cacheURL = base.appendingPathComponent("metadata-cache.json")
        load()
    }

    func albumDetail(for album: AlbumGroup, libraryArtwork: URL?) async -> EnrichedAlbumDetail {
        let key = album.id
        if let cached = albumCache[key] { return cached }

        var detail = EnrichedAlbumDetail(title: album.title, artist: album.artist)

        async let musicBrainz = MusicBrainzService.shared.lookupRelease(artist: album.artist, album: album.title)
        async let lastFM = LastFMService.shared.fetchAlbumInfo(artist: album.artist, album: album.title)

        if let mb = await musicBrainz {
            detail.musicBrainzID = mb.id
            detail.releaseDate = mb.date
            detail.label = mb.label
            detail.country = mb.country
            if let cover = await MusicBrainzService.shared.coverArtURL(releaseID: mb.id) {
                detail.coverArtURL = cover
            }
        }

        let lastFMResult = await lastFM
        if let summary = lastFMResult.summary { detail.summary = summary }
        if !lastFMResult.tags.isEmpty { detail.tags = lastFMResult.tags }
        if detail.coverArtURL == nil { detail.coverArtURL = libraryArtwork }

        albumCache[key] = detail
        scheduleSave()
        return detail
    }

    func artistDetail(for artist: ArtistGroup, libraryArtwork: URL?) async -> EnrichedArtistDetail {
        let key = artist.id
        if let cached = artistCache[key] { return cached }

        var detail = EnrichedArtistDetail(name: artist.name)

        async let mbid = MusicBrainzService.shared.lookupArtist(name: artist.name)
        async let lastFM = LastFMService.shared.fetchArtistInfo(name: artist.name)

        if let mbid = await mbid {
            detail.musicBrainzID = mbid
        }

        let lastFMResult = await lastFM
        if let summary = lastFMResult.summary { detail.summary = summary }
        if !lastFMResult.tags.isEmpty { detail.tags = lastFMResult.tags }
        if !lastFMResult.similar.isEmpty { detail.similarArtists = lastFMResult.similar }
        detail.imageURL = libraryArtwork ?? lastFMResult.imageURL

        artistCache[key] = detail
        scheduleSave()
        return detail
    }

    private struct CachePayload: Codable {
        var albums: [String: EnrichedAlbumDetail]
        var artists: [String: EnrichedArtistDetail]
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data) else { return }
        albumCache = payload.albums
        artistCache = payload.artists
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    private func persist() {
        let payload = CachePayload(albums: albumCache, artists: artistCache)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
