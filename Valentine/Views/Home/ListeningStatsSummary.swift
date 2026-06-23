//
//  ListeningStatsSummary.swift
//  Aries
//

import SwiftUI

struct ListeningStatsSummary: View {
    let listenSeconds: TimeInterval
    let playCount: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 16) {
            summaryTile(icon: "play.circle.fill", label: "Plays", value: "\(playCount)")
            summaryTile(icon: "clock.fill", label: "Listen Time", value: formatListenDuration(listenSeconds))
            summaryTile(icon: "waveform", label: "Avg. Track", value: formatListenDuration(averageTrackLength))
        }
    }

    private var averageTrackLength: TimeInterval {
        guard playCount > 0 else { return 0 }
        return listenSeconds / Double(playCount)
    }

    private func summaryTile(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .light, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func formatListenDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "0m"
    }
}
