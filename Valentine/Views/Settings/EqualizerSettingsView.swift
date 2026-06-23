import SwiftUI

struct EqualizerSettingsView: View {
    @State private var eq = Equalizer()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Equalizer")
                    .font(.title2.weight(.semibold))
                Spacer()
                Toggle("Enabled", isOn: $eq.isEnabled)
                    .labelsHidden()
            }

            HStack(spacing: 8) {
                ForEach(Array(Equalizer.bandFrequencies.enumerated()), id: \ .offset) { index, freq in
                    VStack(spacing: 8) {
                        Text(eq.gains[index] == 0 ? "0" : String(format: "%+.0f", eq.gains[index]))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)

                        Slider(value: Binding(get: {
                            Double(eq.gains[index])
                        }, set: { new in
                            eq.gains[index] = Float(new)
                            persist()
                        }), in: Double(Equalizer.gainRange.lowerBound)...Double(Equalizer.gainRange.upperBound), step: 1)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 28, height: 150)

                        Text(Equalizer.label(for: freq))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("Preset")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EqualizerPreset.presets) { preset in
                            let isActive = eq.activePreset == preset.id
                            Button(action: {
                                eq.gains = preset.gains
                                eq.activePreset = preset.id
                                persist()
                            }) {
                                Text(preset.name)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(isActive ? Color.accentColor.opacity(0.8) : Color.secondary.opacity(0.15))
                                    .foregroundStyle(isActive ? Color.white : Color.primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack {
                Text("Preamp")
                Slider(value: Binding(get: { Double(eq.preamp) }, set: { new in eq.preamp = Float(new); persist() }), in: Double(Equalizer.gainRange.lowerBound)...Double(Equalizer.gainRange.upperBound), step: 1)
            }

            Spacer()
        }
        .padding(20)
        .onAppear {
            eq.load()
        }
    }

    private func persist() {
        eq.save()
        // Writing to UserDefaults triggers didChangeNotification which
        // AudioEngine listens to — no extra notification required.
    }
}

struct EqualizerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        EqualizerSettingsView()
            .frame(width: 600, height: 480)
    }
}
