//
//  DetailBackBar.swift
//  Aries
//

import SwiftUI

struct DetailBackBar<Trailing: View>: View {
    let title: String
    let accent: Color
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        accent: Color,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.accent = accent
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(accent)
            .keyboardShortcut(.escape, modifiers: [])

            Text(title)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(.secondary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.85))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.25)
        }
    }
}

struct FavoriteHeartButton: View {
    let isFavorite: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.body.weight(.medium))
                .foregroundStyle(isFavorite ? accent : .secondary)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}
