//
//  AppNavigation.swift
//  Aries
//

import SwiftUI
import Combine

@MainActor
final class AppNavigation: ObservableObject {
    @Published var artistNameToOpen: String?
    @Published var requestedSettingsTab: SettingsTab?
    @Published var shouldOpenSettings = false
    @Published var focusGreetingField = false
    @Published var showLibrarySearch = false
    @Published var showSmartPlaylistBuilder = false
    @Published var showKeyboardShortcuts = false
    @Published var librarySearchQuery = ""

    @Published var albumIDToOpen: String?

    func openArtist(_ name: String) {
        artistNameToOpen = name
    }

    func openAlbum(_ album: AlbumGroup) {
        albumIDToOpen = album.id
    }

    func openLibrarySearch() {
        showLibrarySearch = true
    }

    func openKeyboardShortcuts() {
        showKeyboardShortcuts = true
    }

    func openSmartPlaylistBuilder() {
        showSmartPlaylistBuilder = true
    }

    func openSettings(tab: SettingsTab = .general, focusGreeting: Bool = false) {
        requestedSettingsTab = tab
        focusGreetingField = focusGreeting
        shouldOpenSettings = true
    }
}
