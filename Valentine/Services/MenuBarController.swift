//
//  MenuBarController.swift
//  Aries
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var engine: AudioEngine?
    private var theme: AlbumTheme?
    private var cancellables = Set<AnyCancellable>()

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "menuBarEnabled") as? Bool ?? true
    }

    private var showOnlyWhenPlaying: Bool {
        UserDefaults.standard.object(forKey: "menuBarShowOnlyWhenPlaying") as? Bool ?? true
    }

    func attach(engine: AudioEngine, theme: AlbumTheme) {
        self.engine = engine
        self.theme = theme
        cancellables.removeAll()

        setupStatusItemIfNeeded()
        refresh()

        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        for key in ["menuBarEnabled", "menuBarShowOnlyWhenPlaying"] {
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.refreshVisibility() }
                .store(in: &cancellables)
        }
    }

    private func setupStatusItemIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Aries")
        item.button?.image?.isTemplate = true
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        item.button?.target = self
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            showMenu(from: sender)
            return
        }
        if event.type == .rightMouseUp {
            showMenu(from: sender)
        } else {
            togglePlayback()
        }
    }

    private func showMenu(from button: NSStatusBarButton) {
        guard engine != nil else { return }
        let menu = buildMenu()
        menu.items.forEach { $0.target = self }
        let point = NSPoint(x: button.bounds.midX, y: button.bounds.minY)
        menu.popUp(positioning: nil, at: point, in: button)
    }

    private func buildMenu() -> NSMenu {
        guard let engine else { return NSMenu() }
        let menu = NSMenu()

        if let track = engine.currentTrack {
            let titleItem = NSMenuItem(title: track.title, action: nil, keyEquivalent: "")
            titleItem.isEnabled = false
            menu.addItem(titleItem)
            let artistItem = NSMenuItem(title: track.artist, action: nil, keyEquivalent: "")
            artistItem.isEnabled = false
            menu.addItem(artistItem)
            menu.addItem(.separator())
        }

        menu.addItem(withTitle: engine.isPlaying ? "Pause" : "Play",
                     action: #selector(togglePlaybackAction),
                     keyEquivalent: "")
        menu.addItem(withTitle: "Next Track", action: #selector(nextTrackAction), keyEquivalent: "")
        menu.addItem(withTitle: "Previous Track", action: #selector(previousTrackAction), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Aries", action: #selector(openMainWindow), keyEquivalent: "")
        menu.addItem(withTitle: "Mini Player", action: #selector(openMiniPlayer), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        return menu
    }

    @objc private func togglePlaybackAction() { togglePlayback() }
    @objc private func nextTrackAction() { engine?.nextTrack() }
    @objc private func previousTrackAction() { engine?.previousTrack() }

    @objc private func openMainWindow() {
        UserDefaults.standard.set(false, forKey: "isMiniPlayerMode")
        NSApp.activate(ignoringOtherApps: true)
        MainWindowManager.shared.activateMainWindow()
    }

    @objc private func openMiniPlayer() {
        UserDefaults.standard.set(true, forKey: "isMiniPlayerMode")
        NSApp.activate(ignoringOtherApps: true)
        MainWindowManager.shared.activateMainWindow()
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    private func togglePlayback() {
        engine?.togglePlayback()
    }

    private func refresh() {
        refreshVisibility()
        refreshButton()
    }

    private func refreshVisibility() {
        guard let statusItem else { return }
        if !isEnabled {
            statusItem.isVisible = false
            return
        }
        statusItem.isVisible = !showOnlyWhenPlaying || engine?.currentTrack != nil
    }

    private func refreshButton() {
        guard let button = statusItem?.button else { return }
        if let image = engine?.currentTrack?.nsImage {
            button.image = image
            button.image?.size = NSSize(width: 18, height: 18)
            button.imagePosition = .imageLeading
            button.title = ""
        } else {
            button.image = NSImage(systemSymbolName: engine?.isPlaying == true ? "pause.fill" : "music.note", accessibilityDescription: "Aries")
            button.image?.isTemplate = true
            button.title = ""
        }
        button.toolTip = engine?.currentTrack.map { "\($0.title) — \($0.artist)" } ?? "Aries"
    }
}
