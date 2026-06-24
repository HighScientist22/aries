//
//  AlbumMetadataEditorView.swift
//  Aries
//

import SwiftUI

struct AlbumMetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryStore

    let album: AlbumGroup

    @State private var metadata: AlbumEditableMetadata
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(album: AlbumGroup, library: LibraryStore) {
        self.album = album
        self.library = library
        _metadata = State(initialValue: AlbumEditableMetadata(from: album))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Album Metadata")
                        .font(.headline)
                    Text("\(album.tracks.count) tracks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                TextField("Artist", text: $metadata.artist)
                TextField("Album", text: $metadata.albumTitle)
                TextField("Genre", text: $metadata.genre)
                TextField("Year", text: $metadata.year)
            }
            .formStyle(.grouped)
            .padding()

            Text("Applies artist, album, genre, and year to every track on this album. Track titles are unchanged.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
        .frame(width: 440, height: 360)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await library.updateAlbumMetadata(album, metadata: metadata)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}
