//
//  SavedPlaylist.swift
//  Aries
//

import Foundation

struct SavedPlaylist: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var trackIDs: [UUID]
    var dateModified: Date

    init(id: UUID = UUID(), name: String, trackIDs: [UUID] = [], dateModified: Date = Date()) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
        self.dateModified = dateModified
    }
}
