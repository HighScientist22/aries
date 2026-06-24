//
//  PodcastStore.swift
//  Aries
//

import Foundation
import AppKit
import Combine

@MainActor
final class PodcastStore: ObservableObject {
    @Published private(set) var feeds: [PodcastFeed] = []
    @Published private(set) var episodes: [PodcastEpisode] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isDownloadingEpisode: UUID?

    private let baseURL: URL
    private let feedsURL: URL
    private let episodesURL: URL
    private let artworkDirURL: URL
    private let episodesDirURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseURL = support.appendingPathComponent("Aries/Podcasts", isDirectory: true)
        feedsURL = baseURL.appendingPathComponent("feeds.json")
        episodesURL = baseURL.appendingPathComponent("episodes.json")
        artworkDirURL = baseURL.appendingPathComponent("Artwork", isDirectory: true)
        episodesDirURL = baseURL.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: artworkDirURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: episodesDirURL, withIntermediateDirectories: true)
        load()
    }

    var newEpisodes: [PodcastEpisode] {
        episodes
            .filter { !$0.isPlayed }
            .sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
    }

    func episodes(for feed: PodcastFeed) -> [PodcastEpisode] {
        episodes
            .filter { $0.feedID == feed.id }
            .sorted { ($0.publishDate ?? .distantPast) > ($1.publishDate ?? .distantPast) }
    }

    func feed(for id: UUID) -> PodcastFeed? {
        feeds.first { $0.id == id }
    }

    func artworkURL(for feed: PodcastFeed) -> URL? {
        guard let file = feed.artworkFile else { return nil }
        return artworkDirURL.appendingPathComponent(file)
    }

    func subscribe(feedURLString: String) async throws {
        let trimmed = feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            throw PodcastError.invalidURL
        }
        if feeds.contains(where: { $0.feedURL == trimmed }) {
            throw PodcastError.alreadySubscribed
        }

        let parsed = try await RSSFeedParser.fetchAndParse(url: url)
        var feed = PodcastFeed(
            feedURL: trimmed,
            title: parsed.title,
            author: parsed.author,
            feedDescription: parsed.description,
            artworkURL: parsed.artworkURL,
            lastFetched: Date()
        )
        feed.artworkFile = await downloadArtwork(from: parsed.artworkURL, feedID: feed.id)
        feeds.append(feed)
        mergeEpisodes(parsed.episodes, feedID: feed.id)
        persistNow()
    }

    func subscribeOPML(at url: URL) async throws -> Int {
        let urls = try OPMLParser.parseFile(at: url)
        guard !urls.isEmpty else { throw PodcastError.emptyOPML }
        var added = 0
        for feedURL in urls {
            do {
                try await subscribe(feedURLString: feedURL)
                added += 1
            } catch PodcastError.alreadySubscribed {
                continue
            }
        }
        return added
    }

    func unsubscribe(_ feed: PodcastFeed) {
        episodes.removeAll { $0.feedID == feed.id }
        feeds.removeAll { $0.id == feed.id }
        if let file = feed.artworkFile {
            try? FileManager.default.removeItem(at: artworkDirURL.appendingPathComponent(file))
        }
        try? FileManager.default.removeItem(at: episodesDirURL.appendingPathComponent(feed.id.uuidString, isDirectory: true))
        persistNow()
    }

    func refreshAllFeeds() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let snapshot = feeds
        let limit = ImportConcurrency.networkLimit
        await withTaskGroup(of: Void.self) { group in
            var iterator = snapshot.makeIterator()
            for _ in 0..<min(limit, snapshot.count) {
                guard let feed = iterator.next() else { break }
                group.addTask { await self.refreshFeed(feed) }
            }
            for await _ in group {
                if let feed = iterator.next() {
                    group.addTask { await self.refreshFeed(feed) }
                }
            }
        }
    }

    func refreshFeed(_ feed: PodcastFeed) async {
        guard let url = URL(string: feed.feedURL) else { return }
        do {
            let parsed = try await RSSFeedParser.fetchAndParse(url: url)
            guard let index = feeds.firstIndex(where: { $0.id == feed.id }) else { return }
            feeds[index].title = parsed.title
            feeds[index].author = parsed.author
            feeds[index].feedDescription = parsed.description
            if feeds[index].artworkFile == nil, let art = parsed.artworkURL {
                feeds[index].artworkFile = await downloadArtwork(from: art, feedID: feed.id)
                feeds[index].artworkURL = art
            }
            feeds[index].lastFetched = Date()
            mergeEpisodes(parsed.episodes, feedID: feed.id)
            persistSoon()
        } catch {
            print("Podcast refresh failed for \(feed.title): \(error)")
        }
    }

    func localURL(for episode: PodcastEpisode) async -> URL? {
        if let existing = cachedURL(for: episode) { return existing }
        return await downloadEpisode(episode)
    }

    func cachedURL(for episode: PodcastEpisode) -> URL? {
        guard let filename = episode.localFilename else { return nil }
        let url = episodesDirURL
            .appendingPathComponent(episode.feedID.uuidString, isDirectory: true)
            .appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func downloadEpisode(_ episode: PodcastEpisode) async -> URL? {
        guard let remoteURL = URL(string: episode.enclosureURL) else { return nil }
        isDownloadingEpisode = episode.id
        defer { isDownloadingEpisode = nil }

        let feedDir = episodesDirURL.appendingPathComponent(episode.feedID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: feedDir, withIntermediateDirectories: true)
        let ext = remoteURL.pathExtension.isEmpty ? "mp3" : remoteURL.pathExtension
        let filename = "\(episode.id.uuidString).\(ext)"
        let localURL = feedDir.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: localURL.path) {
            updateEpisodeLocalPath(episode.id, filename: filename, persist: true)
            return localURL
        }

        do {
            var request = URLRequest(url: remoteURL)
            request.setValue("Aries/1.2", forHTTPHeaderField: "User-Agent")
            let (tempURL, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            if FileManager.default.fileExists(atPath: localURL.path) {
                try? FileManager.default.removeItem(at: localURL)
            }
            try FileManager.default.moveItem(at: tempURL, to: localURL)
            updateEpisodeLocalPath(episode.id, filename: filename, persist: true)
            return localURL
        } catch {
            print("Episode download failed: \(error)")
            return nil
        }
    }

    func markEpisodePlayed(_ episodeID: UUID) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else { return }
        episodes[index].isPlayed = true
        episodes[index].playbackPosition = 0
        persistSoon()
    }

    func setPlaybackPosition(_ position: TimeInterval, for episodeID: UUID) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else { return }
        episodes[index].playbackPosition = position
        persistSoon()
    }

    func resumePosition(for episodeID: UUID) -> TimeInterval? {
        guard let episode = episodes.first(where: { $0.id == episodeID }),
              episode.playbackPosition > 10 else { return nil }
        return episode.playbackPosition
    }

    func clearResumePosition(for episodeID: UUID) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else { return }
        episodes[index].playbackPosition = 0
        persistSoon()
    }

    private func load() {
        if let data = try? Data(contentsOf: feedsURL),
           let decoded = try? JSONDecoder().decode([PodcastFeed].self, from: data) {
            feeds = decoded.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        if let data = try? Data(contentsOf: episodesURL),
           let decoded = try? JSONDecoder().decode([PodcastEpisode].self, from: data) {
            episodes = decoded
        }
    }

    private func persistSoon() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            persistNow()
        }
    }

    private func persistNow() {
        if let data = try? JSONEncoder().encode(feeds) {
            try? data.write(to: feedsURL, options: .atomic)
        }
        if let data = try? JSONEncoder().encode(episodes) {
            try? data.write(to: episodesURL, options: .atomic)
        }
    }

    private func mergeEpisodes(_ parsed: [ParsedPodcastEpisode], feedID: UUID) {
        let existingGuids = Set(episodes.filter { $0.feedID == feedID }.map(\.guid))
        for item in parsed where !existingGuids.contains(item.guid) {
            episodes.append(PodcastEpisode(
                feedID: feedID,
                guid: item.guid,
                title: item.title,
                episodeDescription: item.description,
                publishDate: item.publishDate,
                enclosureURL: item.enclosureURL,
                duration: item.duration
            ))
        }
    }

    private func updateEpisodeLocalPath(_ episodeID: UUID, filename: String, persist: Bool) {
        guard let index = episodes.firstIndex(where: { $0.id == episodeID }) else { return }
        episodes[index].localFilename = filename
        if persist { persistSoon() }
    }

    private func downloadArtwork(from urlString: String?, feedID: UUID) async -> String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = NSImage(data: data),
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else { return nil }
            let filename = "\(feedID.uuidString).jpg"
            try jpeg.write(to: artworkDirURL.appendingPathComponent(filename))
            return filename
        } catch {
            return nil
        }
    }
}

enum PodcastError: LocalizedError {
    case invalidURL
    case alreadySubscribed
    case emptyOPML

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid feed URL"
        case .alreadySubscribed: return "Already subscribed to this feed"
        case .emptyOPML: return "No podcast feeds found in OPML file"
        }
    }
}
