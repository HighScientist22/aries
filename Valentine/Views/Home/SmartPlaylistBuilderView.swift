//
//  SmartPlaylistBuilderView.swift
//  Aries
//

import SwiftUI

struct SmartPlaylistBuilderView: View {
    @ObservedObject var library: LibraryStore
    @EnvironmentObject var theme: AlbumTheme
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var matchAll = true
    @State private var criteria: [SmartPlaylistCriterion] = [
        SmartPlaylistCriterion(field: .genre, match: .contains, value: "")
    ]

    private var previewCount: Int {
        library.resolveSmartPlaylist(.custom(matchAll: matchAll, criteria: criteria)).count
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Custom Smart Playlist")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                Button("Create") { createPlaylist() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.accent)
                    .disabled(criteria.isEmpty)
            }
            .padding(16)
            .background(.ultraThinMaterial)

            Divider()

            Form {
                Section("Name") {
                    TextField("Playlist name", text: $name)
                }

                Section("Match") {
                    Picker("Rules", selection: $matchAll) {
                        Text("All criteria").tag(true)
                        Text("Any criterion").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Criteria") {
                    ForEach($criteria) { $criterion in
                        criterionRow($criterion)
                    }
                    .onDelete { criteria.remove(atOffsets: $0) }

                    Button {
                        criteria.append(SmartPlaylistCriterion())
                    } label: {
                        Label("Add Criterion", systemImage: "plus")
                    }
                }

                Section {
                    Text("\(previewCount) matching tracks")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 480, minHeight: 420)
    }

    @ViewBuilder
    private func criterionRow(_ criterion: Binding<SmartPlaylistCriterion>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Field", selection: criterion.field) {
                ForEach(SmartCriterionField.allCases) { field in
                    Text(field.label).tag(field)
                }
            }

            if criterion.wrappedValue.field.isBoolean {
                Picker("Value", selection: criterion.value) {
                    Text("Yes").tag("true")
                    Text("No").tag("false")
                }
                .onAppear {
                    if criterion.wrappedValue.value != "true" && criterion.wrappedValue.value != "false" {
                        criterion.wrappedValue.value = "true"
                    }
                }
            } else {
                Picker("Match", selection: criterion.match) {
                    ForEach(SmartCriterionMatch.options(for: criterion.wrappedValue.field)) { option in
                        Text(option.label).tag(option)
                    }
                }
                .onChange(of: criterion.wrappedValue.field) { _, field in
                    let options = SmartCriterionMatch.options(for: field)
                    if !options.contains(criterion.wrappedValue.match) {
                        criterion.wrappedValue.match = options[0]
                    }
                }

                TextField("Value", text: criterion.value)
            }
        }
        .padding(.vertical, 4)
    }

    private func createPlaylist() {
        let rule = SmartPlaylistRule.custom(matchAll: matchAll, criteria: criteria)
        let playlistName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = library.createSmartPlaylist(
            named: playlistName.isEmpty ? rule.defaultName : playlistName,
            rule: rule
        )
        dismiss()
    }
}
