//
//  MetadataModels.swift
//  Aries
//

import Foundation

nonisolated struct AlbumCredit: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let role: String
}

nonisolated struct EnrichedAlbumDetail: Codable, Equatable, Sendable {
    let title: String
    let artist: String
    var releaseDate: String?
    var label: String?
    var country: String?
    var summary: String?
    var tags: [String]
    var credits: [AlbumCredit]
    var coverArtURL: URL?
    var musicBrainzID: String?

    init(title: String, artist: String) {
        self.title = title
        self.artist = artist
        self.tags = []
        self.credits = []
    }
}

nonisolated struct EnrichedArtistDetail: Codable, Equatable, Sendable {
    let name: String
    var summary: String?
    var tags: [String]
    var similarArtists: [String]
    var imageURL: URL?
    var musicBrainzID: String?

    init(name: String) {
        self.name = name
        self.tags = []
        self.similarArtists = []
    }
}
