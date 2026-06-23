import Foundation
import CryptoKit
import Combine

class LastFMService: ObservableObject {
    static let shared = LastFMService()
    private let apiKey = Secrets.lastFMApiKey
    private let sharedSecret = Secrets.lastFMSharedSecret
    
    @Published var sessionKey: String = UserDefaults.standard.string(forKey: "lastFMSessionKey") ?? ""
    @Published var username: String = UserDefaults.standard.string(forKey: "lastFMUsername") ?? ""
    @Published var isEnabled: Bool = UserDefaults.standard.object(forKey: "lastFMIsEnabled") as? Bool ?? true
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        $sessionKey
            .sink { UserDefaults.standard.set($0, forKey: "lastFMSessionKey") }
            .store(in: &cancellables)
            
        $username
            .sink { UserDefaults.standard.set($0, forKey: "lastFMUsername") }
            .store(in: &cancellables)
            
        $isEnabled
            .sink { UserDefaults.standard.set($0, forKey: "lastFMIsEnabled") }
            .store(in: &cancellables)
    }
    
    var isConnected: Bool {
        return !sessionKey.isEmpty
    }
    
    // MARK: - Utilities
    
    private func generateSignature(params: [String: String]) -> String {
        let sortedKeys = params.keys.sorted()
        var signatureString = ""
        for key in sortedKeys {
            signatureString += "\(key)\(params[key]!)"
        }
        signatureString += sharedSecret
        
        let digest = Insecure.MD5.hash(data: signatureString.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    private func makeRequest(method: String, params: [String: String], requiresSignature: Bool = true) async throws -> Data {
        var allParams = params
        allParams["api_key"] = apiKey
        allParams["method"] = method
        
        if requiresSignature {
            allParams["api_sig"] = generateSignature(params: allParams)
        }
        allParams["format"] = "json"
        
        let url = URL(string: "https://ws.audioscrobbler.com/2.0/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Last.fm recommends POST for scrobbling and now playing
        
        var components = URLComponents()
        components.queryItems = allParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.query?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
    
    // MARK: - Authentication
    
    func getToken() async throws -> String {
        let data = try await makeRequest(method: "auth.getToken", params: [:], requiresSignature: true)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let token = json["token"] as? String {
            return token
        }
        throw URLError(.cannotParseResponse)
    }
    
    func getSession(token: String) async throws {
        let data = try await makeRequest(method: "auth.getSession", params: ["token": token], requiresSignature: true)
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let session = json["session"] as? [String: Any],
           let key = session["key"] as? String,
           let name = session["name"] as? String {
            DispatchQueue.main.async {
                self.sessionKey = key
                self.username = name
            }
        } else {
            throw URLError(.cannotParseResponse)
        }
    }
    
    func disconnect() {
        self.sessionKey = ""
        self.username = ""
    }
    
    // MARK: - Scrobbling & Now Playing
    
    func updateNowPlaying(track: String, artist: String, album: String?, duration: Int) {
        guard isEnabled && isConnected else { return }
        guard !sharedSecret.isEmpty else { return } // Safe check
        
        var params: [String: String] = [
            "track": track,
            "artist": artist,
            "sk": sessionKey
        ]
        if let album = album {
            params["album"] = album
        }
        if duration > 0 {
            params["duration"] = "\(duration)"
        }
        
        Task {
            do {
                _ = try await makeRequest(method: "track.updateNowPlaying", params: params, requiresSignature: true)
                print("LastFM: Now playing updated (\(artist) - \(track))")
            } catch {
                print("LastFM: Error updating now playing: \(error)")
            }
        }
    }
    
    func scrobble(track: String, artist: String, album: String?, timestamp: Int) {
        guard isEnabled && isConnected else { return }
        guard !sharedSecret.isEmpty else { return } // Safe check
        
        var params: [String: String] = [
            "track": track,
            "artist": artist,
            "timestamp": "\(timestamp)",
            "sk": sessionKey
        ]
        if let album = album {
            params["album"] = album
        }
        
        Task {
            do {
                _ = try await makeRequest(method: "track.scrobble", params: params, requiresSignature: true)
                print("LastFM: Scrobble successful (\(artist) - \(track))")
            } catch {
                print("LastFM: Error scrobbling: \(error)")
            }
        }
    }

    // MARK: - Metadata (read-only; API key only)

    var hasMetadataAPI: Bool { !apiKey.isEmpty }

    func fetchAlbumInfo(artist: String, album: String) async -> (summary: String?, tags: [String]) {
        guard hasMetadataAPI else { return (nil, []) }
        do {
            let data = try await makeRequest(
                method: "album.getInfo",
                params: ["artist": artist, "album": album, "autocorrect": "1"],
                requiresSignature: false
            )
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let albumObj = json["album"] as? [String: Any] else { return (nil, []) }

            let summary = (albumObj["wiki"] as? [String: Any])?["summary"] as? String
            let tags = parseTags(from: albumObj["tags"])
            return (cleanWiki(summary), tags)
        } catch {
            return (nil, [])
        }
    }

    func fetchArtistInfo(name: String) async -> (summary: String?, tags: [String], similar: [String], imageURL: URL?) {
        guard hasMetadataAPI else { return (nil, [], [], nil) }
        do {
            let data = try await makeRequest(
                method: "artist.getInfo",
                params: ["artist": name, "autocorrect": "1"],
                requiresSignature: false
            )
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let artistObj = json["artist"] as? [String: Any] else { return (nil, [], [], nil) }

            let summary = (artistObj["bio"] as? [String: Any])?["summary"] as? String
            let tags = parseTags(from: artistObj["tags"])
            let similar = parseSimilar(from: artistObj["similar"])
            let imageURL = parseArtistImage(from: artistObj["image"])
            return (cleanWiki(summary), tags, similar, imageURL)
        } catch {
            return (nil, [], [], nil)
        }
    }

    func similarArtists(named name: String) async -> [String] {
        guard hasMetadataAPI else { return [] }
        return await fetchArtistInfo(name: name).similar
    }

    private func parseTags(from value: Any?) -> [String] {
        guard let tags = value as? [String: Any],
              let tagList = tags["tag"] as? [[String: Any]] else { return [] }
        return tagList.compactMap { $0["name"] as? String }.prefix(8).map { $0 }
    }

    private func parseSimilar(from value: Any?) -> [String] {
        guard let similar = value as? [String: Any],
              let artists = similar["artist"] as? [[String: Any]] else { return [] }
        return artists.compactMap { $0["name"] as? String }.prefix(8).map { $0 }
    }

    private func parseArtistImage(from value: Any?) -> URL? {
        guard let images = value as? [[String: Any]] else { return nil }
        let preferred = ["extralarge", "large", "medium"]
        for size in preferred {
            if let urlString = images.first(where: { ($0["size"] as? String) == size })?["#text"] as? String,
               let url = URL(string: urlString),
               !urlString.isEmpty,
               !Self.isPlaceholderImageURL(urlString) {
                return url
            }
        }
        return nil
    }

    /// Last.fm returns a generic star image when no artist photo exists.
    private static func isPlaceholderImageURL(_ urlString: String) -> Bool {
        urlString.contains("2a96cbd8-b460-951c-d455-ee949191d192")
            || urlString.contains("avatar70s")
    }

    private func cleanWiki(_ text: String?) -> String? {
        guard var text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        if let range = text.range(of: "<a href") {
            text = String(text[..<range.lowerBound])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
