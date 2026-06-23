import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case lyrics = "Lyrics"
    case integrations = "Integrations"
    case library = "Library"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .lyrics: return "textformat.alt"
        case .integrations: return "network"
        case .library: return "folder"
        }
    }

    var color: Color {
        switch self {
        case .general: return .gray
        case .lyrics: return .blue
        case .integrations: return .red
        case .library: return .purple
        }
    }
}
