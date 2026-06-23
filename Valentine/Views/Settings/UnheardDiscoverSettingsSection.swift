//
//  UnheardDiscoverSettingsSection.swift
//  Aries
//

import SwiftUI

struct UnheardDiscoverSettingsSection: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var featureEnabled = UnheardDiscoverPreferences.isFeatureEnabled

    private var sortedLibraryGenres: [GenreGroup] {
        library.genreGroups.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        Section(header: Text("Discover Unheard Music")) {
            Toggle("Show unheard mixes on home", isOn: $featureEnabled)
                .onChange(of: featureEnabled) { _, enabled in
                    UnheardDiscoverPreferences.isFeatureEnabled = enabled
                    library.refreshHomeMixes()
                }

            if featureEnabled {
                Text("Pick which mixes you want on the home screen.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Group {
                    Text("Presets")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    ForEach(UnheardDiscoverGenre.allCases) { genre in
                        Toggle(genre.settingsLabel, isOn: presetBinding(for: genre))
                    }
                }

                if !sortedLibraryGenres.isEmpty {
                    Group {
                        Text("From your library")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)

                        ForEach(sortedLibraryGenres) { group in
                            Toggle(group.name, isOn: libraryGenreBinding(for: group.name))
                        }
                    }
                }

                if UnheardDiscoverPreferences.enabledPresets.isEmpty
                    && UnheardDiscoverPreferences.enabledLibraryGenres.isEmpty {
                    Text("Turn on at least one genre to see a focus mix.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Each mix needs at least 8 tracks you haven't played recently.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func presetBinding(for genre: UnheardDiscoverGenre) -> Binding<Bool> {
        Binding(
            get: { UnheardDiscoverPreferences.isPresetEnabled(genre) },
            set: { enabled in
                UnheardDiscoverPreferences.setPresetEnabled(genre, enabled: enabled)
                library.refreshHomeMixes()
            }
        )
    }

    private func libraryGenreBinding(for name: String) -> Binding<Bool> {
        Binding(
            get: { UnheardDiscoverPreferences.isLibraryGenreEnabled(name) },
            set: { enabled in
                UnheardDiscoverPreferences.setLibraryGenreEnabled(name, enabled: enabled)
                library.refreshHomeMixes()
            }
        )
    }
}
