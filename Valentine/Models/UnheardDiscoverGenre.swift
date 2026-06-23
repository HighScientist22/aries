//
//  UnheardDiscoverGenre.swift
//  Aries
//

import Foundation

enum UnheardDiscoverGenre: String, CaseIterable, Identifiable, Codable {
    case rb
    case rap
    case alt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rb: return "Unheard R&B"
        case .rap: return "Unheard Rap"
        case .alt: return "Unheard Alt"
        }
    }

    var settingsLabel: String {
        switch self {
        case .rb: return "R&B"
        case .rap: return "Rap"
        case .alt: return "Alt"
        }
    }

    var focusMixID: String { "unheard-\(rawValue)" }

    func matches(tag: String) -> Bool {
        let normalized = tag.lowercased()
        switch self {
        case .rb:
            return normalized.contains("r&b")
                || normalized.contains("rnb")
                || normalized.contains("rhythm and blues")
                || normalized.contains("soul")
                || normalized.contains("neo-soul")
                || normalized.contains("neo soul")
                || normalized.contains("contemporary r&b")
        case .rap:
            return normalized.contains("rap")
                || normalized.contains("hip hop")
                || normalized.contains("hip-hop")
                || normalized.contains("hiphop")
                || normalized.contains("trap")
                || normalized.contains("drill")
                || normalized.contains("grime")
        case .alt:
            return normalized.contains("alt")
                || normalized.contains("alternative")
                || normalized.contains("indie")
                || normalized.contains("post-punk")
                || normalized.contains("shoegaze")
                || normalized.contains("college rock")
        }
    }
}

enum UnheardDiscoverPreferences {
    private static let featureEnabledKey = "unheardDiscoverEnabled"
    private static let presetsKey = "unheardDiscoverPresets"
    private static let libraryGenresKey = "unheardDiscoverLibraryGenres"

    static var isFeatureEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: featureEnabledKey) != nil {
                return UserDefaults.standard.bool(forKey: featureEnabledKey)
            }
            return migratedLegacyEnabledDefault()
        }
        set { UserDefaults.standard.set(newValue, forKey: featureEnabledKey) }
    }

    static var enabledPresets: Set<UnheardDiscoverGenre> {
        get {
            if let stored = UserDefaults.standard.stringArray(forKey: presetsKey) {
                return Set(stored.compactMap(UnheardDiscoverGenre.init(rawValue:)))
            }
            return migratedLegacyPresets()
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: presetsKey)
        }
    }

    static var enabledLibraryGenres: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: libraryGenresKey) ?? [])
        }
        set {
            UserDefaults.standard.set(newValue.sorted(), forKey: libraryGenresKey)
        }
    }

    static func isPresetEnabled(_ genre: UnheardDiscoverGenre) -> Bool {
        enabledPresets.contains(genre)
    }

    static func setPresetEnabled(_ genre: UnheardDiscoverGenre, enabled: Bool) {
        var presets = enabledPresets
        if enabled {
            presets.insert(genre)
        } else {
            presets.remove(genre)
        }
        enabledPresets = presets
    }

    static func isLibraryGenreEnabled(_ name: String) -> Bool {
        enabledLibraryGenres.contains(name)
    }

    static func setLibraryGenreEnabled(_ name: String, enabled: Bool) {
        var genres = enabledLibraryGenres
        if enabled {
            genres.insert(name)
        } else {
            genres.remove(name)
        }
        enabledLibraryGenres = genres
    }

    static func libraryGenreFocusMixID(for name: String) -> String {
        "unheard-genre-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"
    }

    private static func migratedLegacyEnabledDefault() -> Bool {
        let legacyKeys = [
            "unheardDiscoverRB",
            "unheardDiscoverRap",
            "unheardDiscoverAlt"
        ]
        return legacyKeys.contains { UserDefaults.standard.object(forKey: $0) != nil }
    }

    private static func migratedLegacyPresets() -> Set<UnheardDiscoverGenre> {
        var presets = Set<UnheardDiscoverGenre>()
        if UserDefaults.standard.object(forKey: "unheardDiscoverRB") as? Bool ?? false {
            presets.insert(.rb)
        }
        if UserDefaults.standard.object(forKey: "unheardDiscoverRap") as? Bool ?? false {
            presets.insert(.rap)
        }
        if UserDefaults.standard.object(forKey: "unheardDiscoverAlt") as? Bool ?? false {
            presets.insert(.alt)
        }
        if !presets.isEmpty {
            enabledPresets = presets
        }
        return presets
    }
}

nonisolated func trackMatchesUnheardGenre(_ track: LibraryTrack, genre: UnheardDiscoverGenre) -> Bool {
    splitGenreTags(from: track.genre).contains { genre.matches(tag: $0) }
}
