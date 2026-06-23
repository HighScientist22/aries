//
//  HomeView.swift
//  Aries
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct HomeView: View {
    @ObservedObject var engine: AudioEngine
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme

    @State private var cachedGreeting: String = ""
    @State private var cachedAlbums: [AlbumGroup] = []
    @State private var cachedArtists: [ArtistGroup] = []

    private var albums: [AlbumGroup] { cachedAlbums }
    private var artists: [ArtistGroup] { cachedArtists }
    private var heroTrack: LibraryTrack? {
        library.recentlyPlayed.first ?? library.tracks.first
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 40) {
                pageHeader

                if library.tracks.isEmpty {
                    emptyLibrary
                } else {
                    if let hero = heroTrack {
                        continueListeningHero(hero)
                    }

                    if !library.recentlyPlayed.isEmpty {
                        trackRow("Recently Played", tracks: library.recentlyPlayed)
                    }

                    trackRow("Recently Added", tracks: Array(library.tracks.prefix(20)))

                    albumRow("Albums", albums: albums)

                    artistRow("Artists", artists: artists)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 48)
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

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cachedGreeting.isEmpty ? greetingText() : cachedGreeting)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(librarySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    UserDefaults.standard.set(SettingsTab.general.rawValue, forKey: "settingsOpenTab")
                    NotificationCenter.default.post(
                        name: .openSettings,
                        object: nil,
                        userInfo: ["tab": SettingsTab.general.rawValue]
                    )
                } label: {
                    Image(systemName: "pencil")
                        .font(.body.weight(.medium))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Edit Greeting")

                Button(action: importToLibrary) {
                    Label("Add Music", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
                .controlSize(.regular)
                .disabled(library.isImporting)
            }
        }
        .padding(.horizontal, 32)
    }

    private var librarySummary: String {
        let albumCount = albums.count
        let trackCount = library.tracks.count
        if trackCount == 0 { return "No music in your library yet" }
        return "\(trackCount) tracks · \(albumCount) albums"
    }

    // MARK: - Hero

    private func continueListeningHero(_ track: LibraryTrack) -> some View {
        let artworkURL = library.artworkURL(for: track)
        let albumGroup = albums.first(where: { $0.tracks.contains(where: { $0.id == track.id }) })

        return ZStack(alignment: .leading) {
            HeroArtworkBackdrop(url: artworkURL, accent: theme.accent)

            HStack(spacing: 24) {
                CachedArtwork(url: artworkURL, size: 168, rounded: false)
                    .shadow(color: theme.accent.opacity(0.35), radius: 20, y: 10)
                    .shadow(color: .black.opacity(0.4), radius: 12, y: 6)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Continue Listening")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent.opacity(0.9))
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(track.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(track.artist)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let album = track.album, !album.isEmpty {
                        Text(album)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Button(action: { play(track) }) {
                            Label("Play", systemImage: "play.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(theme.accent, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)

                        if let albumGroup {
                            Button(action: { playAlbum(albumGroup) }) {
                                Label("Play Album", systemImage: "square.stack.fill")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(.white.opacity(0.1), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }

    // MARK: - Rows

    private func trackRow(_ title: LocalizedStringKey, tracks: [LibraryTrack]) -> some View {
        HomeRow(title: title, accent: theme.accent) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(tracks) { track in
                        MediaTile(
                            title: track.title,
                            subtitle: track.artist,
                            artworkURL: library.artworkURL(for: track),
                            style: .album,
                            accent: theme.accent
                        ) {
                            play(track)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }
            .scrollClipDisabled()
        }
        .frame(height: 218)
    }

    private func albumRow(_ title: LocalizedStringKey, albums: [AlbumGroup]) -> some View {
        HomeRow(title: title, accent: theme.accent) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(albums) { album in
                        MediaTile(
                            title: album.title,
                            subtitle: album.artist,
                            artworkURL: library.artworkURL(for: album.artworkFile),
                            style: .album,
                            accent: theme.accent
                        ) {
                            playAlbum(album)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }
            .scrollClipDisabled()
        }
        .frame(height: 218)
    }

    private func artistRow(_ title: LocalizedStringKey, artists: [ArtistGroup]) -> some View {
        HomeRow(title: title, accent: theme.accent) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(artists) { artist in
                        MediaTile(
                            title: artist.name,
                            subtitle: "\(artist.tracks.count) tracks",
                            artworkURL: library.artworkURL(for: artist.artworkFile),
                            style: .artist,
                            accent: theme.accent
                        ) {
                            playArtist(artist)
                        }
                    }
                }
                .padding(.horizontal, 32)
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
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 32)
    }

    // MARK: - Actions

    private func greetingText() -> String {
        if let custom = UserDefaults.standard.string(forKey: "customGreeting"),
           !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return custom
        }

        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<18: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }

        let fullName = NSFullUserName()
        let first = fullName.split(separator: " ").first.map(String.init) ?? fullName
        return "\(timeGreeting), \(first)"
    }

    private func refreshHomeTheme() {
        guard let hero = heroTrack,
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

extension LibraryStore {
    func artworkURL(for file: String?) -> URL? {
        artworkURL(forFilename: file)
    }
}

// MARK: - Components

private struct HomeRow<Content: View>: View {
    let title: LocalizedStringKey
    let accent: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 32)
            content
        }
    }
}

private struct HeroArtworkBackdrop: View {
    let url: URL?
    let accent: Color
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 48)
                    .scaleEffect(1.15)
                    .clipped()
            }

            LinearGradient(
                colors: [
                    accent.opacity(0.45),
                    accent.opacity(0.15),
                    .black.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [.black.opacity(0.1), .black.opacity(0.65)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await ArtworkLoader.shared.image(at: url)
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
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                CachedArtwork(
                    url: artworkURL,
                    size: 148,
                    rounded: style == .artist
                )
                .overlay {
                    if isHovered {
                        RoundedRectangle(cornerRadius: style == .artist ? 74 : 12, style: .continuous)
                            .fill(.black.opacity(0.35))
                        Image(systemName: "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(color: accent.opacity(0.6), radius: 8)
                    }
                }
                .scaleEffect(isHovered ? 1.02 : 1.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 148, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
