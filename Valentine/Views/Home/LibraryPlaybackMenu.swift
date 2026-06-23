//
//  LibraryPlaybackMenu.swift
//  Aries
//

import SwiftUI

struct LibraryPlaybackMenu: ViewModifier {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    let tracks: [LibraryTrack]
    let startIndex: Int
    var album: AlbumGroup? = nil
    var artist: ArtistGroup? = nil
    var shuffleTracks: Bool = false

    private var trackIDs: [UUID] {
        tracks.map(\.id)
    }

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                engine.playFromLibrary(tracks, startIndex: startIndex, store: library, shuffleTracks: shuffleTracks)
            } label: {
                Label("Play Now", systemImage: "play.fill")
            }

            Button {
                engine.queueFromLibrary(tracks, startIndex: startIndex, store: library, mode: .playNext, shuffleTracks: shuffleTracks)
            } label: {
                Label("Play Next", systemImage: "text.insert")
            }

            Button {
                engine.queueFromLibrary(tracks, startIndex: startIndex, store: library, mode: .addToQueue, shuffleTracks: shuffleTracks)
            } label: {
                Label("Add to Queue", systemImage: "text.append")
            }

            Divider()

            playlistMenu

            if let album {
                Divider()
                Button {
                    library.toggleFavorite(album: album)
                } label: {
                    Label(
                        library.isFavorite(album: album) ? "Unfavorite Album" : "Favorite Album",
                        systemImage: library.isFavorite(album: album) ? "heart.fill" : "heart"
                    )
                }
            }

            if let artist {
                Button {
                    library.toggleFavorite(artist: artist)
                } label: {
                    Label(
                        library.isFavorite(artist: artist) ? "Unfavorite Artist" : "Favorite Artist",
                        systemImage: library.isFavorite(artist: artist) ? "heart.fill" : "heart"
                    )
                }
            }

            if tracks.count == 1, let track = tracks.first {
                Divider()
                Button {
                    library.toggleFavorite(track: track)
                } label: {
                    Label(
                        library.isFavorite(track: track) ? "Unfavorite" : "Favorite",
                        systemImage: library.isFavorite(track: track) ? "heart.fill" : "heart"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var playlistMenu: some View {
        if library.playlists.isEmpty {
            Button {
                addToNewPlaylist()
            } label: {
                Label("Add to Playlist", systemImage: "text.badge.plus")
            }
        } else {
            Menu {
                ForEach(library.playlists) { playlist in
                    Button {
                        library.addTracks(trackIDs, to: playlist.id)
                    } label: {
                        Text(playlist.name)
                    }
                }
                Divider()
                Button {
                    addToNewPlaylist()
                } label: {
                    Label("New Playlist", systemImage: "plus")
                }
            } label: {
                Label("Add to Playlist", systemImage: "text.badge.plus")
            }
        }
    }

    private func addToNewPlaylist() {
        let playlist = library.createPlaylist(named: "Playlist \(library.playlists.count + 1)")
        library.addTracks(trackIDs, to: playlist.id)
    }
}

extension View {
    func libraryPlaybackMenu(
        engine: AudioEngine,
        library: LibraryStore,
        tracks: [LibraryTrack],
        startIndex: Int = 0,
        album: AlbumGroup? = nil,
        artist: ArtistGroup? = nil,
        shuffleTracks: Bool = false
    ) -> some View {
        modifier(LibraryPlaybackMenu(
            engine: engine,
            library: library,
            tracks: tracks,
            startIndex: startIndex,
            album: album,
            artist: artist,
            shuffleTracks: shuffleTracks
        ))
    }
}
