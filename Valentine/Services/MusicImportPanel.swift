//
//  MusicImportPanel.swift
//  Aries
//

import AppKit
import UniformTypeIdentifiers

enum MusicImportPanel {
    static func pickFiles(allowFolders: Bool, allowMultiple: Bool = true) -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowMultiple
        panel.canChooseDirectories = allowFolders
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .folder]
        guard panel.runModal() == .OK else { return [] }
        return panel.urls
    }
}
