//
//  ContentView.swift
//  Aries
//
//  Created by Jesús David Chapman Vélez on 16/06/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var engine: AudioEngine
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    @EnvironmentObject var navigation: AppNavigation
    @Environment(\.colorScheme) var colorScheme
    @State private var isTargeted = false
    @State private var isPlaylistVisible = true
    @State private var showHome = false
    @State private var wasWide = true
    @State private var persistTask: Task<Void, Never>? = nil
    @State private var homeBackgroundImage: Image?

    @AppStorage("lastNormalWidth") private var lastNormalWidth: Double = 900
    @AppStorage("lastNormalHeight") private var lastNormalHeight: Double = 600

    private let navAnimation = Animation.spring(response: 0.46, dampingFraction: 0.88, blendDuration: 0.1)

    private var isLibraryEmpty: Bool {
        engine.queue.isEmpty && library.tracks.isEmpty
    }

    private var isHomeVisible: Bool {
        showHome || engine.queue.isEmpty
    }

    var body: some View {
        GeometryReader { geometry in
            let currentWidth = geometry.size.width
            let isWide = currentWidth >= 600

            ZStack {
                if isLibraryEmpty {
                    emptyStateView
                        .transition(.opacity)
                } else {
                    if !engine.queue.isEmpty {
                        playerLayout(isWide: isWide)
                            .opacity(isHomeVisible ? 0 : 1)
                            .scaleEffect(isHomeVisible ? 0.97 : 1, anchor: .center)
                            .offset(x: isHomeVisible ? 28 : 0)
                            .allowsHitTesting(!isHomeVisible)
                    }

                    HomeView(engine: engine, library: library)
                        .opacity(isHomeVisible ? 1 : 0)
                        .scaleEffect(isHomeVisible ? 1 : 0.97, anchor: .center)
                        .offset(x: isHomeVisible ? 0 : -28)
                        .allowsHitTesting(isHomeVisible)
                        .safeAreaInset(edge: .bottom, spacing: 12) {
                            if isHomeVisible, engine.currentTrack != nil {
                                HomeNowPlayingBar(engine: engine, accent: theme.accent) {
                                    withAnimation(navAnimation) { showHome = false }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                }
            }
            .animation(navAnimation, value: isHomeVisible)
            .background(backgroundLayer)
            .task(id: backgroundArtKey) {
                await loadHomeBackgroundArtwork()
            }
            .onChange(of: navigation.artistNameToOpen) { _, name in
                guard name != nil else { return }
                withAnimation(navAnimation) { showHome = true }
            }
            .onChange(of: navigation.albumIDToOpen) { _, albumID in
                guard albumID != nil else { return }
                withAnimation(navAnimation) { showHome = true }
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(navAnimation) {
                            isPlaylistVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                    }
                    .disabled(isHomeVisible)
                }
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(navAnimation) {
                            showHome.toggle()
                        }
                    }) {
                        Image(systemName: isHomeVisible ? "play.square.stack" : "square.grid.2x2")
                    }
                    .disabled(engine.queue.isEmpty)
                    .help(isHomeVisible ? "Show Player" : "Show Library")
                    .contentTransition(.symbolEffect(.replace))
                }
            }
            .toolbarBackground(.hidden, for: .windowToolbar)
            .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: geometry.size) { _, newSize in
                let newIsWide = newSize.width >= 600
                if newIsWide != wasWide {
                    wasWide = newIsWide
                    withAnimation(navAnimation) {
                        isPlaylistVisible = newIsWide
                    }
                }
                persistWindowSize(newSize)
            }
            .onChange(of: engine.currentTrackIndex) { _, newIndex in
                guard newIndex != nil, isHomeVisible, !engine.queue.isEmpty else { return }
                withAnimation(navAnimation) { showHome = false }
            }
        }
        .frame(minWidth: 400, minHeight: 540)
        .tint(theme.accent)
        .sheet(isPresented: $navigation.showLibrarySearch) {
            LibrarySearchView(engine: engine, library: library)
                .environmentObject(navigation)
                .environmentObject(theme)
        }
        .sheet(isPresented: $navigation.showSmartPlaylistBuilder) {
            SmartPlaylistBuilderView(library: library)
                .environmentObject(theme)
        }
    }

    @ViewBuilder
    private func playerLayout(isWide: Bool) -> some View {
        HStack(spacing: 0) {
            if isPlaylistVisible {
                PlaylistView(engine: engine)
                    .frame(minWidth: isWide ? 280 : nil,
                           idealWidth: isWide ? 280 : nil,
                           maxWidth: isWide ? 280 : .infinity,
                           maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }

            if isWide || !isPlaylistVisible {
                PlayerView(
                    engine: engine,
                    togglePlaylist: {
                        withAnimation(navAnimation) {
                            isPlaylistVisible.toggle()
                        }
                    },
                    isPlaylistVisible: isPlaylistVisible,
                    showToggle: !isWide
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func persistWindowSize(_ size: CGSize) {
        // Debounce writes to UserDefaults during live resize
        persistTask?.cancel()
        persistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            lastNormalWidth = Double(size.width)
            lastNormalHeight = Double(size.height)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(colors: theme.background, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: theme.background)

            if let art = engine.currentTrack?.albumArt {
                art
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: 90)
                    .opacity(0.55)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: backgroundArtKey)
            } else if let homeBackgroundImage {
                homeBackgroundImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: 90)
                    .opacity(0.55)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.5), value: backgroundArtKey)
            }
        }
    }

    private func loadHomeBackgroundArtwork() async {
        guard isHomeVisible, engine.currentTrack == nil else {
            homeBackgroundImage = nil
            return
        }
        guard let hero = library.recentlyPlayed.first ?? library.tracks.first,
              let url = library.artworkURL(for: hero),
              let image = await ArtworkLoader.shared.image(at: url, maxPixelSize: 512) else {
            homeBackgroundImage = nil
            return
        }
        homeBackgroundImage = Image(nsImage: image)
    }

    private var backgroundArtKey: String {
        if let id = engine.currentTrack?.id { return id.uuidString }
        if let hero = library.recentlyPlayed.first ?? library.tracks.first {
            return "home-\(hero.id.uuidString)"
        }
        return "none"
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .shadow(color: colorScheme == .dark ? .white.opacity(0.6) : .accentColor.opacity(0.4), radius: 25, x: 0, y: 0)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    .overlay(
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .scaleEffect(x: 1, y: -1)
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(colors: [.clear, .white.opacity(0.3)]),
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .opacity(0.5)
                            .offset(y: 140)
                    )
                    .padding(.bottom, 60)
            }

            Text("Aries")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Select a file or a folder, or drag files from your file manager to\nthe application window to add songs to the playlist")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                HoverZoomButton(title: "Add Folder...", isPrimary: true) {
                    selectFiles(directories: true)
                }

                HoverZoomButton(title: "Add File...", isPrimary: false) {
                    selectFiles(directories: false)
                }
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectFiles(directories: Bool) {
        let urls = MusicImportPanel.pickFiles(allowFolders: directories)
        guard !urls.isEmpty else { return }
        engine.addTracks(urls)
        library.importFiles(urls)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "dropQueue")
        var urls: [URL] = []

        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                defer { group.leave() }
                if let urlData = urlData as? Data,
                   let urlString = String(data: urlData, encoding: .utf8),
                   let url = URL(string: urlString) {
                    queue.async {
                        urls.append(url)
                    }
                } else if let url = urlData as? URL {
                    queue.async {
                        urls.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                engine.addTracks(urls)
                library.importFiles(urls)
            }
        }
        return true
    }
}

struct HoverZoomButton: View {
    let title: LocalizedStringKey
    let isPrimary: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isPrimary ? .white : .primary)
                .frame(width: 160, height: 40)
                .background(isPrimary ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// Compact bar shown on Home when a queue is active — tap to return to the player.
private struct HomeNowPlayingBar: View {
    @ObservedObject var engine: AudioEngine
    let accent: Color
    let onExpand: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            if let art = engine.currentTrack?.albumArt {
                art
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button(action: onExpand) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(engine.currentTrack?.title ?? "")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(engine.currentTrack?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                engine.togglePlayback()
            } label: {
                Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.85), in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button(action: onExpand) {
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(isHovered ? 0.18 : 0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isHovered)
        .onHover { isHovered = $0 }
    }
}
