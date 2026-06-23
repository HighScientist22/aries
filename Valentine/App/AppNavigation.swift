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

    func openArtist(_ name: String) {
        artistNameToOpen = name
    }

    func openSettings(tab: SettingsTab = .general, focusGreeting: Bool = false) {
        requestedSettingsTab = tab
        focusGreetingField = focusGreeting
        shouldOpenSettings = true
    }
}
