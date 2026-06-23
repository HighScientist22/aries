//
//  HomeView.swift
//  Aries
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Home shell

struct HomeView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    @EnvironmentObject var navigation: AppNavigation

    @State private var selectedSection: HomeSection = .home
    @State private var activityTab: RecentActivityTab = .added
    @State private var detailAlbum: AlbumGroup?
    @State private var detailArtist: ArtistGroup?

    private var albums: [AlbumGroup] { library.albumGroups }
    private var artists: [ArtistGroup] { library.artistGroups }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 220)
                .background(.ultraThinMaterial.opacity(0.55))

            Divider().opacity(0.25)

            Group {
                if library.tracks.isEmpty {
                    emptyLibrary
                } else if let album = detailAlbum {
                    AlbumDetailView(
                        album: album,
                        engine: engine,
                        library: library,
                        onBack: { withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { detailAlbum = nil } }
                    )
                } else if let artist = detailArtist {
                    ArtistDetailView(
                        artist: artist,
                        albums: albumsForArtist(artist),
                        engine: engine,
                        library: library,
                        onBack: { withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { detailArtist = nil } },
                        onOpenAlbum: { openAlbum($0) }
                    )
                } else {
                    switch selectedSection {
                    case .home:
                        homeDashboard
                    case .albums:
                        sectionBrowser(title: "Albums", albums: albums, artists: [])
                    case .artists:
                        sectionBrowser(title: "Artists", albums: [], artists: artists)
                    case .tracks:
                        tracksBrowser
                    case .favorites:
                        favoritesBrowser
                    case .genres:
                        genresBrowser
                    case .years:
                        yearsBrowser
                    case .year(let year):
                        yearBrowser(year)
                    case .stats:
                        statsBrowser
                    case .genre(let name):
                        genreBrowser(name)
                    case .playlist(let id):
                        playlistBrowser(id)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            refreshHomeTheme()
        }
        .onChange(of: library.recentlyPlayedIDs) { _, _ in
            refreshHomeTheme()
        }
        .onChange(of: navigation.artistNameToOpen) { _, name in
            guard let name, !name.isEmpty,
                  let artist = libraryArtist(matching: name, from: library.tracks) else { return }
            openArtist(artist)
            navigation.artistNameToOpen = nil
        }
        .onChange(of: navigation.albumIDToOpen) { _, albumID in
            guard let albumID,
                  let album = albums.first(where: { $0.id == albumID }) else { return }
            openAlbum(album)
            navigation.albumIDToOpen = nil
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Aries")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

            sidebarGroup("Browse") {
                sidebarItem(.home, icon: "house.fill", label: "Home")
                sidebarAction(icon: "magnifyingglass", label: "Search") {
                    navigation.openLibrarySearch()
                }
                sidebarItem(.stats, icon: "chart.bar.fill", label: "Stats")
            }

            sidebarGroup("My Library") {
                sidebarItem(.albums, icon: "square.stack.fill", label: "Albums")
                sidebarItem(.artists, icon: "person.fill", label: "Artists")
                if !library.genreGroups.isEmpty {
                    sidebarItem(.genres, icon: "guitars.fill", label: "Genres")
                }
                if !library.yearGroups.isEmpty {
                    sidebarItem(.years, icon: "calendar", label: "Years")
                }
                sidebarItem(.tracks, icon: "music.note", label: "Tracks")
                sidebarItem(.favorites, icon: "heart.fill", label: "Favorites")
            }

            if !library.playlists.isEmpty {
                sidebarGroup("Playlists") {
                    ForEach(library.playlists) { playlist in
                        sidebarPlaylistItem(playlist)
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                newPlaylistMenu
                sidebarAction(icon: "plus", label: "Add Music", action: importToLibrary)
                sidebarAction(icon: "gearshape", label: "Settings") {
                    navigation.openSettings()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
    }

    private var newPlaylistMenu: some View {
        Menu {
            Button("New Playlist", action: createPlaylist)
            Menu("New Smart Playlist") {
                Button("Custom Rules…") {
                    navigation.openSmartPlaylistBuilder()
                }
                Divider()
                Button("Favorite Tracks") {
                    openSmartPlaylist(library.createSmartPlaylist(rule: .favorites))
                }
                Button("Recently Played") {
                    openSmartPlaylist(library.createSmartPlaylist(rule: .recentlyPlayed))
                }
                if !library.genreGroups.isEmpty {
                    Menu("By Genre") {
                        ForEach(library.genreGroups.prefix(24)) { genre in
                            Button(genre.name) {
                                openSmartPlaylist(library.createSmartPlaylist(rule: .genre(genre.name)))
                            }
                        }
                    }
                }
                let years = Array(Set(library.tracks.compactMap(\.year))).sorted(by: >).prefix(12)
                if !years.isEmpty {
                    Menu("By Year") {
                        ForEach(Array(years), id: \.self) { year in
                            Button(String(year)) {
                                openSmartPlaylist(library.createSmartPlaylist(rule: .year(year)))
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text("New Playlist")
                    .font(.subheadline)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func sidebarGroup(_ title: String, @ViewBuilder items: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
            items()
        }
        .padding(.bottom, 16)
    }

    private func sidebarPlaylistItem(_ playlist: SavedPlaylist) -> some View {
        let isSelected = selectedSection == .playlist(playlist.id)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                selectedSection = .playlist(playlist.id)
                detailAlbum = nil
                detailArtist = nil
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: playlist.isSmart ? "sparkles" : "music.note.list")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(playlist.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(isSelected ? theme.accent : .primary.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.accent.opacity(0.15))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .contextMenu {
            Button(role: .destructive) {
                library.deletePlaylist(playlist)
                if selectedSection == .playlist(playlist.id) {
                    selectedSection = .home
                }
            } label: {
                Label("Delete Playlist", systemImage: "trash")
            }
        }
    }

    private func sidebarItem(_ section: HomeSection, icon: String, label: String) -> some View {
        let isSelected = selectedSection == section
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                selectedSection = section
                detailAlbum = nil
                detailArtist = nil
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(label)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(isSelected ? theme.accent : .primary.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(theme.accent.opacity(0.15))
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private func sidebarAction(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(label)
                    .font(.subheadline)
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Home dashboard

    private var homeDashboard: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 32) {
                greetingHeader
                statsRow
                if !library.genreListeningStats.isEmpty {
                    GenreListeningChart(stats: library.genreListeningStats, accent: theme.accent, maxBars: 5)
                }
                recentActivityPanel
                albumRow("Albums", albums: Array(albums.prefix(12)))
                artistRow("Artists", artists: Array(artists.prefix(12)))
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 48)
        }
    }

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            Text(greetingText())
                .font(.system(size: 40, weight: .regular, design: .serif))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                navigation.openSettings(tab: .general, focusGreeting: true)
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Edit Greeting")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            HomeStatCard(icon: "person.fill", label: "Artists", value: artists.count, accent: theme.accent)
            HomeStatCard(icon: "square.stack.fill", label: "Albums", value: albums.count, accent: theme.accent)
            HomeStatCard(icon: "music.note", label: "Tracks", value: library.tracks.count, accent: theme.accent)
            HomeStatCard(
                icon: "clock.fill",
                label: "Hours",
                value: Int(library.tracks.reduce(0) { $0 + $1.duration } / 3600),
                accent: theme.accent
            )
        }
    }

    private var recentActivityPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent Activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.8)

                Spacer()

                HStack(spacing: 4) {
                    activityTabButton(.played, label: "Played")
                    activityTabButton(.added, label: "Added")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 24) {
                    switch activityTab {
                    case .played:
                        if library.recentlyPlayed.isEmpty {
                            activityPlaceholder("Nothing played yet")
                        } else {
                            ForEach(library.recentlyPlayed.prefix(15)) { track in
                                ActivityAlbumTile(
                                    title: track.album ?? track.title,
                                    subtitle: track.artist,
                                    badge: nil,
                                    artworkURL: library.artworkURL(for: track),
                                    accent: theme.accent,
                                    onOpen: { openTrackAlbum(track) },
                                    onPlay: { playTrackAlbum(track) }
                                )
                            }
                        }
                    case .added:
                        let recentAlbums = recentlyAddedAlbums()
                        if recentAlbums.isEmpty {
                            activityPlaceholder("No recent additions")
                        } else {
                            ForEach(recentAlbums.prefix(15)) { item in
                                ActivityAlbumTile(
                                    title: item.album.title,
                                    subtitle: item.album.artist,
                                    badge: relativeAdded(item.date),
                                    artworkURL: library.artworkURL(for: item.album.artworkFile),
                                    accent: theme.accent,
                                    onOpen: { openAlbum(item.album) },
                                    onPlay: { playAlbum(item.album) }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 228)
            .clipped()
        }
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.accent.opacity(0.55))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func activityTabButton(_ tab: RecentActivityTab, label: String) -> some View {
        let isActive = activityTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { activityTab = tab }
        } label: {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(isActive ? .white : .white.opacity(0.5))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    if isActive {
                        Rectangle()
                            .fill(.white)
                            .frame(height: 2)
                            .padding(.horizontal, 4)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func activityPlaceholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
            .frame(width: 240, height: 136, alignment: .center)
    }

    // MARK: - Section browsers

    private func sectionBrowser(title: String, albums: [AlbumGroup], artists: [ArtistGroup]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(title)
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                if !albums.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)], spacing: 24) {
                        ForEach(albums) { album in
                            LibraryMediaTile(
                                title: album.title,
                                subtitle: album.artist,
                                artworkURL: library.artworkURL(for: album.artworkFile),
                                style: .album,
                                accent: theme.accent,
                                onOpen: { openAlbum(album) },
                                onPlay: { playAlbum(album) }
                            )
                            .libraryPlaybackMenu(engine: engine, library: library, tracks: album.tracks, album: album)
                        }
                    }
                }

                if !artists.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)], spacing: 24) {
                        ForEach(artists) { artist in
                            LibraryMediaTile(
                                title: artist.name,
                                subtitle: "\(artist.tracks.count) tracks",
                                artworkURL: library.artworkURL(for: artist.artworkFile),
                                style: .artist,
                                accent: theme.accent,
                                onOpen: { openArtist(artist) },
                                onPlay: { playArtist(artist) }
                            )
                            .libraryPlaybackMenu(engine: engine, library: library, tracks: artist.tracks, artist: artist)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var tracksBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tracks")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                LazyVStack(spacing: 2) {
                    ForEach(library.tracks) { track in
                        LibraryTrackRow(
                            track: track,
                            artworkURL: library.artworkURL(for: track),
                            accent: theme.accent
                        ) { play(track) }
                        .libraryPlaybackMenu(engine: engine, library: library, tracks: [track])
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var genresBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Genres")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(library.genreGroups) { genre in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                selectedSection = .genre(genre.name)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(genre.name)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text("\(genre.tracks.count) tracks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func genreBrowser(_ name: String) -> some View {
        let genre = library.genreGroups.first { $0.name == name }
        let genreAlbums = genre.map { albumsForGenre($0, from: albums) } ?? []

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            selectedSection = .genres
                        }
                    } label: {
                        Label("Genres", systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)

                    Text(name)
                        .font(.system(size: 32, weight: .regular, design: .serif))
                }
                .padding(.top, 24)

                if let genre {
                    HStack(spacing: 12) {
                        Button {
                            engine.playFromLibrary(genre.tracks, startIndex: 0, store: library)
                        } label: {
                            Label("Play Genre", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            engine.playFromLibrary(genre.tracks, startIndex: 0, store: library, shuffleTracks: true)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .glassEffect(.regular, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if !genreAlbums.isEmpty {
                        albumRow("Albums", albums: genreAlbums)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tracks")
                            .font(.title3.weight(.semibold))
                        LazyVStack(spacing: 2) {
                            ForEach(genre.tracks) { track in
                                LibraryTrackRow(
                                    track: track,
                                    artworkURL: library.artworkURL(for: track),
                                    accent: theme.accent
                                ) { play(track) }
                                .libraryPlaybackMenu(engine: engine, library: library, tracks: [track])
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var statsBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Listening Stats")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                GenreListeningChart(stats: library.genreListeningStats, accent: theme.accent)

                HStack(alignment: .top, spacing: 20) {
                    TopListeningList(
                        title: "Top Artists",
                        stats: library.artistListeningStats,
                        accent: theme.accent
                    )
                    .frame(maxWidth: .infinity)

                    TopListeningList(
                        title: "Top Albums",
                        stats: library.albumListeningStats,
                        accent: theme.accent
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var yearsBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Years")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 16)],
                    spacing: 16
                ) {
                    ForEach(library.yearGroups) { yearGroup in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                selectedSection = .year(yearGroup.year)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(String(yearGroup.year))
                                    .font(.title2.weight(.semibold))
                                Text("\(yearGroup.tracks.count) tracks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func yearBrowser(_ year: Int) -> some View {
        let yearGroup = library.yearGroups.first { $0.year == year }
        let yearAlbums = yearGroup.map { group in
            albums.filter { album in
                album.tracks.contains { $0.year == year }
            }
        } ?? []

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            selectedSection = .years
                        }
                    } label: {
                        Label("Years", systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)

                    Text(String(year))
                        .font(.system(size: 32, weight: .regular, design: .serif))
                }
                .padding(.top, 24)

                if let yearGroup {
                    HStack(spacing: 12) {
                        Button {
                            engine.playFromLibrary(yearGroup.tracks, startIndex: 0, store: library)
                        } label: {
                            Label("Play \(year)", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    if !yearAlbums.isEmpty {
                        albumRow("Albums", albums: yearAlbums)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tracks")
                            .font(.title3.weight(.semibold))
                        LazyVStack(spacing: 2) {
                            ForEach(yearGroup.tracks) { track in
                                LibraryTrackRow(
                                    track: track,
                                    artworkURL: library.artworkURL(for: track),
                                    accent: theme.accent
                                ) { play(track) }
                                .libraryPlaybackMenu(engine: engine, library: library, tracks: [track])
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var favoritesBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Favorites")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                if library.favoriteAlbums.isEmpty && library.favoriteArtists.isEmpty && library.favoriteTracks.isEmpty {
                    Text("Heart albums, artists, and tracks to see them here.")
                        .foregroundStyle(.secondary)
                } else {
                    if !library.favoriteAlbums.isEmpty {
                        albumRow("Albums", albums: library.favoriteAlbums)
                    }
                    if !library.favoriteArtists.isEmpty {
                        artistRow("Artists", artists: library.favoriteArtists)
                    }
                    if !library.favoriteTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tracks")
                                .font(.title3.weight(.semibold))
                            LazyVStack(spacing: 2) {
                                ForEach(library.favoriteTracks) { track in
                                    LibraryTrackRow(
                                        track: track,
                                        artworkURL: library.artworkURL(for: track),
                                        accent: theme.accent,
                                        isFavorite: true,
                                        onFavorite: { library.toggleFavorite(track: track) }
                                    ) { play(track) }
                                    .libraryPlaybackMenu(engine: engine, library: library, tracks: [track])
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func playlistBrowser(_ playlistID: UUID) -> some View {
        let playlist = library.playlists.first { $0.id == playlistID }
        let playlistTracks = playlist.map { library.tracks(for: $0) } ?? []

        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(playlist?.name ?? "Playlist")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                if playlist?.isSmart == true {
                    Label("Smart playlist — updates automatically", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let rule = playlist?.smartRule {
                        Text(rule.summary)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if playlistTracks.isEmpty {
                    Text("This playlist is empty.")
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 12) {
                        Button("Play") {
                            engine.playFromLibrary(playlistTracks, startIndex: 0, store: library)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                    }

                    LazyVStack(spacing: 2) {
                        ForEach(Array(playlistTracks.enumerated()), id: \.element.id) { index, track in
                            LibraryTrackRow(
                                track: track,
                                artworkURL: library.artworkURL(for: track),
                                accent: theme.accent
                            ) {
                                engine.playFromLibrary(playlistTracks, startIndex: index, store: library)
                            }
                            .libraryPlaybackMenu(engine: engine, library: library, tracks: [track])
                            .contextMenu {
                                if playlist?.isSmart != true {
                                    Button(role: .destructive) {
                                        library.removeTrack(track.id, from: playlistID)
                                    } label: {
                                        Label("Remove from Playlist", systemImage: "minus.circle")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Rows

    private func albumRow(_ title: LocalizedStringKey, albums: [AlbumGroup]) -> some View {
        HomeSectionRow(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(albums) { album in
                        LibraryMediaTile(
                            title: album.title,
                            subtitle: album.artist,
                            artworkURL: library.artworkURL(for: album.artworkFile),
                            style: .album,
                            accent: theme.accent,
                            onOpen: { openAlbum(album) },
                            onPlay: { playAlbum(album) }
                        )
                        .libraryPlaybackMenu(engine: engine, library: library, tracks: album.tracks, album: album)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .frame(height: 218)
    }

    private func artistRow(_ title: LocalizedStringKey, artists: [ArtistGroup]) -> some View {
        HomeSectionRow(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(artists) { artist in
                        LibraryMediaTile(
                            title: artist.name,
                            subtitle: "\(artist.tracks.count) tracks",
                            artworkURL: library.artworkURL(for: artist.artworkFile),
                            style: .artist,
                            accent: theme.accent,
                            onOpen: { openArtist(artist) },
                            onPlay: { playArtist(artist) }
                        )
                        .libraryPlaybackMenu(engine: engine, library: library, tracks: artist.tracks, artist: artist)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .frame(height: 218)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 52))
                .foregroundStyle(theme.accent.opacity(0.7))
            Text("Your library is empty")
                .font(.title3.weight(.semibold))
            Text("Add a folder of music to build your library.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Music", action: importToLibrary)
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .disabled(library.isImporting)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func greetingText() -> String {
        if let custom = UserDefaults.standard.string(forKey: "customGreeting"),
           !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return custom
        }
        let first = NSFullUserName().split(separator: " ").first.map(String.init)
            ?? NSFullUserName()
        return "Hi, \(first)"
    }

    private func recentlyAddedAlbums() -> [RecentAlbumItem] {
        albums
            .compactMap { album -> RecentAlbumItem? in
                guard let newest = album.tracks.map(\.dateAdded).max() else { return nil }
                return RecentAlbumItem(album: album, date: newest)
            }
            .sorted { $0.date > $1.date }
    }

    private func relativeAdded(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Added today" }
        if cal.isDateInYesterday(date) { return "Added yesterday" }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 0
        if days < 30 { return "Added \(days) days ago" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "Added \(formatter.string(from: date))"
    }

    private func refreshHomeTheme() {
        let hero = library.recentlyPlayed.first ?? library.tracks.first
        guard let hero, let url = library.artworkURL(for: hero) else { return }
        let key = "home-\(hero.id.uuidString)"
        Task {
            guard let image = await ArtworkLoader.shared.image(at: url, maxPixelSize: 256) else { return }
            await MainActor.run {
                theme.update(from: image, key: key)
            }
        }
    }

    private func play(_ track: LibraryTrack) {
        guard let start = library.tracks.firstIndex(of: track) else { return }
        engine.playFromLibrary(library.tracks, startIndex: start, store: library)
    }

    private func playAlbum(_ album: AlbumGroup) {
        engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
    }

    private func playTrackAlbum(_ track: LibraryTrack) {
        if let album = library.albumGroup(for: track) {
            playAlbum(album)
        } else {
            play(track)
        }
    }

    private func playArtist(_ artist: ArtistGroup) {
        engine.playFromLibrary(artist.tracks, startIndex: 0, store: library)
    }

    private func openAlbum(_ album: AlbumGroup) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            detailAlbum = album
            detailArtist = nil
        }
    }

    private func openArtist(_ artist: ArtistGroup) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            detailArtist = artist
            detailAlbum = nil
        }
    }

    private func openTrackAlbum(_ track: LibraryTrack) {
        if let album = library.albumGroup(for: track) {
            openAlbum(album)
        }
    }

    private func albumsForArtist(_ artist: ArtistGroup) -> [AlbumGroup] {
        matchingAlbums(forArtist: artist, in: albums)
    }

    private func createPlaylist() {
        let playlist = library.createPlaylist(named: "Playlist \(library.playlists.count + 1)")
        openSmartPlaylist(playlist)
    }

    private func openSmartPlaylist(_ playlist: SavedPlaylist) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            selectedSection = .playlist(playlist.id)
            detailAlbum = nil
            detailArtist = nil
        }
    }

    private func importToLibrary() {
        let urls = MusicImportPanel.pickFiles(allowFolders: true)
        guard !urls.isEmpty else { return }
        library.importFiles(urls)
    }
}

// MARK: - Home-only types

private struct RecentAlbumItem: Identifiable {
    let album: AlbumGroup
    let date: Date
    var id: String { album.id }
}

private enum HomeSection: Hashable {
    case home, stats, albums, artists, genres, years, tracks, favorites
    case genre(String)
    case year(Int)
    case playlist(UUID)
}

private enum RecentActivityTab {
    case played, added
}
