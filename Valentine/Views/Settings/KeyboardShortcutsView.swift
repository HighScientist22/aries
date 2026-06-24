//
//  KeyboardShortcutsView.swift
//  Aries
//

import SwiftUI

struct KeyboardShortcutRow: Identifiable {
    let id = UUID()
    let action: String
    let keys: String
}

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(title: String, rows: [KeyboardShortcutRow])] = [
        ("Playback", [
            KeyboardShortcutRow(action: "Play / Pause", keys: "Space"),
            KeyboardShortcutRow(action: "Previous Track", keys: "⌘ ←"),
            KeyboardShortcutRow(action: "Next Track", keys: "⌘ →"),
        ]),
        ("Library", [
            KeyboardShortcutRow(action: "Search Library", keys: "⌘ K"),
            KeyboardShortcutRow(action: "Add File", keys: "⌘ O"),
            KeyboardShortcutRow(action: "Add Folder", keys: "⌘ ⇧ O"),
            KeyboardShortcutRow(action: "Clear Playlist", keys: "⌘ ⌫"),
        ]),
        ("Player", [
            KeyboardShortcutRow(action: "Edit Lyrics", keys: "⌘ E"),
            KeyboardShortcutRow(action: "Toggle Mini Player", keys: "⌘ M"),
            KeyboardShortcutRow(action: "Filter Queue", keys: "⌘ F"),
        ]),
        ("Navigation", [
            KeyboardShortcutRow(action: "Settings", keys: "⌘ ,"),
            KeyboardShortcutRow(action: "Keyboard Shortcuts", keys: "⌘ /"),
            KeyboardShortcutRow(action: "Back", keys: "Esc"),
        ]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 0) {
                                ForEach(section.rows) { row in
                                    HStack {
                                        Text(row.action)
                                        Spacer()
                                        Text(row.keys)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                                    }
                                    .padding(.vertical, 8)
                                    if row.id != section.rows.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 420, height: 480)
    }
}
