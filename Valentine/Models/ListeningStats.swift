//
//  ListeningStats.swift
//  Aries
//

import Foundation

struct ListeningStats: Codable {
    var genrePlayCounts: [String: Int] = [:]
    var genreListenSeconds: [String: Double] = [:]
}

struct GenreListeningStat: Identifiable, Hashable {
    let name: String
    let playCount: Int
    let listenSeconds: TimeInterval

    var id: String { name }
}

func splitGenreTags(from raw: String?) -> [String] {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return []
    }
    return raw.split { $0 == ";" || $0 == "/" || $0 == "," }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}
