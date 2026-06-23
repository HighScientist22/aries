//
//  SmartPlaylistRule.swift
//  Aries
//

import Foundation

enum SmartPlaylistRule: Codable, Hashable {
    case favorites
    case recentlyPlayed
    case genre(String)
    case artist(String)
    case year(Int)
    case custom(matchAll: Bool, criteria: [SmartPlaylistCriterion])

    var defaultName: String {
        switch self {
        case .favorites: return "Favorite Tracks"
        case .recentlyPlayed: return "Recently Played"
        case .genre(let name): return name
        case .artist(let name): return name
        case .year(let year): return "\(year)"
        case .custom(_, let criteria):
            if let first = criteria.first {
                return "\(first.field.label) \(first.match.label) \(first.value)"
            }
            return "Smart Playlist"
        }
    }

    var summary: String {
        switch self {
        case .favorites: return "Favorite tracks"
        case .recentlyPlayed: return "Recently played tracks"
        case .genre(let name): return "Genre is \(name)"
        case .artist(let name): return "Artist is \(name)"
        case .year(let year): return "Year is \(year)"
        case .custom(let matchAll, let criteria):
            let joiner = matchAll ? " AND " : " OR "
            return criteria.map { "\($0.field.label) \($0.match.label) \($0.value)" }.joined(separator: joiner)
        }
    }
}
