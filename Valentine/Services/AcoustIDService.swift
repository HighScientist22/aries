//
//  AcoustIDService.swift
//  Aries
//

import Foundation

actor AcoustIDService {
    static let shared = AcoustIDService()

    struct Match: Sendable {
        let acoustID: String
        let musicBrainzRecordingID: String?
        let musicBrainzReleaseID: String?
        let musicBrainzReleaseGroupID: String?
        let title: String?
        let score: Double
    }

    private struct LookupResponse: Decodable {
        struct Result: Decodable {
            let id: String?
            let score: Double?
            let recordings: [Recording]?

            struct Recording: Decodable {
                let id: String?
                let title: String?
                let releases: [Release]?

                struct Release: Decodable {
                    let id: String?
                    let releaseGroup: ReleaseGroup?

                    struct ReleaseGroup: Decodable {
                        let id: String?
                    }
                }
            }
        }

        let status: String?
        let results: [Result]?
    }

    var hasAPIKey: Bool {
        !Secrets.acoustIDApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func lookup(fingerprint: String, duration: Int) async -> Match? {
        let apiKey = Secrets.acoustIDApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return nil }

        var components = URLComponents(string: "https://api.acoustid.org/v2/lookup")!
        components.queryItems = [
            URLQueryItem(name: "client", value: apiKey),
            URLQueryItem(name: "duration", value: "\(duration)"),
            URLQueryItem(name: "fingerprint", value: fingerprint),
            URLQueryItem(name: "meta", value: "recordings+releases+releasegroups"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Aries/1.2 (https://github.com/HighScientist22/aries)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let payload = try? JSONDecoder().decode(LookupResponse.self, from: data),
                  payload.status == "ok",
                  let result = payload.results?.first,
                  let acoustID = result.id else { return nil }

            let recording = result.recordings?.first
            let release = recording?.releases?.first
            let score = min(max(result.score ?? 0, 0), 1)

            return Match(
                acoustID: acoustID,
                musicBrainzRecordingID: recording?.id,
                musicBrainzReleaseID: release?.id,
                musicBrainzReleaseGroupID: release?.releaseGroup?.id,
                title: recording?.title,
                score: score
            )
        } catch {
            return nil
        }
    }
}
