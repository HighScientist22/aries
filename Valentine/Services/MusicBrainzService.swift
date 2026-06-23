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

            struct LabelInfo: Decodable {
                let label: Label?
                struct Label: Decodable { let name: String? }
            }
        }
        struct Artist: Decodable {
            let id: String
            let name: String?
        }
        let releases: [Release]?
        let artists: [Artist]?
    }

    func lookupRelease(artist: String, album: String) async -> (id: String, date: String?, label: String?, country: String?)? {
        let query = "release:\"\(escape(album))\" AND artist:\"\(escape(artist))\""
        guard let url = URL(string: "\(baseURL)/release?query=\(encoded(query))&fmt=json&limit=5") else { return nil }

        guard let data = await request(url: url) else { return nil }
        guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let release = response.releases?.first else { return nil }

        let label = release.labelInfo?.first?.label?.name
        return (release.id, release.date, label, release.country)
    }

    func lookupArtist(name: String) async -> String? {
        let query = "artist:\"\(escape(name))\""
        guard let url = URL(string: "\(baseURL)/artist?query=\(encoded(query))&fmt=json&limit=3") else { return nil }

        guard let data = await request(url: url) else { return nil }
        guard let response = try? JSONDecoder().decode(SearchResponse.self, from: data),
              let artist = response.artists?.first else { return nil }
        return artist.id
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
