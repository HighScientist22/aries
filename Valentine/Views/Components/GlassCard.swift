//
//  GlassCard.swift
//  Aries
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = DesignConstants.CornerRadius.medium
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.45))
                    .ariesGlass(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
            )
    }
}
