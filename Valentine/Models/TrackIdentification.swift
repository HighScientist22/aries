//
//  TrackIdentification.swift
//  Aries
//

import Foundation

nonisolated enum IdentificationSource: String, Codable, Sendable {
    case acoustID
    case musicBrainz
    case unknown
}

nonisolated struct TrackIdentification: Codable, Equatable, Sendable {
    var acoustID: String?
    var musicBrainzRecordingID: String?
    var musicBrainzReleaseID: String?
    var musicBrainzReleaseGroupID: String?
    var matchedTitle: String?
    var source: IdentificationSource
    var confidence: Double
    var identifiedAt: Date

    init(
        acoustID: String? = nil,
        musicBrainzRecordingID: String? = nil,
        musicBrainzReleaseID: String? = nil,
        musicBrainzReleaseGroupID: String? = nil,
        matchedTitle: String? = nil,
        source: IdentificationSource = .unknown,
        confidence: Double = 0,
        identifiedAt: Date = Date()
    ) {
        self.acoustID = acoustID
        self.musicBrainzRecordingID = musicBrainzRecordingID
        self.musicBrainzReleaseID = musicBrainzReleaseID
        self.musicBrainzReleaseGroupID = musicBrainzReleaseGroupID
        self.matchedTitle = matchedTitle
        self.source = source
        self.confidence = confidence
        self.identifiedAt = identifiedAt
    }
}

nonisolated struct IdentificationStore: Codable, Sendable {
    var tracks: [UUID: TrackIdentification] = [:]
    var preferredDuplicateTrackID: [String: UUID] = [:]
    var hiddenDuplicateTrackIDs: [UUID] = []

    var hiddenDuplicateTrackIDSet: Set<UUID> {
        get { Set(hiddenDuplicateTrackIDs) }
        set { hiddenDuplicateTrackIDs = Array(newValue) }
    }
}

nonisolated struct DuplicateTrackGroup: Identifiable, Hashable, Sendable {
    let id: String
    let trackIDs: [UUID]
    var preferredTrackID: UUID
    let reason: String
}

nonisolated func duplicateFingerprint(for track: LibraryTrack) -> String {
    let title = normalizeMetadataToken(track.title)
    let artist = normalizeMetadataToken(track.albumArtist)
    let duration = Int(track.duration.rounded())
    return "\(artist)|\(title)|\(duration)"
}

nonisolated func normalizeMetadataToken(_ value: String) -> String {
    value.lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}
