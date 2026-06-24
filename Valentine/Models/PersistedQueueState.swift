//
//  PersistedQueueState.swift
//  Aries
//

import Foundation

struct PersistedQueueState: Codable {
    var libraryTrackIDs: [UUID]
    var podcastEpisodeIDs: [UUID]
    var currentIndex: Int?
    var currentTime: TimeInterval
    var wasPlaying: Bool
    var shuffleMode: Bool
    var repeatMode: Int

    init(
        libraryTrackIDs: [UUID] = [],
        podcastEpisodeIDs: [UUID] = [],
        currentIndex: Int? = nil,
        currentTime: TimeInterval = 0,
        wasPlaying: Bool = false,
        shuffleMode: Bool = false,
        repeatMode: Int = 0
    ) {
        self.libraryTrackIDs = libraryTrackIDs
        self.podcastEpisodeIDs = podcastEpisodeIDs
        self.currentIndex = currentIndex
        self.currentTime = currentTime
        self.wasPlaying = wasPlaying
        self.shuffleMode = shuffleMode
        self.repeatMode = repeatMode
    }

    var isPodcastQueue: Bool {
        !podcastEpisodeIDs.isEmpty && libraryTrackIDs.isEmpty
    }

    // Backward compatibility with queues saved before podcast support.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        libraryTrackIDs = try container.decode([UUID].self, forKey: .libraryTrackIDs)
        podcastEpisodeIDs = try container.decodeIfPresent([UUID].self, forKey: .podcastEpisodeIDs) ?? []
        currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex)
        currentTime = try container.decode(TimeInterval.self, forKey: .currentTime)
        wasPlaying = try container.decode(Bool.self, forKey: .wasPlaying)
        shuffleMode = try container.decode(Bool.self, forKey: .shuffleMode)
        repeatMode = try container.decode(Int.self, forKey: .repeatMode)
    }
}
