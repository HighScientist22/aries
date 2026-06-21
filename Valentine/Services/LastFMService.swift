import Foundation
import CryptoKit
import SwiftUI
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
        
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")!
        components.queryItems = allParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST" // Last.fm recommends POST for scrobbling and now playing
        
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
}
