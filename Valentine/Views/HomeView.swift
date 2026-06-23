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

    @State private var selectedSection: HomeSection = .home
    @State private var activityTab: RecentActivityTab = .added
    @State private var cachedGreeting: String = ""
    @State private var cachedAlbums: [AlbumGroup] = []
    @State private var cachedArtists: [ArtistGroup] = []
    @State private var detailAlbum: AlbumGroup?
    @State private var detailArtist: ArtistGroup?

    private var albums: [AlbumGroup] { cachedAlbums }
    private var artists: [ArtistGroup] { cachedArtists }

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
                        onBack: { withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { detailArtist = nil } }
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
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if cachedGreeting.isEmpty { cachedGreeting = greetingText() }
            recomputeGroups()
            refreshHomeTheme()
        }
        .onChange(of: library.tracks) { _, _ in
            recomputeGroups()
            refreshHomeTheme()
        }
        .onChange(of: library.recentlyPlayedIDs) { _, _ in
            refreshHomeTheme()
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
            }

            sidebarGroup("My Library") {
                sidebarItem(.albums, icon: "square.stack.fill", label: "Albums")
                sidebarItem(.artists, icon: "person.fill", label: "Artists")
                sidebarItem(.tracks, icon: "music.note", label: "Tracks")
            }

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                sidebarAction(icon: "plus", label: "Add Music", action: importToLibrary)
                sidebarAction(icon: "gearshape", label: "Settings") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
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
            Text(cachedGreeting.isEmpty ? greetingText() : cachedGreeting)
                .font(.system(size: 40, weight: .regular, design: .serif))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                UserDefaults.standard.set(SettingsTab.general.rawValue, forKey: "settingsOpenTab")
                NotificationCenter.default.post(
                    name: .openSettings,
                    object: nil,
                    userInfo: ["tab": SettingsTab.general.rawValue]
                )
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
            StatCard(icon: "person.fill", label: "Artists", value: artists.count, accent: theme.accent)
            StatCard(icon: "square.stack.fill", label: "Albums", value: albums.count, accent: theme.accent)
            StatCard(icon: "music.note", label: "Tracks", value: library.tracks.count, accent: theme.accent)
            StatCard(
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
                                    onPlay: { play(track) }
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
                            MediaTile(
                                title: album.title,
                                subtitle: album.artist,
                                artworkURL: library.artworkURL(for: album.artworkFile),
                                style: .album,
                                accent: theme.accent,
                                onOpen: { openAlbum(album) },
                                onPlay: { playAlbum(album) }
                            )
                        }
                    }
                }

                if !artists.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 20)], spacing: 24) {
                        ForEach(artists) { artist in
                            MediaTile(
                                title: artist.name,
                                subtitle: "\(artist.tracks.count) tracks",
                                artworkURL: library.artworkURL(for: artist.artworkFile),
                                style: .artist,
                                accent: theme.accent,
                                onOpen: { openArtist(artist) },
                                onPlay: { playArtist(artist) }
                            )
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
                        TrackListRow(
                            track: track,
                            artworkURL: library.artworkURL(for: track),
                            accent: theme.accent
                        ) { play(track) }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Rows

    private func albumRow(_ title: LocalizedStringKey, albums: [AlbumGroup]) -> some View {
        HomeRow(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(albums) { album in
                        MediaTile(
                            title: album.title,
                            subtitle: album.artist,
                            artworkURL: library.artworkURL(for: album.artworkFile),
                            style: .album,
                            accent: theme.accent,
                            onOpen: { openAlbum(album) },
                            onPlay: { playAlbum(album) }
                        )
                    }
                }
            }
            .scrollClipDisabled()
        }
        .frame(height: 218)
    }

    private func artistRow(_ title: LocalizedStringKey, artists: [ArtistGroup]) -> some View {
        HomeRow(title: title) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(artists) { artist in
                        MediaTile(
                            title: artist.name,
                            subtitle: "\(artist.tracks.count) tracks",
                            artworkURL: library.artworkURL(for: artist.artworkFile),
                            style: .artist,
                            accent: theme.accent,
                            onOpen: { openArtist(artist) },
                            onPlay: { playArtist(artist) }
                        )
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
        guard let hero,
              let url = library.artworkURL(for: hero),
              let image = NSImage(contentsOf: url) else { return }
        theme.update(from: image, key: "home-\(hero.id.uuidString)")
    }

    private func play(_ track: LibraryTrack) {
        guard let start = library.tracks.firstIndex(of: track) else { return }
        engine.playFromLibrary(library.tracks, startIndex: start, store: library)
    }

    private func playAlbum(_ album: AlbumGroup) {
        engine.playFromLibrary(album.tracks, startIndex: 0, store: library)
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
        if let album = albums.first(where: { group in
            group.tracks.contains(where: { $0.id == track.id })
        }) {
            openAlbum(album)
        } else if let albumTitle = track.album {
            let group = AlbumGroup(
                title: albumTitle,
                artist: track.artist,
                artworkFile: track.artworkFile,
                tracks: library.tracks.filter { ($0.album ?? $0.title) == albumTitle && $0.artist == track.artist }
            )
            openAlbum(group)
        }
    }

    private func albumsForArtist(_ artist: ArtistGroup) -> [AlbumGroup] {
        albums(forArtist: artist, in: albums)
    }

    private func importToLibrary() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .folder]
        if panel.runModal() == .OK {
            library.importFiles(panel.urls)
        }
    }

    private func recomputeGroups() {
        let tracks = library.tracks
        Task.detached(priority: .utility) {
            let groupedAlbums = groupAlbums(from: tracks)
            let groupedArtists: [ArtistGroup] = {
                let grouped = Dictionary(grouping: tracks) { $0.albumArtist }
                return grouped.map { name, tracks in
                    ArtistGroup(
                        name: name,
                        artworkFile: tracks.first(where: { $0.artworkFile != nil })?.artworkFile,
                        tracks: tracks.sorted { $0.dateAdded < $1.dateAdded }
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            }()
            await MainActor.run {
                self.cachedAlbums = groupedAlbums
                self.cachedArtists = groupedArtists
            }
        }
    }
}

// MARK: - Types

private struct RecentAlbumItem: Identifiable {
    let album: AlbumGroup
    let date: Date
    var id: String { album.id }
}

private enum HomeSection: Hashable {
    case home, albums, artists, tracks
}

private enum RecentActivityTab {
    case played, added
}

// MARK: - Grouping

struct AlbumGroup: Identifiable {
    let title: String
    let artist: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { title + artist }
}

struct ArtistGroup: Identifiable {
    let name: String
    let artworkFile: String?
    let tracks: [LibraryTrack]
    var id: String { name }
}

func groupAlbums(from tracks: [LibraryTrack]) -> [AlbumGroup] {
    let grouped = Dictionary(grouping: tracks) { $0.album ?? $0.artist }
    return grouped.map { key, group in
        let ordered = group.sorted { $0.dateAdded < $1.dateAdded }
        return AlbumGroup(
            title: key,
            artist: ordered.first?.artist ?? "Unknown Artist",
            artworkFile: ordered.first(where: { $0.artworkFile != nil })?.artworkFile,
            tracks: ordered
        )
    }
    .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
}

func artistGroup(named name: String, from tracks: [LibraryTrack]) -> ArtistGroup {
    let matching = tracks.filter { $0.albumArtist == name || $0.artist == name }
    return ArtistGroup(
        name: name,
        artworkFile: matching.first(where: { $0.artworkFile != nil })?.artworkFile,
        tracks: matching.sorted { $0.dateAdded > $1.dateAdded }
    )
}

func albums(forArtist artist: ArtistGroup, in albums: [AlbumGroup]) -> [AlbumGroup] {
    albums.filter { album in
        album.tracks.contains { $0.albumArtist == artist.name || $0.artist == artist.name }
    }
}

extension LibraryStore {
    func artworkURL(for file: String?) -> URL? {
        artworkURL(forFilename: file)
    }
}

// MARK: - Components

private struct StatCard: View {
    let icon: String
    let label: String
    let value: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct ActivityAlbumTile: View {
    let title: String
    let subtitle: String
    let badge: String?
    let artworkURL: URL?
    let accent: Color
    let onOpen: () -> Void
    let onPlay: () -> Void
    @State private var isHovered = false

    private let artSize: CGFloat = 136

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: onOpen) {
                    CachedArtwork(url: artworkURL, size: artSize, rounded: false)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay {
                            if let badge {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text(badge)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.black.opacity(0.55), in: Capsule())
                                        Spacer()
                                    }
                                    .padding(8)
                                }
                            }
                        }
                }
                .buttonStyle(.plain)

                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(accent.opacity(0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(width: artSize, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(width: artSize)
        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.85)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
        .scaleEffect(isHovered ? 1.02 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

private struct TrackListRow: View {
    let track: LibraryTrack
    let artworkURL: URL?
    let accent: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CachedArtwork(url: artworkURL, size: 44, rounded: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(track.duration.formatTime())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(accent)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? accent.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct HomeRow<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
            content
        }
    }
}

private struct MediaTile: View {
    enum Style { case album, artist }

    let title: String
    let subtitle: String
    let artworkURL: URL?
    let style: Style
    let accent: Color
    let onOpen: () -> Void
    let onPlay: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Button(action: onOpen) {
                    CachedArtwork(url: artworkURL, size: 148, rounded: style == .artist)
                        .scaleEffect(isHovered ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)

                if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(accent.opacity(0.9), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 148, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
