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
    @Environment(\.colorScheme) var colorScheme
    @State private var isTargeted = false
    @State private var isPlaylistVisible = true
    @State private var showHome = false
    @State private var wasWide = true
    @State private var windowSize: CGSize? = nil
    @State private var persistTask: Task<Void, Never>? = nil

    @AppStorage("lastNormalWidth") private var lastNormalWidth: Double = 900
    @AppStorage("lastNormalHeight") private var lastNormalHeight: Double = 600

    var body: some View {
        GeometryReader { geometry in
            let currentWidth = geometry.size.width
            let isWide = currentWidth > 600

            Group {
                if engine.queue.isEmpty && library.tracks.isEmpty {
                    emptyStateView
                } else if showHome || engine.queue.isEmpty {
                    HomeView(engine: engine, library: library)
                } else {
                    HStack(spacing: 0) {
                        if isPlaylistVisible {
                            PlaylistView(engine: engine)
                                .frame(minWidth: isWide ? 280 : nil,
                                       idealWidth: isWide ? 280 : nil,
                                       maxWidth: isWide ? 280 : .infinity,
                                       maxHeight: .infinity)
                                .background(Color.black.opacity(0.2))
                                .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
                        }

                        if isWide || !isPlaylistVisible {
                            PlayerView(
                                engine: engine,
                                togglePlaylist: {
                                    withAnimation(.spring()) {
                                        isPlaylistVisible.toggle()
                                    }
                                },
                                isPlaylistVisible: isPlaylistVisible,
                                showToggle: !isWide
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
                        }
                    }
                }
            }
            .background(backgroundLayer)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(.spring()) {
                            isPlaylistVisible.toggle()
                        }
                    }) {
                        Image(systemName: "sidebar.left")
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(.spring()) {
                            showHome.toggle()
                        }
                    }) {
                        Image(systemName: showHome ? "play.square.stack" : "square.grid.2x2")
                    }
                    .disabled(engine.queue.isEmpty)
                    .help(showHome ? "Show Player" : "Show Library")
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
                    withAnimation(.spring()) {
                        isPlaylistVisible = newIsWide
                    }
                }
                persistWindowSize(newSize)
            }
        }
        .frame(minWidth: 400, minHeight: 540)
        .tint(theme.accent)
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

            if let art = backgroundArtwork {
                art
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

    private var backgroundArtKey: String {
        if let id = engine.currentTrack?.id { return id.uuidString }
        if let hero = library.recentlyPlayed.first ?? library.tracks.first {
            return "home-\(hero.id.uuidString)"
        }
        return "none"
    }

    private var backgroundArtwork: Image? {
        if let art = engine.currentTrack?.albumArt {
            return art
        }
        if showHome || engine.queue.isEmpty,
           let hero = library.recentlyPlayed.first ?? library.tracks.first,
           let url = library.artworkURL(for: hero),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return nil
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
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = directories
        panel.canChooseFiles = !directories
        panel.allowedContentTypes = [.audio]

        if panel.runModal() == .OK {
            engine.addTracks(panel.urls)
        }
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


struct WindowSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
