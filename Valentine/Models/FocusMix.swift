//
//  FocusMix.swift
//  Aries
//

import Foundation

struct FocusMix: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
}

struct PlayHistoryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let trackID: UUID
    let playedAt: Date

    init(id: UUID = UUID(), trackID: UUID, playedAt: Date = Date()) {
        self.id = id
        self.trackID = trackID
        self.playedAt = playedAt
    }
}

struct ListeningTimelineItem: Identifiable, Hashable {
    let id: UUID
    let track: LibraryTrack
    let playedAt: Date
}

struct ListeningTimelineDay: Identifiable, Hashable {
    let date: Date
    let items: [ListeningTimelineItem]

    var id: String {
        Calendar.current.startOfDay(for: date).ISO8601Format()
    }
}
