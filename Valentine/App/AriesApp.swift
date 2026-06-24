//
//  AriesApp.swift
//  Aries
//
//  Created by Jesús David Chapman Vélez on 16/06/26.
//  Fork: Aries by the Aries contributors.
//

import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        NotificationCenter.default.post(name: .openAudioFiles, object: urls)
    }
}

@main
struct AriesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appTheme") private var appTheme = 0
    @StateObject private var engine = AudioEngine()
    @StateObject private var library = LibraryStore()
    @StateObject private var theme = AlbumTheme()
    @StateObject private var navigation = AppNavigation()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(engine)
                .environmentObject(library)
                .environmentObject(theme)
                .environmentObject(navigation)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AriesCommands()
        }

        Window("About Aries", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 650, height: 480)

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(library)
                .environmentObject(navigation)
                .preferredColorScheme(appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil))
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @EnvironmentObject var engine: AudioEngine
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    @EnvironmentObject var navigation: AppNavigation
    @Environment(\.openWindow) var openWindow
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @AppStorage("appTheme") private var appTheme = 0

    @AppStorage("lastNormalWidth") private var lastNormalWidth: Double = 900
    @AppStorage("lastNormalHeight") private var lastNormalHeight: Double = 600

    var body: some View {
        Group {
            if isMiniPlayerMode {
                MiniPlayerView(engine: engine)
            } else {
                ContentView()
                    .environmentObject(engine)
                    .environmentObject(library)
                    .environmentObject(theme)
            }
        }
        .animation(.easeInOut, value: isMiniPlayerMode)
        .preferredColorScheme(appTheme == 1 ? .light : (appTheme == 2 ? .dark : nil))
        .onAppear {
            updateTheme(theme: appTheme)
            configureWindow(forMiniPlayer: isMiniPlayerMode)
            theme.update(from: engine.currentTrack?.nsImage, key: engine.currentTrack?.id.uuidString)
            engine.attachLibraryStore(library)
            MenuBarController.shared.attach(engine: engine, theme: theme)
        }
        .onChange(of: engine.currentTrackIndex) { _, _ in
            theme.update(from: engine.currentTrack?.nsImage, key: engine.currentTrack?.id.uuidString)
        }
        .onChange(of: appTheme) { _, newTheme in
            updateTheme(theme: newTheme)
        }
        .onChange(of: isMiniPlayerMode) { _, newValue in
            configureWindow(forMiniPlayer: newValue)
        }
        .sheet(isPresented: $engine.showLyricsEditor) {
            LyricsEditorView()
                .environmentObject(engine)
        }
        .sheet(isPresented: $engine.showMutagenInstaller) {
            MutagenInstallerView {
                engine.showLyricsEditor = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addFile)) { _ in engine.showAddFileDialog() }
        .onReceive(NotificationCenter.default.publisher(for: .addFolder)) { _ in engine.showAddFolderDialog() }
        .onReceive(NotificationCenter.default.publisher(for: .clearPlaylist)) { _ in engine.clearPlaylist() }
        .onReceive(NotificationCenter.default.publisher(for: .editLyrics)) { _ in engine.checkAndShowLyricsEditor() }
        .onReceive(NotificationCenter.default.publisher(for: .reinstallMutagen)) { _ in engine.showMutagenInstaller = true }
        .onChange(of: navigation.shouldOpenSettings) { _, shouldOpen in
            guard shouldOpen else { return }
            openWindow(id: "settings")
            navigation.shouldOpenSettings = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .openLibrarySearch)) { _ in
            navigation.openLibrarySearch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showKeyboardShortcuts)) { _ in
            navigation.openKeyboardShortcuts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openWindow(id: "settings")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAudioFiles)) { notification in
            guard let urls = notification.object as? [URL], !urls.isEmpty else { return }
            engine.addTracks(urls)
            library.importFiles(urls)
            UserDefaults.standard.set(false, forKey: "isMiniPlayerMode")
            NSApp.activate(ignoringOtherApps: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            engine.persistQueueNow()
        }
    }

    private func updateTheme(theme: Int) {
        #if os(macOS)
        DispatchQueue.main.async {
            let appearance: NSAppearance?
            switch theme {
            case 1: appearance = NSAppearance(named: .aqua)
            case 2: appearance = NSAppearance(named: .darkAqua)
            default: appearance = nil
            }
            NSApplication.shared.appearance = appearance
        }
        #endif
    }

    private func configureWindow(forMiniPlayer: Bool) {
        #if os(macOS)
        DispatchQueue.main.async {
            guard let window = MainWindowManager.shared.mainAppWindow() else { return }
            MainWindowManager.shared.configureMainWindow(
                window,
                miniPlayer: forMiniPlayer,
                normalSize: CGSize(width: lastNormalWidth, height: lastNormalHeight)
            )
        }
        #endif
    }
}

struct AriesCommands: Commands {
    @AppStorage("isMiniPlayerMode") private var isMiniPlayerMode = false
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(action: {
                openWindow(id: "about")
            }) {
                Label("About Aries", systemImage: "info.circle")
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(action: { openWindow(id: "settings") }) {
                Label("Settings...", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
            Button(action: { NotificationCenter.default.post(name: .addFile, object: nil) }) {
                Label("Add File...", systemImage: "doc.badge.plus")
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button(action: { NotificationCenter.default.post(name: .addFolder, object: nil) }) {
                Label("Add Folder...", systemImage: "folder.badge.plus")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Divider()

            Button(action: { NotificationCenter.default.post(name: .clearPlaylist, object: nil) }) {
                Label("Clear Playlist", systemImage: "trash")
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }

        CommandGroup(after: .textEditing) {
            Divider()
            Button(action: { NotificationCenter.default.post(name: .openLibrarySearch, object: nil) }) {
                Label("Search Library", systemImage: "magnifyingglass")
            }
            .keyboardShortcut("k", modifiers: [.command])
            Divider()
            Button(action: { NotificationCenter.default.post(name: .editLyrics, object: nil) }) {
                Label("Edit Lyrics", systemImage: "music.note.list")
            }
            .keyboardShortcut("e", modifiers: [.command])
        }

        CommandGroup(replacing: .help) {
            Button(action: { NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil) }) {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
            }
            .keyboardShortcut("/", modifiers: [.command])
            Divider()
            Button(action: { NotificationCenter.default.post(name: .reinstallMutagen, object: nil) }) {
                Label("Reinstall Mutagen", systemImage: "arrow.triangle.2.circlepath")
            }
        }

        CommandGroup(after: .windowList) {
            Button(action: { isMiniPlayerMode.toggle() }) {
                Label(isMiniPlayerMode ? "Switch to Full Player" : "Switch to Mini-Player", systemImage: isMiniPlayerMode ? "arrow.up.left.and.arrow.down.right" : "pip.enter")
            }
            .keyboardShortcut("m", modifiers: [.command])
        }
    }
}
