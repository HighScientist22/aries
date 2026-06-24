//
//  ListeningStatsExport.swift
//  Aries
//

import Foundation

enum ListeningStatsExport {
    static func jsonData(from store: LibraryStore) throws -> Data {
        let payload = ExportPayload(
            exportedAt: Date(),
            totalPlays: store.totalPlayCount,
            totalListenSeconds: store.totalListenSeconds,
            genres: store.genreListeningStats.map {
                ExportGenreStat(name: $0.name, playCount: $0.playCount, listenSeconds: $0.listenSeconds)
            },
            artists: store.artistListeningStats.map {
                ExportNamedStat(
                    name: $0.title,
                    playCount: $0.playCount,
                    listenSeconds: $0.listenSeconds
                )
            },
            albums: store.albumListeningStats.map {
                ExportNamedStat(
                    name: $0.title,
                    subtitle: $0.subtitle,
                    playCount: $0.playCount,
                    listenSeconds: $0.listenSeconds
                )
            },
            tracks: store.tracks.compactMap { track -> ExportTrackStat? in
                let plays = store.playCount(for: track.id)
                guard plays > 0 || store.lastPlayed(for: track.id) != nil else { return nil }
                return ExportTrackStat(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    genre: track.genre,
                    playCount: plays,
                    lastPlayed: store.lastPlayed(for: track.id)
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func csvString(from store: LibraryStore) -> String {
        var rows = ["title,artist,album,genre,play_count,last_played"]
        for track in store.tracks {
            let plays = store.playCount(for: track.id)
            guard plays > 0 || store.lastPlayed(for: track.id) != nil else { continue }
            let lastPlayed = store.lastPlayed(for: track.id).map(isoDate) ?? ""
            rows.append(
                [
                    csvEscaped(track.title),
                    csvEscaped(track.artist),
                    csvEscaped(track.album ?? ""),
                    csvEscaped(track.genre ?? ""),
                    "\(plays)",
                    csvEscaped(lastPlayed)
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    private static func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func csvEscaped(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}

private struct ExportPayload: Codable {
    let exportedAt: Date
    let totalPlays: Int
    let totalListenSeconds: TimeInterval
    let genres: [ExportGenreStat]
    let artists: [ExportNamedStat]
    let albums: [ExportNamedStat]
    let tracks: [ExportTrackStat]
}

private struct ExportGenreStat: Codable {
    let name: String
    let playCount: Int
    let listenSeconds: TimeInterval
}

private struct ExportNamedStat: Codable {
    let name: String
    var subtitle: String? = nil
    let playCount: Int
    let listenSeconds: TimeInterval
}

private struct ExportTrackStat: Codable {
    let title: String
    let artist: String
    let album: String?
    let genre: String?
    let playCount: Int
    let lastPlayed: Date?
}
