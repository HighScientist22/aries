//
//  SmartPlaylistCriterion.swift
//  Aries
//

import Foundation

enum SmartCriterionField: String, Codable, CaseIterable, Identifiable {
    case genre
    case artist
    case album
    case title
    case year
    case isFavorite
    case recentlyPlayed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .genre: return "Genre"
        case .artist: return "Artist"
        case .album: return "Album"
        case .title: return "Title"
        case .year: return "Year"
        case .isFavorite: return "Favorite"
        case .recentlyPlayed: return "Recently Played"
        }
    }

    var isBoolean: Bool {
        self == .isFavorite || self == .recentlyPlayed
    }
}

enum SmartCriterionMatch: String, Codable, CaseIterable, Identifiable {
    case contains
    case equals
    case notEquals
    case greaterThan
    case lessThan

    var id: String { rawValue }

    var label: String {
        switch self {
        case .contains: return "contains"
        case .equals: return "is"
        case .notEquals: return "is not"
        case .greaterThan: return "after"
        case .lessThan: return "before"
        }
    }

    static func options(for field: SmartCriterionField) -> [SmartCriterionMatch] {
        switch field {
        case .year:
            return [.equals, .greaterThan, .lessThan]
        case .isFavorite, .recentlyPlayed:
            return [.equals]
        default:
            return [.contains, .equals, .notEquals]
        }
    }
}

struct SmartPlaylistCriterion: Codable, Hashable, Identifiable {
    var id: UUID
    var field: SmartCriterionField
    var match: SmartCriterionMatch
    var value: String

    init(
        id: UUID = UUID(),
        field: SmartCriterionField = .genre,
        match: SmartCriterionMatch = .contains,
        value: String = ""
    ) {
        self.id = id
        self.field = field
        self.match = match
        self.value = value
    }
}

func evaluateSmartCriterion(
    _ criterion: SmartPlaylistCriterion,
    track: LibraryTrack,
    store: LibraryStore
) -> Bool {
    switch criterion.field {
    case .genre:
        guard let genre = track.genre else { return false }
        return compareText(genre, match: criterion.match, value: criterion.value)
    case .artist:
        return compareText(track.albumArtist, match: criterion.match, value: criterion.value)
            || compareText(track.artist, match: criterion.match, value: criterion.value)
    case .album:
        return compareText(track.album ?? "", match: criterion.match, value: criterion.value)
    case .title:
        return compareText(track.title, match: criterion.match, value: criterion.value)
    case .year:
        guard let year = track.year else { return false }
        return compareYear(year, match: criterion.match, value: criterion.value)
    case .isFavorite:
        let isFavorite = store.isFavorite(track: track)
        return criterion.value == "true" ? isFavorite : !isFavorite
    case .recentlyPlayed:
        let isRecent = store.recentlyPlayedIDs.contains(track.id)
        return criterion.value == "true" ? isRecent : !isRecent
    }
}

private func compareText(_ text: String, match: SmartCriterionMatch, value: String) -> Bool {
    switch match {
    case .contains:
        return text.localizedCaseInsensitiveContains(value)
    case .equals:
        return text.localizedCaseInsensitiveCompare(value) == .orderedSame
    case .notEquals:
        return text.localizedCaseInsensitiveCompare(value) != .orderedSame
    case .greaterThan, .lessThan:
        return false
    }
}

private func compareYear(_ year: Int, match: SmartCriterionMatch, value: String) -> Bool {
    guard let target = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
    switch match {
    case .equals: return year == target
    case .greaterThan: return year > target
    case .lessThan: return year < target
    default: return false
    }
}
