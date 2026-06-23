//
//  SpeedControlView.swift
//  Aries
//

import SwiftUI

struct SpeedControlView: View {
    @ObservedObject var engine: AudioEngine

    private let presets: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Playback Speed")
                    .font(.headline)
                Spacer()
                Text(String(format: "%.2f×", engine.playbackRate))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $engine.playbackRate, in: 0.5...2.0, step: 0.05)

            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { rate in
                    Button(rate == 1.0 ? "1×" : String(format: "%.2g×", rate)) {
                        engine.playbackRate = rate
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(abs(engine.playbackRate - rate) < 0.001 ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.15))
                    .foregroundStyle(abs(engine.playbackRate - rate) < 0.001 ? Color.white : Color.primary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .frame(width: 300)
    }
}
