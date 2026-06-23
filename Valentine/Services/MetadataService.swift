//
//  MetadataService.swift
//  Aries
//

import Foundation

@MainActor
final class MetadataService {
    static let shared = MetadataService()

    private var albumCache: [String: EnrichedAlbumDetail] = [:]
    private var artistCache: [String: EnrichedArtistDetail] = [:]
    private let cacheURL: URL

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

        if let mb = await MusicBrainzService.shared.lookupRelease(artist: album.artist, album: album.title) {
            detail.musicBrainzID = mb.id
            detail.releaseDate = mb.date
            detail.label = mb.label
            detail.country = mb.country
            if let cover = await MusicBrainzService.shared.coverArtURL(releaseID: mb.id) {
                detail.coverArtURL = cover
            }
        }

        if detail.coverArtURL == nil {
            detail.coverArtURL = libraryArtwork
        }

        let lastFM = await LastFMService.shared.fetchAlbumInfo(artist: album.artist, album: album.title)
        if let summary = lastFM.summary { detail.summary = summary }
        if !lastFM.tags.isEmpty { detail.tags = lastFM.tags }

        albumCache[key] = detail
        persist()
        return detail
    }

    func artistDetail(for artist: ArtistGroup, libraryArtwork: URL?) async -> EnrichedArtistDetail {
        let key = artist.id
        if let cached = artistCache[key] { return cached }

        var detail = EnrichedArtistDetail(name: artist.name)

        if let mbid = await MusicBrainzService.shared.lookupArtist(name: artist.name) {
            detail.musicBrainzID = mbid
        }

        let lastFM = await LastFMService.shared.fetchArtistInfo(name: artist.name)
        if let summary = lastFM.summary { detail.summary = summary }
        if !lastFM.tags.isEmpty { detail.tags = lastFM.tags }
        if !lastFM.similar.isEmpty { detail.similarArtists = lastFM.similar }
        detail.imageURL = lastFM.imageURL ?? libraryArtwork

        artistCache[key] = detail
        persist()
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

    private func persist() {
        let payload = CachePayload(albums: albumCache, artists: artistCache)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
