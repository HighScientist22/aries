//
//  AudioFormatInfo.swift
//  Aries
//

import Foundation
import AVFoundation

nonisolated struct AudioFormatInfo: Codable, Equatable, Sendable {
    let codec: String
    let sampleRate: Int
    let bitDepth: Int?
    let channels: Int

    var displayString: String {
        var parts = [codec]
        let kHz = Double(sampleRate) / 1000.0
        if kHz.truncatingRemainder(dividingBy: 1) == 0 {
            parts.append("\(Int(kHz)) kHz")
        } else {
            parts.append(String(format: "%.1f kHz", kHz))
        }
        if let bitDepth {
            parts.append("\(bitDepth)-bit")
        }
        parts.append(channels == 1 ? "mono" : channels == 2 ? "stereo" : "\(channels)ch")
        return parts.joined(separator: " · ")
    }

    static func inspect(url: URL) -> AudioFormatInfo? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        return AudioFormatInfo(
            codec: codecLabel(for: url),
            sampleRate: Int(format.sampleRate.rounded()),
            bitDepth: bitDepth(for: format, url: url),
            channels: Int(format.channelCount)
        )
    }

    private static func codecLabel(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "flac": return "FLAC"
        case "alac": return "ALAC"
        case "m4a": return "AAC"
        case "mp3": return "MP3"
        case "aac": return "AAC"
        case "wav": return "WAV"
        case "aiff", "aif": return "AIFF"
        case "ogg": return "OGG"
        case "opus": return "OPUS"
        default: return url.pathExtension.uppercased()
        }
    }

    private static func bitDepth(for format: AVAudioFormat, url: URL) -> Int? {
        switch format.commonFormat {
        case .pcmFormatInt16: return 16
        case .pcmFormatInt32: return 32
        case .pcmFormatFloat32, .pcmFormatFloat64:
            if url.pathExtension.lowercased() == "flac" { return 24 }
            return nil
        default:
            return nil
        }
    }
}
