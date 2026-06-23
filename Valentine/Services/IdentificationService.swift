//
//  IdentificationService.swift
//  Aries
//

import Foundation

actor IdentificationService {
    static let shared = IdentificationService()

    func identify(_ track: LibraryTrack, fileURL: URL?) async -> TrackIdentification {
        if let fileURL,
           !Secrets.acoustIDApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           ChromaprintService.isAvailable,
           let chromaprint = await ChromaprintService.fingerprint(for: fileURL),
           let match = await AcoustIDService.shared.lookup(
            fingerprint: chromaprint.fingerprint,
            duration: chromaprint.duration
           ),
           match.score >= 0.5 {
            return TrackIdentification(
                acoustID: match.acoustID,
                musicBrainzRecordingID: match.musicBrainzRecordingID,
                musicBrainzReleaseID: match.musicBrainzReleaseID,
                musicBrainzReleaseGroupID: match.musicBrainzReleaseGroupID,
                matchedTitle: match.title,
                source: .acoustID,
                confidence: match.score,
                identifiedAt: Date()
            )
        }

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
                source: .musicBrainz,
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
                source: .musicBrainz,
                confidence: 0.35,
                identifiedAt: Date()
            )
        }

        return TrackIdentification(source: .unknown, confidence: 0, identifiedAt: Date())
    }
}
