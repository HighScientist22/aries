//
//  PersistedQueueState.swift
//  Aries
//

import Foundation

struct PersistedQueueState: Codable {
    var libraryTrackIDs: [UUID]
    var currentIndex: Int?
    var currentTime: TimeInterval
    var wasPlaying: Bool
    var shuffleMode: Bool
    var repeatMode: Int
}
