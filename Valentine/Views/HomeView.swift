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
    @EnvironmentObject var podcastStore: PodcastStore
    @EnvironmentObject var theme: AlbumTheme
    @EnvironmentObject var navigation: AppNavigation

    @State private var selectedSection: HomeSection = .home
    @State private var activityTab: RecentActivityTab = .added
    @State private var detailAlbum: AlbumGroup?
    @State private var detailArtist: ArtistGroup?
    @State private var detailPodcastFeed: PodcastFeed?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @AppStorage("albumGridDensity") private var albumGridDensity = AlbumGridDensity.comfortable.rawValue
    @AppStorage(LiquidGlassSettings.enabledKey) private var liquidGlassEnabled = true

    private var albums: [AlbumGroup] { library.albumGroups }
    private var artists: [ArtistGroup] { library.artistGroups }
    private var gridDensity: AlbumGridDensity {
        AlbumGridDensity(rawValue: albumGridDensity) ?? .comfortable
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            Group {
                if !navigation.librarySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    LibraryInlineSearchResults(
                        engine: engine,
                        library: library,
                        query: navigation.librarySearchQuery
                    )
                } else if library.tracks.isEmpty && podcastStore.feeds.isEmpty {
                    emptyLibrary
                } else if let feed = detailPodcastFeed {
                    PodcastFeedDetailView(
                        feed: feed,
                        podcastStore: podcastStore,
                        engine: engine,
                        accent: theme.accent,
                        onBack: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                                detailPodcastFeed = nil
                            }
                        }
                    )
                } else if let album = detailAlbum {
                    AlbumDetailView(
                        album: album,
                        engine: engine,
                        library: library,
                        onBack: { withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { detailAlbum = nil } },
                        onOpenAlbum: { openAlbum($0) }
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
                    case .listenLater:
                        listenLaterBrowser
                    case .podcasts:
                        PodcastBrowserView(
                            podcastStore: podcastStore,
                            engine: engine,
                            accent: theme.accent,
                            onOpenFeed: { feed in
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
                                    detailPodcastFeed = feed
                                }
                            }
                        )
                    case .genres:
                        genresBrowser
                    case .composers:
                        composersBrowser
                    case .folders:
                        foldersBrowser
                    case .years:
                        yearsBrowser
                    case .year(let year):
                        yearBrowser(year)
                    case .stats:
                        statsBrowser
                    case .duplicates:
                        DuplicatesView(
                            library: library,
                            accent: theme.accent,
                            onOpenAlbum: { openTrackAlbum($0) }
                        )
                    case .genre(let name):
                        genreBrowser(name)
                    case .composer(let name):
                        composerBrowser(name)
                    case .folder(let path):
                        folderBrowser(path)
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
        .onReceive(NotificationCenter.default.publisher(for: .openAlbumFromSearch)) { notification in
            guard let albumID = notification.object as? String,
                  let album = albums.first(where: { $0.id == albumID }) else { return }
            openAlbum(album)
            navigation.librarySearchQuery = ""
        }
        .onReceive(NotificationCenter.default.publisher(for: .openArtistFromSearch)) { notification in
            guard let name = notification.object as? String,
                  let artist = libraryArtist(matching: name, from: library.tracks) else { return }
            openArtist(artist)
            navigation.librarySearchQuery = ""
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
                sidebarItem(.listenLater, icon: "clock.badge.checkmark", label: "Listen Later")
                sidebarItem(.podcasts, icon: "mic.fill", label: "Podcasts")
                sidebarItem(.stats, icon: "chart.bar.fill", label: "Stats")
                if !library.duplicateGroups.isEmpty {
                    sidebarItem(.duplicates, icon: "doc.on.doc", label: "Duplicates")
                }
            }

            sidebarGroup("My Library") {
                sidebarItem(.albums, icon: "square.stack.fill", label: "Albums")
                sidebarItem(.artists, icon: "person.fill", label: "Artists")
                if !library.genreGroups.isEmpty {
                    sidebarItem(.genres, icon: "guitars.fill", label: "Genres")
                }
                if !library.composerGroups.isEmpty {
                    sidebarItem(.composers, icon: "person.text.rectangle", label: "Composers")
                }
                if !library.folderGroups.isEmpty {
                    sidebarItem(.folders, icon: "folder.fill", label: "Folders")
                }
                if !library.yearGroups.isEmpty {
                    sidebarItem(.years, icon: "calendar", label: "Years")
                }
                sidebarItem(.tracks, icon: "music.note", label: "Tracks")
                sidebarItem(.favorites, icon: "heart.fill", label: "Favorites")
            }

            if !library.playlistFolders.isEmpty || !library.playlists.isEmpty {
                sidebarGroup("Playlists") {
                    ForEach(library.playlistFolders) { folder in
                        sidebarPlaylistFolderHeader(folder)
                        ForEach(library.playlists(in: folder.id)) { playlist in
                            sidebarPlaylistItem(playlist, indented: true)
                        }
                    }
                    ForEach(library.playlists(in: nil)) { playlist in
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
        .background(.ultraThinMaterial.opacity(liquidGlassEnabled ? 0.55 : 0.9))
    }

    private var newPlaylistMenu: some View {
        Menu {
            Button("New Playlist", action: createPlaylist)
            Button("New Playlist Folder", action: createPlaylistFolder)
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

    private func sidebarPlaylistFolderHeader(_ folder: PlaylistFolder) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(folder.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .contextMenu {
            Button(role: .destructive) {
                library.deletePlaylistFolder(folder)
            } label: {
                Label("Delete Folder", systemImage: "trash")
            }
        }
    }

    private func sidebarPlaylistItem(_ playlist: SavedPlaylist, indented: Bool = false) -> some View {
        let isSelected = selectedSection == .playlist(playlist.id)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                selectedSection = .playlist(playlist.id)
                detailAlbum = nil
                detailArtist = nil
            }
        } label: {
            HStack(spacing: 10) {
                if indented {
                    Spacer().frame(width: 8)
                }
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
                        .ariesGlass(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .contextMenu {
            if !library.playlistFolders.isEmpty {
                Menu("Move to Folder") {
                    Button("None") {
                        library.movePlaylist(playlist, to: nil)
                    }
                    ForEach(library.playlistFolders) { folder in
                        Button(folder.name) {
                            library.movePlaylist(playlist, to: folder.id)
                        }
                    }
                }
            }
            Button {
                exportPlaylistM3U(playlist)
            } label: {
                Label("Export M3U…", systemImage: "square.and.arrow.up")
            }
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
                detailPodcastFeed = nil
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
                        .ariesGlass(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                ListenLaterRow(
                    tracks: library.listenLaterTracks,
                    accent: theme.accent,
                    artworkURL: { library.artworkURL(for: $0) },
                    engine: engine,
                    library: library,
                    onViewAll: { selectSection(.listenLater) }
                )
                if !podcastStore.feeds.isEmpty {
                    PodcastHomeSection(
                        podcastStore: podcastStore,
                        engine: engine,
                        accent: theme.accent,
                        onViewAll: { selectSection(.podcasts) }
                    )
                }
                if !library.focusMixes.isEmpty {
                    FocusMixRow(
                        mixes: library.focusMixes,
                        accent: theme.accent,
                        artworkURL: { library.artworkURL(for: $0) },
                        engine: engine,
                        library: library,
                        onPlay: { mix, shuffle in
                            engine.playFromLibrary(
                                mix.tracks,
                                startIndex: 0,
                                store: library,
                                shuffleTracks: shuffle
                            )
                        }
                    )
                }
                if !library.genreListeningStats.isEmpty {
                    GenreListeningChart(
                        stats: library.genreListeningStats,
                        accent: theme.accent,
                        maxBars: 5,
                        onGenreSelected: { openGenre($0) },
                        onViewAll: { selectSection(.stats) }
                    )
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
            HomeStatCard(
                icon: "person.fill",
                label: "Artists",
                value: artists.count,
                accent: theme.accent,
                action: { selectSection(.artists) }
            )
            HomeStatCard(
                icon: "square.stack.fill",
                label: "Albums",
                value: albums.count,
                accent: theme.accent,
                action: { selectSection(.albums) }
            )
            HomeStatCard(
                icon: "music.note",
                label: "Tracks",
                value: library.tracks.count,
                accent: theme.accent,
                action: { selectSection(.tracks) }
            )
            if library.totalPlayCount > 0 {
                HomeStatCard(
                    icon: "clock.fill",
                    label: "Listened",
                    value: max(1, Int(library.totalListenSeconds / 3600)),
                    accent: theme.accent,
                    action: { selectSection(.stats) }
                )
            } else {
                HomeStatCard(
                    icon: "clock.fill",
                    label: "Hours",
                    value: Int(library.tracks.reduce(0) { $0 + $1.duration } / 3600),
                    accent: theme.accent
                )
            }
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
                    .ariesGlass(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: gridDensity.gridMinimum, maximum: gridDensity.gridMaximum), spacing: 20)],
                        spacing: 24
                    ) {
                        ForEach(albums) { album in
                            LibraryMediaTile(
                                title: album.title,
                                subtitle: album.artist,
                                artworkURL: library.artworkURL(for: album.artworkFile),
                                style: .album,
                                accent: theme.accent,
                                artSize: gridDensity.tileSize,
                                onOpen: { openAlbum(album) },
                                onPlay: { playAlbum(album) }
                            )
                            .libraryPlaybackMenu(engine: engine, library: library, tracks: album.tracks, album: album)
                        }
                    }
                }

                if !artists.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: gridDensity.gridMinimum, maximum: gridDensity.gridMaximum), spacing: 20)],
                        spacing: 24
                    ) {
                        ForEach(artists) { artist in
                            LibraryMediaTile(
                                title: artist.name,
                                subtitle: "\(artist.tracks.count) tracks",
                                artworkURL: library.artworkURL(for: artist.artworkFile),
                                style: .artist,
                                accent: theme.accent,
                                artSize: gridDensity.tileSize,
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
                        trackListRow(track)
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

                if library.genreGroups.isEmpty {
                    LibraryEmptySectionHint(
                        icon: "guitars",
                        title: "No genres found",
                        message: "Add genre tags to your files, or run Identify Library to pull metadata from MusicBrainz.",
                        actionTitle: "Open Library Settings",
                        action: { navigation.openSettings(tab: .library) }
                    )
                } else {
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
                            .ariesGlass(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
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
                                .ariesGlass(.regular, in: Capsule())
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
                                trackListRow(track)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var composersBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Composers")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                if library.composerGroups.isEmpty {
                    LibraryEmptySectionHint(
                        icon: "person.text.rectangle",
                        title: "No composers found",
                        message: "Composer tags appear when your files include them, or after Identify Library pulls credits from MusicBrainz.",
                        actionTitle: "Open Library Settings",
                        action: { navigation.openSettings(tab: .library) }
                    )
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(library.composerGroups) { composer in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    selectedSection = .composer(composer.name)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(composer.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text("\(composer.tracks.count) tracks")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .ariesGlass(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func composerBrowser(_ name: String) -> some View {
        let composer = library.composerGroups.first { $0.name == name }

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            selectedSection = .composers
                        }
                    } label: {
                        Label("Composers", systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)

                    Text(name)
                        .font(.system(size: 32, weight: .regular, design: .serif))
                }
                .padding(.top, 24)

                if let composer {
                    HStack(spacing: 12) {
                        Button {
                            engine.playFromLibrary(composer.tracks, startIndex: 0, store: library)
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            engine.playFromLibrary(composer.tracks, startIndex: 0, store: library, shuffleTracks: true)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .ariesGlass(.regular, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Works")
                            .font(.title3.weight(.semibold))
                        LazyVStack(spacing: 2) {
                            ForEach(composer.tracks) { track in
                                trackListRow(track)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var foldersBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Folders")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                if library.folderGroups.isEmpty {
                    LibraryEmptySectionHint(
                        icon: "folder",
                        title: "No folders found",
                        message: "Import music from a folder to browse by filesystem location.",
                        actionTitle: "Add Music",
                        action: importToLibrary
                    )
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(library.folderGroups) { folder in
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    selectedSection = .folder(folder.path)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(theme.accent)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(folder.name)
                                            .font(.subheadline.weight(.medium))
                                            .lineLimit(1)
                                        Text(folder.path)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(folder.tracks.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private func folderBrowser(_ path: String) -> some View {
        let folder = library.folderGroups.first { $0.path == path }

        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            selectedSection = .folders
                        }
                    } label: {
                        Label("Folders", systemImage: "chevron.left")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)

                    Text(folder?.name ?? "Folder")
                        .font(.system(size: 32, weight: .regular, design: .serif))
                }
                .padding(.top, 24)

                if let folder {
                    Text(folder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        Button {
                            engine.playFromLibrary(folder.tracks, startIndex: 0, store: library)
                        } label: {
                            Label("Play Folder", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            engine.playFromLibrary(folder.tracks, startIndex: 0, store: library, shuffleTracks: true)
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial, in: Capsule())
                                .ariesGlass(.regular, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tracks")
                            .font(.title3.weight(.semibold))
                        LazyVStack(spacing: 2) {
                            ForEach(folder.tracks) { track in
                                trackListRow(track)
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

                if library.totalPlayCount > 0 {
                    ListeningStatsSummary(
                        listenSeconds: library.totalListenSeconds,
                        playCount: library.totalPlayCount,
                        accent: theme.accent
                    )
                } else {
                    LibraryEmptySectionHint(
                        icon: "chart.bar",
                        title: "No listening history yet",
                        message: "Play some tracks and your stats, charts, and exports will appear here."
                    )
                }

                HStack(spacing: 12) {
                    Button("Export JSON") { exportListeningStats(asJSON: true) }
                        .buttonStyle(.bordered)
                    Button("Export CSV") { exportListeningStats(asJSON: false) }
                        .buttonStyle(.bordered)
                }

                GenreListeningChart(
                    stats: library.genreListeningStats,
                    accent: theme.accent,
                    onGenreSelected: { openGenre($0) }
                )

                HStack(alignment: .top, spacing: 20) {
                    TopListeningList(
                        title: "Top Artists",
                        stats: library.artistListeningStats,
                        accent: theme.accent,
                        onSelect: { stat in
                            if let artist = library.artistGroup(named: stat.id) {
                                openArtist(artist)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)

                    TopListeningList(
                        title: "Top Albums",
                        stats: library.albumListeningStats,
                        accent: theme.accent,
                        onSelect: { stat in
                            if let album = albums.first(where: { $0.id == stat.id }) {
                                openAlbum(album)
                            }
                        }
                    )
                    .frame(maxWidth: .infinity)
                }

                ListeningTimelineView(
                    days: library.listeningTimeline,
                    accent: theme.accent,
                    artworkURL: { library.artworkURL(for: $0) },
                    onPlayTrack: { play($0) },
                    onOpenAlbum: { openTrackAlbum($0) }
                )
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
                            .ariesGlass(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                trackListRow(track)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    private var listenLaterBrowser: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Listen Later")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .padding(.top, 24)

                if library.listenLaterTracks.isEmpty {
                    LibraryEmptySectionHint(
                        icon: "clock.badge.checkmark",
                        title: "Nothing saved yet",
                        message: "Right-click any track and choose Add to Listen Later."
                    )
                } else {
                    HStack(spacing: 12) {
                        Button {
                            engine.playFromLibrary(library.listenLaterTracks, startIndex: 0, store: library)
                        } label: {
                            Label("Play All", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVStack(spacing: 2) {
                        ForEach(library.listenLaterTracks) { track in
                            trackListRow(
                                track,
                                action: { play(track) }
                            )
                            .contextMenu {
                                Button {
                                    library.removeFromListenLater(track)
                                } label: {
                                    Label("Mark as Listened", systemImage: "checkmark.circle")
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
                                    trackListRow(
                                        track,
                                        isFavorite: true,
                                        onFavorite: { library.toggleFavorite(track: track) }
                                    )
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

                        if let playlist {
                            Button("Export M3U") {
                                exportPlaylistM3U(playlist)
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    LazyVStack(spacing: 2) {
                        ForEach(Array(playlistTracks.enumerated()), id: \.element.id) { index, track in
                            trackListRow(track) {
                                engine.playFromLibrary(playlistTracks, startIndex: index, store: library)
                            }
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
                            artSize: gridDensity.tileSize,
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
                            artSize: gridDensity.tileSize,
                            onOpen: { openArtist(artist) },
                            onPlay: { playArtist(artist) }
                        )
                        .libraryPlaybackMenu(engine: engine, library: library, tracks: artist.tracks, artist: artist)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .frame(height: gridDensity.rowHeight)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house")
                .font(.system(size: 52))
                .foregroundStyle(theme.accent.opacity(0.7))
            Text("Your library is empty")
                .font(.title3.weight(.semibold))
            Text("Import music, add a watched folder, or identify your library to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(spacing: 10) {
                Button("Add Music", action: importToLibrary)
                    .buttonStyle(.borderedProminent)
                    .tint(theme.accent)
                    .disabled(library.isImporting)

                Button("Add Watched Folder", action: addWatchedFolder)
                    .buttonStyle(.bordered)

                Button("Identify Library") {
                    library.identifyLibrary()
                }
                .buttonStyle(.bordered)
                .disabled(library.isIdentifying)

                Button("Library Settings") {
                    navigation.openSettings(tab: .library)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Button("Subscribe to Podcast") {
                    selectSection(.podcasts)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func trackListRow(
        _ track: LibraryTrack,
        isFavorite: Bool = false,
        onFavorite: (() -> Void)? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        LibraryTrackRow(
            track: track,
            artworkURL: library.artworkURL(for: track),
            accent: theme.accent,
            playCount: library.playCount(for: track.id),
            lastPlayed: library.lastPlayed(for: track.id),
            isFavorite: isFavorite,
            onFavorite: onFavorite
        ) {
            if let action {
                action()
            } else {
                play(track)
            }
        }
        .libraryPlaybackMenu(engine: engine, library: library, tracks: [track])
    }

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
            selectedSection = .home
            detailAlbum = album
            detailArtist = nil
        }
    }

    private func selectSection(_ section: HomeSection) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            selectedSection = section
            detailAlbum = nil
            detailArtist = nil
            detailPodcastFeed = nil
        }
    }

    private func openGenre(_ name: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            selectedSection = .genre(name)
            detailAlbum = nil
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

    private func createPlaylistFolder() {
        _ = library.createPlaylistFolder(named: "Folder \(library.playlistFolders.count + 1)")
    }

    private func exportPlaylistM3U(_ playlist: SavedPlaylist) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(playlist.name).m3u"
        if let m3uType = UTType(filenameExtension: "m3u") {
            panel.allowedContentTypes = [m3uType]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let content = library.exportM3U(for: playlist)
        try? content.write(to: url, atomically: true, encoding: .utf8)
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

    private func addWatchedFolder() {
        guard let url = MusicImportPanel.pickFiles(allowFolders: true, allowMultiple: false).first else { return }
        library.addWatchedFolder(url)
    }

    private func exportListeningStats(asJSON: Bool) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        if asJSON {
            panel.nameFieldStringValue = "aries-listening-stats.json"
            panel.allowedContentTypes = [.json]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard let data = try? ListeningStatsExport.jsonData(from: library) else { return }
            try? data.write(to: url)
        } else {
            panel.nameFieldStringValue = "aries-listening-stats.csv"
            panel.allowedContentTypes = [.commaSeparatedText]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let csv = ListeningStatsExport.csvString(from: library)
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Home-only types

private struct RecentAlbumItem: Identifiable {
    let album: AlbumGroup
    let date: Date
    var id: String { album.id }
}

private enum HomeSection: Hashable {
    case home, stats, duplicates, albums, artists, genres, composers, folders, years, tracks, favorites, listenLater, podcasts
    case genre(String)
    case composer(String)
    case folder(String)
    case year(Int)
    case playlist(UUID)
}

private enum RecentActivityTab {
    case played, added
}
