//
//  TopListeningList.swift
//  Aries
//

import SwiftUI

struct TopListeningList: View {
    let title: String
    let stats: [NamedListeningStat]
    let accent: Color
    var maxRows: Int = 6

    private var topStats: [NamedListeningStat] {
        Array(stats.prefix(maxRows))
    }

    private var maxSeconds: TimeInterval {
        max(topStats.map(\.listenSeconds).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            if topStats.isEmpty {
                Text("No listening data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(topStats) { stat in
                        row(stat)
                    }
                }
            }
        }
    }

    private func row(_ stat: NamedListeningStat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let subtitle = stat.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 120, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    Capsule()
                        .fill(accent.opacity(0.8))
                        .frame(width: max(8, geometry.size.width * CGFloat(stat.listenSeconds / maxSeconds)))
                }
            }
            .frame(height: 8)

            Text(formatListenTime(stat.listenSeconds))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }

    private func formatListenTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(1, minutes))m"
    }
}
