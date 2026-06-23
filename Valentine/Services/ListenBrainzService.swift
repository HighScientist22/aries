//
//  ListenBrainzService.swift
//  Aries
//

import Foundation
import SwiftUI
import Combine

// Scrobbles to ListenBrainz via its submit-listens API. Unlike Last.fm this
// uses a single user token (Bearer auth) and a JSON body, so there is no
// signing step. Mirrors LastFMService's now-playing / scrobble surface.
class ListenBrainzService: ObservableObject {
    static let shared = ListenBrainzService()

    @Published var userToken: String = UserDefaults.standard.string(forKey: "listenBrainzToken") ?? ""
    @Published var isEnabled: Bool = UserDefaults.standard.bool(forKey: "listenBrainzEnabled")

    private let endpoint = URL(string: "https://api.listenbrainz.org/1/submit-listens")!
    private var cancellables = Set<AnyCancellable>()

    private init() {
        $userToken
            .sink { UserDefaults.standard.set($0, forKey: "listenBrainzToken") }
            .store(in: &cancellables)
        $isEnabled
            .sink { UserDefaults.standard.set($0, forKey: "listenBrainzEnabled") }
            .store(in: &cancellables)
    }

    var isConnected: Bool {
        !userToken.isEmpty
    }

    func updateNowPlaying(track: String, artist: String, album: String?) {
        submit(listenType: "playing_now", track: track, artist: artist, album: album, timestamp: nil)
    }

    func scrobble(track: String, artist: String, album: String?, timestamp: Int) {
        submit(listenType: "single", track: track, artist: artist, album: album, timestamp: timestamp)
    }

    private func submit(listenType: String, track: String, artist: String, album: String?, timestamp: Int?) {
        guard isEnabled, isConnected else { return }

        var trackMetadata: [String: Any] = [
            "track_name": track,
            "artist_name": artist
        ]
        if let album { trackMetadata["release_name"] = album }

        var listen: [String: Any] = ["track_metadata": trackMetadata]
        if let timestamp { listen["listened_at"] = timestamp }

        let payload: [String: Any] = [
            "listen_type": listenType,
            "payload": [listen]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Token \(userToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    print("ListenBrainz: submit failed (\(listenType))")
                    return
                }
                print("ListenBrainz: \(listenType) submitted (\(artist) - \(track))")
            } catch {
                print("ListenBrainz: error submitting \(listenType): \(error)")
            }
        }
    }
}
