//
//  IdentificationService.swift
//  Aries
//

import Foundation

actor IdentificationService {
    static let shared = IdentificationService()

    func identify(_ track: LibraryTrack) async -> TrackIdentification {
        let durationMs = Int((track.duration * 1000).rounded())
        if let match = await MusicBrainzService.shared.lookupRecording(
            artist: track.albumArtist,
            title: track.title,
            durationMs: durationMs
        ) {
            return TrackIdentification(
                musicBrainzRecordingID: match.recordingID,
                musicBrainzReleaseID: match.releaseID,
                musicBrainzReleaseGroupID: match.releaseGroupID,
                matchedTitle: match.title,
                confidence: match.confidence,
                identifiedAt: Date()
            )
        }

        if let release = await MusicBrainzService.shared.lookupReleaseMatch(
            artist: track.albumArtist,
            album: track.album ?? track.title
        ) {
            return TrackIdentification(
                musicBrainzReleaseID: release.id,
                musicBrainzReleaseGroupID: release.releaseGroupID,
                confidence: 0.35,
                identifiedAt: Date()
            )
        }

        return TrackIdentification(confidence: 0, identifiedAt: Date())
    }
}
