//
//  MetadataModels.swift
//  Aries
//

import Foundation

struct EnrichedAlbumDetail: Codable, Equatable {
    let title: String
    let artist: String
    var releaseDate: String?
    var label: String?
    var country: String?
    var summary: String?
    var tags: [String]
    var coverArtURL: URL?
    var musicBrainzID: String?

    init(title: String, artist: String) {
        self.title = title
        self.artist = artist
        self.tags = []
    }
}

struct EnrichedArtistDetail: Codable, Equatable {
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
