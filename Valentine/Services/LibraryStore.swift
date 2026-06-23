//
//  LibraryStore.swift
//  Aries
//

import Foundation
import AppKit
import Combine

@MainActor
class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [LibraryTrack] = []
    @Published private(set) var recentlyPlayedIDs: [UUID] = []
    @Published private(set) var isImporting = false

    private let supportedExtensions = Set(["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff", "alac"])
    private let recentlyPlayedLimit = 25

    private let baseURL: URL
    private let indexURL: URL
    private let recentURL: URL
    private let artworkDirURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = support.appendingPathComponent("Aries", isDirectory: true)
        indexURL = baseURL.appendingPathComponent("library.json")
        recentURL = baseURL.appendingPathComponent("recent.json")
        artworkDirURL = baseURL.appendingPathComponent("Artwork", isDirectory: true)

        try? FileManager.default.createDirectory(at: artworkDirURL, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Persistence

    private func load() {
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([LibraryTrack].self, from: data) {
            tracks = decoded.sorted { $0.dateAdded > $1.dateAdded }
        }
        if let data = try? Data(contentsOf: recentURL),
           let decoded = try? JSONDecoder().decode([UUID].self, from: data) {
            recentlyPlayedIDs = decoded
        }
    }

    func markPlayed(_ id: UUID) {
        recentlyPlayedIDs.removeAll { $0 == id }
        recentlyPlayedIDs.insert(id, at: 0)
        if recentlyPlayedIDs.count > recentlyPlayedLimit {
            recentlyPlayedIDs = Array(recentlyPlayedIDs.prefix(recentlyPlayedLimit))
        }
        if let data = try? JSONEncoder().encode(recentlyPlayedIDs) {
            try? data.write(to: recentURL, options: .atomic)
        }
    }

    var recentlyPlayed: [LibraryTrack] {
        recentlyPlayedIDs.compactMap { id in tracks.first { $0.id == id } }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Resolving files

    // Resolves a library track to a live URL. The app is not sandboxed, so a
    // plain bookmark is sufficient and no security-scoped access is required.
    func resolveURL(for track: LibraryTrack) -> URL? {
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: track.bookmark,
                                 options: [],
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale, let refreshed = try? url.bookmarkData() {
            updateBookmark(refreshed, for: track.id)
        }
        return url
    }

    func artworkURL(for track: LibraryTrack) -> URL? {
        artworkURL(forFilename: track.artworkFile)
    }

    func artworkURL(forFilename file: String?) -> URL? {
        guard let file else { return nil }
        return artworkDirURL.appendingPathComponent(file)
    }

    private func updateBookmark(_ data: Data, for id: UUID) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else { return }
        tracks[index].bookmark = data
        persist()
    }

    // MARK: - Import

    func importFiles(_ urls: [URL]) {
        Task { await importFilesAsync(urls) }
    }

    private func importFilesAsync(_ urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        let audioURLs = expand(urls)
        let existingPaths = Set(resolvedPaths())

        for url in audioURLs {
            if existingPaths.contains(url.standardizedFileURL.path) { continue }

            guard let bookmark = try? url.bookmarkData() else { continue }

            var track = Track(url: url)
            await track.loadMetadata()

            let artworkFile = saveArtwork(track.nsImage)

            let record = LibraryTrack(
                id: UUID(),
                bookmark: bookmark,
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                artworkFile: artworkFile,
                dateAdded: Date()
            )
            tracks.insert(record, at: 0)
        }

        persist()
    }

    func remove(_ track: LibraryTrack) {
        if let file = track.artworkFile {
            try? FileManager.default.removeItem(at: artworkDirURL.appendingPathComponent(file))
        }
        tracks.removeAll { $0.id == track.id }
        persist()
    }

    func clear() {
        try? FileManager.default.removeItem(at: artworkDirURL)
        try? FileManager.default.createDirectory(at: artworkDirURL, withIntermediateDirectories: true)
        tracks.removeAll()
        persist()
    }

    // MARK: - Helpers

    private func expand(_ urls: [URL]) -> [URL] {
        var result: [URL] = []
        let fileManager = FileManager.default
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    while let fileURL = enumerator.nextObject() as? URL {
                        if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                            result.append(fileURL)
                        }
                    }
                }
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                result.append(url)
            }
        }
        return result
    }

    private func resolvedPaths() -> [String] {
        tracks.compactMap { track in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: track.bookmark,
                                     options: [],
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &isStale) else { return nil }
            return url.standardizedFileURL.path
        }
    }

    private func saveArtwork(_ image: NSImage?) -> String? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        let destination = artworkDirURL.appendingPathComponent(name)
        do {
            try jpeg.write(to: destination)
            return name
        } catch {
            return nil
        }
    }
}
