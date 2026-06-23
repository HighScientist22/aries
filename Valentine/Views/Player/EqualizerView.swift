//
//  EqualizerView.swift
//  Aries
//

import SwiftUI

struct EqualizerView: View {
    @ObservedObject var engine: AudioEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Equalizer")
                    .font(.title3.weight(.semibold))
                Spacer()
                Toggle("", isOn: Binding(
                    get: { engine.equalizer.isEnabled },
                    set: { engine.setEqualizerEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            presetRow

            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(Equalizer.bandFrequencies.enumerated()), id: \.offset) { index, frequency in
                    BandSlider(
                        gain: Binding(
                            get: { engine.equalizer.gains[index] },
                            set: { engine.setEqualizerBand(index, gain: $0) }
                        ),
                        label: Equalizer.label(for: frequency)
                    )
                    .disabled(!engine.equalizer.isEnabled)
                }
            }
            .opacity(engine.equalizer.isEnabled ? 1 : 0.4)
            .animation(.easeInOut(duration: 0.2), value: engine.equalizer.isEnabled)
        }
        .padding(24)
        .frame(width: 460)
    }

    private var presetRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EqualizerPreset.presets) { preset in
                    let isActive = engine.equalizer.activePreset == preset.id
                    Button(preset.name) {
                        engine.applyEqualizerPreset(preset)
                    }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isActive ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.15))
                    .foregroundStyle(isActive ? Color.white : Color.primary)
                    .clipShape(Capsule())
                }
            }
            .padding(.vertical, 2)
        }
        .disabled(!engine.equalizer.isEnabled)
    }
}

private struct BandSlider: View {
    @Binding var gain: Float
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text(gain == 0 ? "0" : String(format: "%+.0f", gain))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

            Slider(value: $gain, in: Equalizer.gainRange, step: 1)
                .frame(width: 150)
                .rotationEffect(.degrees(-90))
                .frame(width: 28, height: 150)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
