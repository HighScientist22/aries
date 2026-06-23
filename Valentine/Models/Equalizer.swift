//
//  Equalizer.swift
//  Aries
//

import Foundation

struct EqualizerPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let gains: [Float]

    static let presets: [EqualizerPreset] = [
        EqualizerPreset(id: "flat", name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        EqualizerPreset(id: "bass", name: "Bass Boost", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        EqualizerPreset(id: "treble", name: "Treble Boost", gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]),
        EqualizerPreset(id: "vocal", name: "Vocal", gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]),
        EqualizerPreset(id: "loudness", name: "Loudness", gains: [5, 3, 0, -1, -2, -2, 0, 2, 4, 5]),
        EqualizerPreset(id: "acoustic", name: "Acoustic", gains: [4, 4, 2, 0, 1, 1, 3, 3, 2, 1])
    ]
}

struct Equalizer {
    static let bandFrequencies: [Float] = [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    static let gainRange: ClosedRange<Float> = -12...12

    var isEnabled: Bool = false
    var preamp: Float = 0
    var gains: [Float] = Array(repeating: 0, count: bandFrequencies.count)
    var activePreset: String? = "flat"

    private static let gainsKey = "equalizerGains"
    private static let enabledKey = "equalizerEnabled"
    private static let preampKey = "equalizerPreamp"
    private static let presetKey = "equalizerPreset"

    mutating func load() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        preamp = defaults.object(forKey: Self.preampKey) as? Float ?? 0
        activePreset = defaults.string(forKey: Self.presetKey)
        if let stored = defaults.array(forKey: Self.gainsKey) as? [Double],
           stored.count == Self.bandFrequencies.count {
            gains = stored.map { Float($0) }
        }
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: Self.enabledKey)
        defaults.set(preamp, forKey: Self.preampKey)
        defaults.set(gains.map { Double($0) }, forKey: Self.gainsKey)
        if let activePreset {
            defaults.set(activePreset, forKey: Self.presetKey)
        } else {
            defaults.removeObject(forKey: Self.presetKey)
        }
    }

    static func label(for frequency: Float) -> String {
        frequency >= 1_000 ? "\(Int(frequency / 1_000))k" : "\(Int(frequency))"
    }
}
