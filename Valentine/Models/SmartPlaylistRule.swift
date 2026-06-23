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

    var defaultName: String {
        switch self {
        case .favorites: return "Favorite Tracks"
        case .recentlyPlayed: return "Recently Played"
        case .genre(let name): return name
        case .artist(let name): return name
        case .year(let year): return "\(year)"
        }
    }
}
