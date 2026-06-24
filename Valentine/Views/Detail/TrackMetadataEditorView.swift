//
//  TrackMetadataEditorView.swift
//  Aries
//

import SwiftUI

struct TrackMetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryStore

    let track: LibraryTrack

    @State private var metadata: EditableTrackMetadata
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(track: LibraryTrack, library: LibraryStore) {
        self.track = track
        self.library = library
        _metadata = State(initialValue: EditableTrackMetadata(from: track))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit Metadata")
                    .font(.headline)
                Spacer()
                Button(action: save) {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving)
                Button("Cancel") { dismiss() }
            }
            .padding()

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.red.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
            }

            Form {
                TextField("Title", text: $metadata.title)
                TextField("Artist", text: $metadata.artist)
                TextField("Album", text: $metadata.album)
                TextField("Genre", text: $metadata.genre)
                TextField("Year", text: $metadata.year)
                TextField("Track Number", text: $metadata.trackNumber)
                TextField("Disc Number", text: $metadata.discNumber)
                TextField("Composer", text: $metadata.composer)
            }
            .formStyle(.grouped)
            .padding()
        }
        .frame(width: 440, height: 420)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await library.updateTrackMetadata(track.id, metadata: metadata)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
