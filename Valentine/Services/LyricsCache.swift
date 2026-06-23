//
//  LyricsCache.swift
//  Aries
//

import Foundation

/// Persists LRCLib results so tracks aren't re-fetched across sessions.
@MainActor
final class LyricsCache {
    static let shared = LyricsCache()

    private var entries: [String: String] = [:]
    private let cacheURL: URL
    private var saveTask: Task<Void, Never>?

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let base = support.appendingPathComponent("Aries", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        cacheURL = base.appendingPathComponent("lyrics-cache.json")
        load()
    }

    func key(artist: String, title: String) -> String {
        let a = artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(a)|\(t)"
    }

    func lyrics(artist: String, title: String) -> String? {
        entries[key(artist: artist, title: title)]
    }

    func store(artist: String, title: String, lyrics: String) {
        let k = key(artist: artist, title: title)
        guard entries[k] != lyrics else { return }
        entries[k] = lyrics
        scheduleSave()
    }

    private func load() {
        guard let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        entries = decoded
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
