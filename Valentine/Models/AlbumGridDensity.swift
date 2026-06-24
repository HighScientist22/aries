//
//  AlbumGridDensity.swift
//  Aries
//

import Foundation

enum AlbumGridDensity: Int, CaseIterable, Identifiable {
    case compact = 0
    case comfortable = 1
    case large = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .compact: return "Compact"
        case .comfortable: return "Comfortable"
        case .large: return "Large"
        }
    }

    var tileSize: CGFloat {
        switch self {
        case .compact: return 120
        case .comfortable: return 148
        case .large: return 184
        }
    }

    var gridMinimum: CGFloat { tileSize }
    var gridMaximum: CGFloat { tileSize + 36 }

    var rowHeight: CGFloat { tileSize + 70 }

    static var current: AlbumGridDensity {
        let raw = UserDefaults.standard.object(forKey: "albumGridDensity") as? Int ?? 1
        return AlbumGridDensity(rawValue: raw) ?? .comfortable
    }
}
