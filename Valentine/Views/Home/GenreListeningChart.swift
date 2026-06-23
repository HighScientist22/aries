//
//  GenreListeningChart.swift
//  Aries
//

import SwiftUI

struct GenreListeningChart: View {
    let stats: [GenreListeningStat]
    let accent: Color
    var maxBars: Int = 8

    private var topStats: [GenreListeningStat] {
        Array(stats.prefix(maxBars))
    }

    private var maxSeconds: TimeInterval {
        max(topStats.map(\.listenSeconds).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Genres Listened")
                        .font(.title3.weight(.semibold))
                    Text("Based on your play history in Aries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !stats.isEmpty {
                    Text("\(stats.count) genres")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if topStats.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary.opacity(0.6))
                    Text("Play some music to see your genre breakdown.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(topStats) { stat in
                        genreBar(stat)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.5))
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func genreBar(_ stat: GenreListeningStat) -> some View {
        HStack(spacing: 12) {
            Text(stat.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .frame(width: 96, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geometry.size.width * CGFloat(stat.listenSeconds / maxSeconds)))
                }
            }
            .frame(height: 10)

            VStack(alignment: .trailing, spacing: 1) {
                Text(formatListenTime(stat.listenSeconds))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("\(stat.playCount) plays")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 58, alignment: .trailing)
        }
    }

    private func formatListenTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(max(1, minutes))m"
    }
}
