//
//  EditableTrackMetadata.swift
//  Aries
//

import Foundation

struct EditableTrackMetadata: Equatable, Sendable {
    var title: String
    var artist: String
    var album: String
    var genre: String
    var year: String
    var trackNumber: String
    var discNumber: String
    var composer: String

    init(from track: LibraryTrack) {
        title = track.title
        artist = track.artist
        album = track.album ?? ""
        genre = track.genre ?? ""
        year = track.year.map(String.init) ?? ""
        trackNumber = track.trackNumber.map(String.init) ?? ""
        discNumber = track.discNumber.map(String.init) ?? ""
        composer = track.composer ?? ""
    }
}
