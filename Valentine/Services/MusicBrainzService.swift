//
//  MusicBrainzService.swift
//  Aries
//

import Foundation

actor MusicBrainzService {
    static let shared = MusicBrainzService()

    private let baseURL = "https://musicbrainz.org/ws/2"
    private let userAgent = "Aries/1.2 (https://github.com/HighScientist22/aries)"
    private var lastRequest: Date = .distantPast

    private struct SearchResponse: Decodable {
        struct Release: Decodable {
            let id: String
            let title: String?
            let date: String?
            let country: String?
            let labelInfo: [LabelInfo]?
            let releaseGroup: ReleaseGroupRef?

            struct LabelInfo: Decodable {
                let label: Label?
                struct Label: Decodable { let name: String? }
            }

            struct ReleaseGroupRef: Decodable {
                let id: String
            }
        }
        struct Artist: Decodable {
            let id: String
            let name: String?
        }
        struct Recording: Decodable {
            let id: String
            let title: String?
            let length: Int?
            let score: Int?
            let releases: [Release]?

            struct Release: Decodable {
                let id: String
                let title: String?
                let releaseGroup: ReleaseGroupRef?

                struct ReleaseGroupRef: Decodable {
                    let id: String
                }
            }
        }
        let releases: [Release]?
        let artists: [Artist]?
        let recordings: [Recording]?
    }

    struct ReleaseMatch: Sendable {
        let id: String
        let date: String?
        let label: String?
        let country: String?
        let releaseGroupID: String?
    }

    struct RecordingMatch: Sendable {
        let recordingID: String
        let releaseID: String?
        let releaseGroupID: String?
        let title: String?
        let confidence: Double
    }

    func lookupReleaseMatch(artist: String, album: String) async -> ReleaseMatch? {
        let query = "release:\"\(escape(album))\" AND artist:\"\(escape(artist))\""
        guard let url = URL(string: "\(baseURL)/release?query=\(encoded(query))&fmt=json&limit=5") else { return nil }

        guard let data = await request(url: url) else { return nil }
        guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let release = response.releases?.first else { return nil }

        let label = release.labelInfo?.first?.label?.name
        return ReleaseMatch(
            id: release.id,
            date: release.date,
            label: label,
            country: release.country,
            releaseGroupID: release.releaseGroup?.id
        )
    }

    func lookupRelease(artist: String, album: String) async -> (id: String, date: String?, label: String?, country: String?)? {
        guard let match = await lookupReleaseMatch(artist: artist, album: album) else { return nil }
        return (match.id, match.date, match.label, match.country)
    }

    func lookupRecording(artist: String, title: String, durationMs: Int?) async -> RecordingMatch? {
        let query = "recording:\"\(escape(title))\" AND artist:\"\(escape(artist))\""
        guard let url = URL(string: "\(baseURL)/recording?query=\(encoded(query))&fmt=json&limit=8&inc=releases") else { return nil }

        guard let data = await request(url: url) else { return nil }
        guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let recordings = response.recordings,
              !recordings.isEmpty else { return nil }

        let ranked = recordings.map { recording -> (SearchResponse.Recording, Double) in
            var score = Double(recording.score ?? 0) / 100.0
            let normalizedTitle = normalizeMetadataToken(recording.title ?? "")
            let normalizedTarget = normalizeMetadataToken(title)
            if normalizedTitle == normalizedTarget { score += 0.35 }
            if let durationMs, let length = recording.length {
                let delta = abs(durationMs - length)
                if delta <= 2_000 { score += 0.35 }
                else if delta <= 8_000 { score += 0.15 }
            }
            return (recording, min(score, 1.0))
        }
        .sorted { $0.1 > $1.1 }

        guard let best = ranked.first, best.1 >= 0.45 else { return nil }
        let recording = best.0
        let release = recording.releases?.first
        return RecordingMatch(
            recordingID: recording.id,
            releaseID: release?.id,
            releaseGroupID: release?.releaseGroup?.id,
            title: recording.title,
            confidence: best.1
        )
    }

    func lookupArtist(name: String) async -> String? {
        let query = "artist:\"\(escape(name))\""
        guard let url = URL(string: "\(baseURL)/artist?query=\(encoded(query))&fmt=json&limit=3") else { return nil }

        guard let data = await request(url: url) else { return nil }
        guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let artist = response.artists?.first else { return nil }
        return artist.id
    }

    func releaseCredits(releaseID: String) async -> [AlbumCredit] {
        guard let url = URL(string: "\(baseURL)/release/\(releaseID)?inc=artist-credits&fmt=json") else { return [] }
        guard let data = await request(url: url) else { return [] }

        struct ReleaseDetail: Decodable {
            struct ArtistCredit: Decodable {
                let name: String?
                let artist: ArtistRef?
                struct ArtistRef: Decodable { let name: String? }
            }
            let artistCredit: [ArtistCredit]?

            enum CodingKeys: String, CodingKey {
                case artistCredit = "artist-credit"
            }
        }

        guard let release = try? JSONDecoder().decode(ReleaseDetail.self, from: data),
              let credits = release.artistCredit,
              !credits.isEmpty else { return [] }

        let names = credits.compactMap { $0.name ?? $0.artist?.name }
        guard !names.isEmpty else { return [] }
        return [AlbumCredit(id: "release-artists", name: names.joined(separator: ", "), role: "Artists")]
    }

    func coverArtURL(releaseID: String) async -> URL? {
        let url = URL(string: "https://coverartarchive.org/release/\(releaseID)/front-500")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return url
            }
        } catch {}
        return nil
    }

    private func request(url: URL) async -> Data? {
        let elapsed = Date().timeIntervalSince(lastRequest)
        if elapsed < 1.1 {
            try? await Task.sleep(nanoseconds: UInt64((1.1 - elapsed) * 1_000_000_000))
        }
        lastRequest = Date()

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func encoded(_ query: String) -> String {
        query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    }
}
