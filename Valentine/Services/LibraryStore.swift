//
//  LibraryStore.swift
//  Aries
//

import Foundation
import AppKit
import Combine
import Darwin

@MainActor
class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [LibraryTrack] = []
    @Published private(set) var albumGroups: [AlbumGroup] = []
    @Published private(set) var artistGroups: [ArtistGroup] = []
    @Published private(set) var genreGroups: [GenreGroup] = []
    @Published private(set) var recentlyPlayedIDs: [UUID] = []
    @Published private(set) var favoriteTrackIDs: Set<UUID> = []
    @Published private(set) var favoriteAlbumIDs: Set<String> = []
    @Published private(set) var favoriteArtistIDs: Set<String> = []
    @Published private(set) var playlists: [SavedPlaylist] = []
    @Published private(set) var isImporting = false

    private let supportedExtensions = SupportedAudioFormats.extensions
    private let recentlyPlayedLimit = 25
    private var recentSaveTask: Task<Void, Never>?
    private var librarySaveTask: Task<Void, Never>?

    private let baseURL: URL
    private let indexURL: URL
    private let recentURL: URL
    private let favoritesURL: URL
    private let playlistsURL: URL
    private let artworkDirURL: URL

    // Directory watchers: a DispatchSource per watched directory and the
    // underlying file descriptor so we can cancel and close when needed.
    private var directoryWatchers: [URL: DispatchSourceFileSystemObject] = [:]
    private var watchedFileDescriptors: [URL: Int32] = [:]
    private var lastEventTimestamps: [URL: Date] = [:]
    @Published var watchedFolders: [URL] = []

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = support.appendingPathComponent("Aries", isDirectory: true)
        indexURL = baseURL.appendingPathComponent("library.json")
        recentURL = baseURL.appendingPathComponent("recent.json")
        favoritesURL = baseURL.appendingPathComponent("favorites.json")
        playlistsURL = baseURL.appendingPathComponent("playlists.json")
        artworkDirURL = baseURL.appendingPathComponent("Artwork", isDirectory: true)

        try? FileManager.default.createDirectory(at: artworkDirURL, withIntermediateDirectories: true)
        load()
        // Kick off a background scan on startup (non-blocking). Respects user
        // preference `scanOnLaunch` (defaults to true).
        Task { await scanLibraryOnLaunch() }
        loadWatchedFoldersFromDefaults()
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
        if let data = try? Data(contentsOf: favoritesURL),
           let decoded = try? JSONDecoder().decode(FavoritesPayload.self, from: data) {
            favoriteTrackIDs = Set(decoded.tracks)
            favoriteAlbumIDs = Set(decoded.albums)
            favoriteArtistIDs = Set(decoded.artists ?? [])
        }
        if let data = try? Data(contentsOf: playlistsURL),
           let decoded = try? JSONDecoder().decode([SavedPlaylist].self, from: data) {
            playlists = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        recomputeGroups()
    }

    private struct FavoritesPayload: Codable {
        var tracks: [UUID]
        var albums: [String]
        var artists: [String]?
    }

    private func recomputeGroups() {
        let snapshot = tracks
        Task.detached(priority: .utility) {
            let albums = groupAlbums(from: snapshot)
            let artists = groupArtists(from: snapshot)
            let genres = groupGenres(from: snapshot)
            await MainActor.run {
                self.albumGroups = albums
                self.artistGroups = artists
                self.genreGroups = genres
            }
        }
    }

    func markPlayed(_ id: UUID) {
        recentlyPlayedIDs.removeAll { $0 == id }
        recentlyPlayedIDs.insert(id, at: 0)
        if recentlyPlayedIDs.count > recentlyPlayedLimit {
            recentlyPlayedIDs = Array(recentlyPlayedIDs.prefix(recentlyPlayedLimit))
        }
        scheduleRecentSave()
    }

    var recentlyPlayed: [LibraryTrack] {
        recentlyPlayedIDs.compactMap { id in tracks.first { $0.id == id } }
    }

    var favoriteTracks: [LibraryTrack] {
        tracks.filter { favoriteTrackIDs.contains($0.id) }
    }

    var favoriteAlbums: [AlbumGroup] {
        albumGroups.filter { favoriteAlbumIDs.contains($0.id) }
    }

    var favoriteArtists: [ArtistGroup] {
        artistGroups.filter { favoriteArtistIDs.contains($0.id) }
    }

    func isFavorite(track: LibraryTrack) -> Bool {
        favoriteTrackIDs.contains(track.id)
    }

    func isFavorite(album: AlbumGroup) -> Bool {
        favoriteAlbumIDs.contains(album.id)
    }

    func isFavorite(artist: ArtistGroup) -> Bool {
        favoriteArtistIDs.contains(artist.id)
    }

    func toggleFavorite(track: LibraryTrack) {
        if favoriteTrackIDs.contains(track.id) {
            favoriteTrackIDs.remove(track.id)
        } else {
            favoriteTrackIDs.insert(track.id)
        }
        persistFavorites()
    }

    func toggleFavorite(album: AlbumGroup) {
        if favoriteAlbumIDs.contains(album.id) {
            favoriteAlbumIDs.remove(album.id)
        } else {
            favoriteAlbumIDs.insert(album.id)
        }
        persistFavorites()
    }

    func toggleFavorite(artist: ArtistGroup) {
        if favoriteArtistIDs.contains(artist.id) {
            favoriteArtistIDs.remove(artist.id)
        } else {
            favoriteArtistIDs.insert(artist.id)
        }
        persistFavorites()
    }

    func createPlaylist(named name: String) -> SavedPlaylist {
        let playlist = SavedPlaylist(name: name)
        playlists.append(playlist)
        playlists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistPlaylists()
        return playlist
    }

    func createSmartPlaylist(named name: String? = nil, rule: SmartPlaylistRule) -> SavedPlaylist {
        let playlist = SavedPlaylist(name: name ?? rule.defaultName, smartRule: rule)
        playlists.append(playlist)
        playlists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistPlaylists()
        return playlist
    }

    func deletePlaylist(_ playlist: SavedPlaylist) {
        playlists.removeAll { $0.id == playlist.id }
        persistPlaylists()
    }

    func renamePlaylist(_ playlist: SavedPlaylist, to name: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else { return }
        playlists[index].name = name
        playlists[index].dateModified = Date()
        playlists.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistPlaylists()
    }

    func tracks(for playlist: SavedPlaylist) -> [LibraryTrack] {
        if let rule = playlist.smartRule {
            return resolveSmartPlaylist(rule)
        }
        return playlist.trackIDs.compactMap { id in tracks.first { $0.id == id } }
    }

    func resolveSmartPlaylist(_ rule: SmartPlaylistRule) -> [LibraryTrack] {
        switch rule {
        case .favorites:
            return favoriteTracks
        case .recentlyPlayed:
            return recentlyPlayed
        case .genre(let name):
            if let group = genreGroups.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return group.tracks
            }
            return tracks.filter { track in
                guard let genre = track.genre else { return false }
                return genre.localizedCaseInsensitiveContains(name)
            }
        case .artist(let name):
            if let group = artistGroups.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                return group.tracks.sorted(by: sortTracksForAlbum)
            }
            return tracks.filter { $0.albumArtist == name || $0.artist == name }
                .sorted(by: sortTracksForAlbum)
        case .year(let year):
            return tracks.filter { $0.year == year }.sorted(by: sortTracksForAlbum)
        }
    }

    func addTracks(_ trackIDs: [UUID], to playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        guard playlists[index].smartRule == nil else { return }
        var seen = Set(playlists[index].trackIDs)
        for id in trackIDs where seen.insert(id).inserted {
            playlists[index].trackIDs.append(id)
        }
        playlists[index].dateModified = Date()
        persistPlaylists()
    }

    func removeTrack(_ trackID: UUID, from playlistID: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        guard playlists[index].smartRule == nil else { return }
        playlists[index].trackIDs.removeAll { $0 == trackID }
        playlists[index].dateModified = Date()
        persistPlaylists()
    }

    func search(query: String) -> LibrarySearchResults {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LibrarySearchResults(tracks: [], albums: [], artists: [])
        }

        let matchedTracks = tracks.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.artist.localizedCaseInsensitiveContains(trimmed)
                || ($0.album?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || ($0.genre?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }

        let matchedAlbums = albumGroups.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed)
                || $0.artist.localizedCaseInsensitiveContains(trimmed)
        }

        let matchedArtists = artistGroups.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        }

        return LibrarySearchResults(
            tracks: Array(matchedTracks.prefix(25)),
            albums: Array(matchedAlbums.prefix(15)),
            artists: Array(matchedArtists.prefix(15))
        )
    }

    private func scheduleRecentSave() {
        recentSaveTask?.cancel()
        recentSaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(recentlyPlayedIDs) {
                try? data.write(to: recentURL, options: .atomic)
            }
        }
    }

    private func persistFavorites() {
        let payload = FavoritesPayload(
            tracks: Array(favoriteTrackIDs),
            albums: Array(favoriteAlbumIDs),
            artists: Array(favoriteArtistIDs)
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: favoritesURL, options: .atomic)
    }

    private func persistPlaylists() {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        try? data.write(to: playlistsURL, options: .atomic)
    }

    private func persist() {
        librarySaveTask?.cancel()
        librarySaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard let data = try? JSONEncoder().encode(tracks) else { return }
            try? data.write(to: indexURL, options: .atomic)
        }
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

    func artworkURL(for file: String?) -> URL? {
        artworkURL(forFilename: file)
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

    /// Faster import routine used for scanning folders. Loads metadata in
    /// parallel with a concurrency limit so startup scanning completes faster
    /// than serial imports.
    private func importFilesFast(_ urls: [URL]) async {
        isImporting = true
        defer { isImporting = false }

        let audioURLs = expand(urls)
        let existing = Set(resolvedPaths())

        // Filter out already-known files early.
        let toImport = audioURLs.filter { !existing.contains($0.standardizedFileURL.path) }
        guard !toImport.isEmpty else { return }

        var newRecords: [LibraryTrack] = []
        let artworkDir = artworkDirURL
        let limit = min(8, max(4, ProcessInfo.processInfo.activeProcessorCount))

        await withTaskGroup(of: LibraryTrack?.self) { group in
            var iterator = toImport.makeIterator()

            func enqueueNext() {
                guard let url = iterator.next() else { return }
                group.addTask {
                    await Self.importTrack(from: url, artworkDir: artworkDir)
                }
            }

            for _ in 0..<min(limit, toImport.count) {
                enqueueNext()
            }

            for await maybeRecord in group {
                if let record = maybeRecord {
                    newRecords.append(record)
                }
                enqueueNext()
            }
        }

        // Insert new records on the main actor (this actor) and persist once.
        if !newRecords.isEmpty {
            // Keep newest first like importFilesAsync
            for r in newRecords.sorted(by: { $0.dateAdded > $1.dateAdded }) {
                tracks.insert(r, at: 0)
            }
            persist()
            recomputeGroups()
        }
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
                dateAdded: Date(),
                genre: track.genre,
                year: track.year,
                trackNumber: track.trackNumber,
                discNumber: track.discNumber
            )
            tracks.insert(record, at: 0)
        }

        persist()
        recomputeGroups()
    }

    /// Scans sensible default folders (and any user-configured folders) for
    /// audio files and imports any files not already present in the library.
    /// This runs on startup in the background and is intentionally non-blocking.
    func scanLibraryOnLaunch() async {
        // Allow users to disable scanning via UserDefaults (default: true)
        let shouldScan = UserDefaults.standard.object(forKey: "scanOnLaunch") as? Bool ?? true
        guard shouldScan else { return }

        var candidateURLs: [URL] = []

        // If the user has provided folders to scan, use them.
        if let folderStrings = UserDefaults.standard.array(forKey: "libraryFolders") as? [String] {
            for s in folderStrings {
                let u = URL(fileURLWithPath: s)
                candidateURLs.append(u)
            }
        }

        // Always include the user's Music directory as a sensible default.
        if let music = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first {
            candidateURLs.append(music)
        }

        // Also check Downloads as many users store downloads there.
        if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            candidateURLs.append(downloads)
        }

        // Deduplicate and ensure directories exist.
        candidateURLs = Array(Set(candidateURLs)).filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !candidateURLs.isEmpty else { return }

        // Use the faster parallel importer for startup scanning.
        await importFilesFast(candidateURLs)

        // Start watching these directories so future changes are picked up
        // automatically while the app is running.
        startWatchingDirectories(candidateURLs)
    }

    // MARK: - Directory watching

    /// Start watching the given directories for changes. When a change is
    /// detected, the directory will be scanned (using the fast importer).
    func startWatchingDirectories(_ urls: [URL]) {
        for url in urls {
            // Ensure it's a directory and isn't already watched
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }
            if directoryWatchers[url] != nil { continue }

            let fd = open(url.path, O_EVTONLY)
            if fd == -1 { continue }

            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: DispatchQueue.global(qos: .utility))

            source.setEventHandler { [weak self] in
                guard let self = self else { return }
                self.handleDirectoryChange(url: url)
            }

            source.setCancelHandler {
                close(fd)
            }

            source.resume()

            Task { @MainActor in
                self.directoryWatchers[url] = source
                self.watchedFileDescriptors[url] = fd
            }
        }
    }

    /// Stop watching all directories and release resources.
    func stopWatchingAllDirectories() {
        for (_, src) in directoryWatchers {
            src.cancel()
        }
        Task { @MainActor in
            directoryWatchers.removeAll()
            for (_, fd) in watchedFileDescriptors {
                // If any remain open, ensure closed.
                if fd != -1 { close(fd) }
            }
            watchedFileDescriptors.removeAll()
            lastEventTimestamps.removeAll()
        }
    }

    private func handleDirectoryChange(url: URL) {
        // Debounce rapid events per-directory (5s to reduce aggressive rescans).
        let now = Date()
        if let last = lastEventTimestamps[url], now.timeIntervalSince(last) < 5.0 {
            return
        }
        lastEventTimestamps[url] = now

        // Scan the changed directory in background but run importer on the
        // main actor to safely update published state.
        Task { @MainActor in
            await self.importFilesFast([url])
        }
    }

    /// Add a folder to the persisted list of library folders and begin
    /// watching it immediately.
    func addWatchedFolder(_ url: URL) {
        var folders = UserDefaults.standard.array(forKey: "libraryFolders") as? [String] ?? []
        let path = url.path
        if !folders.contains(path) {
            folders.append(path)
            UserDefaults.standard.set(folders, forKey: "libraryFolders")
        }
        startWatchingDirectories([url])
        Task { @MainActor in
            if !watchedFolders.contains(url) { watchedFolders.append(url) }
        }
    }

    func removeWatchedFolder(_ url: URL) {
        // Cancel watcher if present
        if let src = directoryWatchers[url] {
            src.cancel()
            directoryWatchers.removeValue(forKey: url)
        }
        if let fd = watchedFileDescriptors[url] {
            if fd != -1 { close(fd) }
            watchedFileDescriptors.removeValue(forKey: url)
        }
        // Update persisted list
        var folders = UserDefaults.standard.array(forKey: "libraryFolders") as? [String] ?? []
        folders.removeAll { $0 == url.path }
        UserDefaults.standard.set(folders, forKey: "libraryFolders")
        Task { @MainActor in
            watchedFolders.removeAll { $0 == url }
        }
    }

    private func loadWatchedFoldersFromDefaults() {
        let folderStrings = UserDefaults.standard.array(forKey: "libraryFolders") as? [String] ?? []
        let urls = folderStrings.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
        watchedFolders = urls
        // Start watching any persisted folders
        startWatchingDirectories(urls)
    }

    func remove(_ track: LibraryTrack) {
        if let file = track.artworkFile {
            try? FileManager.default.removeItem(at: artworkDirURL.appendingPathComponent(file))
        }
        tracks.removeAll { $0.id == track.id }
        persist()
        recomputeGroups()
    }

    func clear() {
        try? FileManager.default.removeItem(at: artworkDirURL)
        try? FileManager.default.createDirectory(at: artworkDirURL, withIntermediateDirectories: true)
        tracks.removeAll()
        persist()
        recomputeGroups()
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
        Self.saveArtworkJPEG(image, to: artworkDirURL)
    }

    private static func importTrack(from url: URL, artworkDir: URL) async -> LibraryTrack? {
        guard let bookmark = try? url.bookmarkData() else { return nil }
        var track = Track(url: url)
        await track.loadMetadata()
        let artworkFile = saveArtworkJPEG(track.nsImage, to: artworkDir)
        return LibraryTrack(
            id: UUID(),
            bookmark: bookmark,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            artworkFile: artworkFile,
            dateAdded: Date(),
            genre: track.genre,
            year: track.year,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber
        )
    }

    private static func saveArtworkJPEG(_ image: NSImage?, to dir: URL) -> String? {
        guard let image,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else { return nil }
        let name = "\(UUID().uuidString).jpg"
        let destination = dir.appendingPathComponent(name)
        do {
            try jpeg.write(to: destination)
            return name
        } catch {
            return nil
        }
    }
}
