//
//  LibraryTrack.swift
//  Aries
//

import Foundation

// A persistable record of a track in the user's library. Unlike `Track`, this
// survives relaunches: the file is referenced by a bookmark and artwork is
// cached to disk by `artworkFile` rather than held in memory.
struct LibraryTrack: Codable, Identifiable, Hashable {
    let id: UUID
    var bookmark: Data
    var title: String
    var artist: String
    var album: String?
    var duration: TimeInterval
    var artworkFile: String?
    var dateAdded: Date

    // The primary artist, with featured-artist credits removed, so grouping
    // collapses "X feat. Y", "X & Y", "X, Y" into a single "X".
    var albumArtist: String {
        let separators = [" feat. ", " feat ", " ft. ", " ft ", " featuring ", " with ", " & ", ", ", " x ", " vs. ", " vs "]
        var name = artist
        for separator in separators {
            if let range = name.range(of: separator, options: [.caseInsensitive]) {
                name = String(name[..<range.lowerBound])
            }
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? artist : trimmed
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LibraryTrack, rhs: LibraryTrack) -> Bool {
        lhs.id == rhs.id
    }
}
