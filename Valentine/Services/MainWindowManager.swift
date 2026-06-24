//
//  MainWindowManager.swift
//  Aries
//

import AppKit

@MainActor
final class MainWindowManager: NSObject, NSWindowDelegate {
    static let shared = MainWindowManager()

    private let snapThreshold: CGFloat = 18
    private var observedWindow: NSWindow?
    private var isMiniPlayerMode = false

    var isPinned: Bool {
        get { UserDefaults.standard.bool(forKey: "miniPlayerPinned") }
        set { UserDefaults.standard.set(newValue, forKey: "miniPlayerPinned") }
    }

    func configureMainWindow(_ window: NSWindow, miniPlayer: Bool, normalSize: CGSize) {
        observedWindow = window
        isMiniPlayerMode = miniPlayer
        window.delegate = self

        let settingsID = window.identifier?.rawValue ?? ""
        if settingsID.contains("settings") || settingsID.contains("about") { return }

        window.isMovableByWindowBackground = true
        window.standardWindowButton(.closeButton)?.isHidden = miniPlayer
        window.standardWindowButton(.miniaturizeButton)?.isHidden = miniPlayer
        window.standardWindowButton(.zoomButton)?.isHidden = miniPlayer

        if miniPlayer || isPinned {
            window.level = .floating
        } else {
            window.level = .normal
        }

        if miniPlayer {
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true

            var frame = window.frame
            let oldHeight = frame.size.height
            frame.size = NSSize(width: 480, height: currentMiniPlayerHeight())
            if hasSavedMiniPlayerPosition(), let screen = screenForSavedPosition() {
                frame.origin = restoredMiniPlayerOrigin(for: frame.size, on: screen)
            } else {
                frame.origin.y += (oldHeight - frame.size.height)
            }
            window.setFrame(frame, display: true, animate: true)
        } else {
            window.backgroundColor = .windowBackgroundColor
            window.isOpaque = true

            var frame = window.frame
            let oldHeight = frame.size.height
            let targetWidth = max(400, normalSize.width)
            let targetHeight = max(540, normalSize.height)
            frame.size = NSSize(width: targetWidth, height: targetHeight)
            frame.origin.y -= (targetHeight - oldHeight)
            window.setFrame(frame, display: true, animate: true)
        }
    }

    func updateMiniPlayerHeight(_ height: CGFloat) {
        guard isMiniPlayerMode, let window = observedWindow else { return }
        var frame = window.frame
        let delta = height - frame.size.height
        frame.size.height = height
        frame.origin.y -= delta
        window.setFrame(frame, display: true, animate: true)
    }

    func activateMainWindow() {
        guard let window = mainAppWindow() else { return }
        window.makeKeyAndOrderFront(nil)
    }

    func mainAppWindow() -> NSWindow? {
        NSApp.windows.first { window in
            let id = window.identifier?.rawValue ?? ""
            return !id.contains("settings") && !id.contains("about")
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard isMiniPlayerMode, let window = notification.object as? NSWindow else { return }
        persistMiniPlayerFrame(window.frame)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard isMiniPlayerMode, let window = notification.object as? NSWindow else { return }
        snapWindowToEdges(window)
    }

    private func snapWindowToEdges(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame

        if abs(frame.minX - visible.minX) < snapThreshold {
            frame.origin.x = visible.minX + 8
        } else if abs(frame.maxX - visible.maxX) < snapThreshold {
            frame.origin.x = visible.maxX - frame.width - 8
        }

        if abs(frame.minY - visible.minY) < snapThreshold {
            frame.origin.y = visible.minY + 8
        } else if abs(frame.maxY - visible.maxY) < snapThreshold {
            frame.origin.y = visible.maxY - frame.height - 8
        }

        if frame != window.frame {
            window.setFrame(frame, display: true, animate: true)
        }
        persistMiniPlayerFrame(frame)
    }

    private func currentMiniPlayerHeight() -> CGFloat {
        let stored = UserDefaults.standard.double(forKey: "miniPlayerLastHeight")
        if stored < 140 || stored > 240 { return 140 }
        return CGFloat(stored)
    }

    private func hasSavedMiniPlayerPosition() -> Bool {
        UserDefaults.standard.double(forKey: "miniPlayerOriginX") >= 0
    }

    private func screenForSavedPosition() -> NSScreen? {
        NSScreen.screens.first ?? NSScreen.main
    }

    private func restoredMiniPlayerOrigin(for size: NSSize, on screen: NSScreen) -> NSPoint {
        let visible = screen.visibleFrame
        let x = UserDefaults.standard.double(forKey: "miniPlayerOriginX")
        let y = UserDefaults.standard.double(forKey: "miniPlayerOriginY")
        var origin = NSPoint(x: x, y: y)
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        return origin
    }

    private func persistMiniPlayerFrame(_ frame: NSRect) {
        UserDefaults.standard.set(frame.origin.x, forKey: "miniPlayerOriginX")
        UserDefaults.standard.set(frame.origin.y, forKey: "miniPlayerOriginY")
        UserDefaults.standard.set(frame.size.height, forKey: "miniPlayerLastHeight")
    }

    func refreshWindowLevel() {
        guard let window = mainAppWindow() else { return }
        let mini = UserDefaults.standard.bool(forKey: "isMiniPlayerMode")
        window.level = (mini || isPinned) ? .floating : .normal
    }
}
