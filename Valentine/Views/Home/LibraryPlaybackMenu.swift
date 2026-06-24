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

    private var resolvedAlbum: AlbumGroup? {
        if let album { return album }
        if tracks.count == 1, let track = tracks.first {
            return library.albumGroup(for: track)
        }
        if let first = tracks.first,
           let group = library.albumGroup(for: first),
           Set(group.tracks.map(\.id)) == Set(tracks.map(\.id)) {
            return group
        }
        return nil
    }

    func body(content: Content) -> some View {
        content.contextMenu {
            if let album = resolvedAlbum {
                Button {
                    engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
                } label: {
                    Label("Play Album", systemImage: "play.circle.fill")
                }

                Button {
                    engine.playFromLibrary(album.tracks, startIndex: 0, store: library, shuffleTracks: true)
                } label: {
                    Label("Shuffle Album", systemImage: "shuffle")
                }

                Divider()
            }

            Button {
                engine.playFromLibrary(tracks, startIndex: startIndex, store: library, shuffleTracks: shuffleTracks)
            } label: {
                Label(tracks.count == 1 ? "Play Now" : "Play", systemImage: "play.fill")
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

            similarMenu

            radioMenu

            Divider()

            playlistMenu

            if let album = resolvedAlbum {
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
                Menu("Rate Track") {
                    ForEach(1...5, id: \.self) { stars in
                        Button {
                            library.setRating(stars, for: track.id)
                        } label: {
                            HStack {
                                Text(String(repeating: "★", count: stars))
                                if library.rating(for: track.id) >= stars {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if library.rating(for: track.id) > 0 {
                        Button("Clear Rating") {
                            library.setRating(0, for: track.id)
                        }
                    }
                }
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
    private var similarMenu: some View {
        if tracks.count == 1, let track = tracks.first {
            Button {
                let similar = LibrarySimilar.tracks(for: track, in: library)
                guard !similar.isEmpty else { return }
                engine.playFromLibrary(similar, startIndex: 0, store: library)
            } label: {
                Label("Play Similar", systemImage: "wand.and.stars")
            }
        }
    }

    @ViewBuilder
    private var radioMenu: some View {
        if let album = resolvedAlbum {
            Button {
                engine.startRadio(seed: .album(album), store: library)
            } label: {
                Label("Start Album Radio", systemImage: "dot.radiowaves.left.and.right")
            }
        }

        if let artist {
            Button {
                engine.startRadio(seed: .artist(artist), store: library)
            } label: {
                Label("Start Artist Radio", systemImage: "dot.radiowaves.left.and.right")
            }
        } else if let track = tracks.first, tracks.count == 1 {
            Button {
                engine.startRadio(seed: .track(track), store: library)
            } label: {
                Label("Start Track Radio", systemImage: "dot.radiowaves.left.and.right")
            }
        } else if let album = resolvedAlbum,
                  let artistGroup = library.artistGroup(named: album.artist) {
            Button {
                engine.startRadio(seed: .artist(artistGroup), store: library)
            } label: {
                Label("Start Artist Radio", systemImage: "dot.radiowaves.left.and.right")
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
