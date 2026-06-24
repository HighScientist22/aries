//
//  PodcastModels.swift
//  Aries
//

import Foundation

struct PodcastFeed: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var feedURL: String
    var title: String
    var author: String?
    var feedDescription: String?
    var artworkURL: String?
    var artworkFile: String?
    var lastFetched: Date?
    var dateSubscribed: Date

    init(
        id: UUID = UUID(),
        feedURL: String,
        title: String,
        author: String? = nil,
        feedDescription: String? = nil,
        artworkURL: String? = nil,
        artworkFile: String? = nil,
        lastFetched: Date? = nil,
        dateSubscribed: Date = Date()
    ) {
        self.id = id
        self.feedURL = feedURL
        self.title = title
        self.author = author
        self.feedDescription = feedDescription
        self.artworkURL = artworkURL
        self.artworkFile = artworkFile
        self.lastFetched = lastFetched
        self.dateSubscribed = dateSubscribed
    }
}

struct PodcastEpisode: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var feedID: UUID
    var guid: String
    var title: String
    var episodeDescription: String?
    var publishDate: Date?
    var enclosureURL: String
    var duration: TimeInterval?
    var localFilename: String?
    var isPlayed: Bool
    var playbackPosition: TimeInterval

    init(
        id: UUID = UUID(),
        feedID: UUID,
        guid: String,
        title: String,
        episodeDescription: String? = nil,
        publishDate: Date? = nil,
        enclosureURL: String,
        duration: TimeInterval? = nil,
        localFilename: String? = nil,
        isPlayed: Bool = false,
        playbackPosition: TimeInterval = 0
    ) {
        self.id = id
        self.feedID = feedID
        self.guid = guid
        self.title = title
        self.episodeDescription = episodeDescription
        self.publishDate = publishDate
        self.enclosureURL = enclosureURL
        self.duration = duration
        self.localFilename = localFilename
        self.isPlayed = isPlayed
        self.playbackPosition = playbackPosition
    }
}

struct ParsedPodcastFeed {
    var title: String
    var author: String?
    var description: String?
    var artworkURL: String?
    var episodes: [ParsedPodcastEpisode]
}

struct ParsedPodcastEpisode {
    var guid: String
    var title: String
    var description: String?
    var publishDate: Date?
    var enclosureURL: String
    var duration: TimeInterval?
}
