//
//  AlbumEditableMetadata.swift
//  Aries
//

import Foundation

struct AlbumEditableMetadata: Equatable, Sendable {
    var artist: String
    var albumTitle: String
    var genre: String
    var year: String

    init(from album: AlbumGroup) {
        artist = album.artist
        albumTitle = album.title
        genre = album.tracks.compactMap(\.genre).first ?? ""
        year = album.tracks.compactMap(\.year).first.map(String.init) ?? ""
    }
}
