//
//  DetailBackBar.swift
//  Aries
//

import SwiftUI

struct DetailBackBar: View {
    let title: String
    let accent: Color
    let onBack: () -> Void

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
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial.opacity(0.85))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.25)
        }
    }
}
