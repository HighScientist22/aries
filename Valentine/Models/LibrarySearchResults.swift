//
//  LibrarySearchResults.swift
//  Aries
//

import Foundation

struct LibrarySearchResults {
    var tracks: [LibraryTrack]
    var albums: [AlbumGroup]
    var artists: [ArtistGroup]

    var isEmpty: Bool {
        tracks.isEmpty && albums.isEmpty && artists.isEmpty
    }
}
