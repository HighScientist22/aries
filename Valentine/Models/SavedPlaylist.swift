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
    var smartRule: SmartPlaylistRule?
    var folderID: UUID?

    var isSmart: Bool { smartRule != nil }

    init(
        id: UUID = UUID(),
        name: String,
        trackIDs: [UUID] = [],
        dateModified: Date = Date(),
        smartRule: SmartPlaylistRule? = nil,
        folderID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
        self.dateModified = dateModified
        self.smartRule = smartRule
        self.folderID = folderID
    }
}

struct PlaylistFolder: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var dateModified: Date

    init(id: UUID = UUID(), name: String, dateModified: Date = Date()) {
        self.id = id
        self.name = name
        self.dateModified = dateModified
    }
}
