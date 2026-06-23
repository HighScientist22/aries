import Foundation
import AVFoundation
import SwiftUI

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval
    let text: String
}

struct Track: Identifiable, Hashable {
    let id: UUID
    let url: URL
    var title: String
    var artist: String
    var album: String?
    var albumArt: Image?
    var nsImage: NSImage?
    var duration: TimeInterval
    var lyrics: [LyricLine]?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var discNumber: Int?

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "Unknown Artist"
        self.album = nil
        self.albumArt = nil
        self.nsImage = nil
        self.duration = 0
        self.lyrics = nil
        self.genre = nil
        self.year = nil
        self.trackNumber = nil
        self.discNumber = nil
    }
    
    mutating func loadMetadata() async {
        let asset = AVURLAsset(url: url)
        
        do {
            self.duration = try await asset.load(.duration).seconds
            
            let formats = try await asset.load(.availableMetadataFormats)
            var foundLyricsText: String? = nil
            
            for format in formats {
                let metadata = try await asset.loadMetadata(for: format)
                for item in metadata {
                    if item.identifier == .iTunesMetadataLyrics || 
                       item.identifier?.rawValue == "id3/USLT" ||
                       item.identifier?.rawValue == "id3/SYLT" ||
                       item.key as? String == "USLT" ||
                       item.key as? String == "SYLT" {
                        if let value = try? await item.load(.stringValue) {
                            foundLyricsText = value
                        }
                    }
                    
                    guard let commonKey = item.commonKey?.rawValue else { continue }
                    
                    switch commonKey {
                    case AVMetadataKey.commonKeyTitle.rawValue:
                        if let value = try await item.load(.stringValue) {
                            self.title = value
                        }
                    case AVMetadataKey.commonKeyArtist.rawValue:
                        if let value = try await item.load(.stringValue) {
                            self.artist = value
                        }
                    case AVMetadataKey.commonKeyAlbumName.rawValue:
                        if let value = try await item.load(.stringValue) {
                            self.album = value
                        }
                    case AVMetadataKey.commonKeyArtwork.rawValue:
                        if let value = try await item.load(.dataValue),
                           let image = NSImage(data: value) {
                            self.nsImage = image
                            self.albumArt = Image(nsImage: image)
                        }
                    case AVMetadataKey.commonKeyType.rawValue:
                        if let value = try await item.load(.stringValue) {
                            self.genre = value
                        }
                    case AVMetadataKey.commonKeyCreationDate.rawValue:
                        if let value = try await item.load(.stringValue),
                           let parsed = Int(value.prefix(4)) {
                            self.year = parsed
                        }
                    default:
                        if let identifier = item.identifier?.rawValue {
                            if identifier.contains("trackNumber") || identifier.hasSuffix("/trkn") {
                                self.trackNumber = await Self.parseIntMetadata(item)
                            } else if identifier.contains("discNumber") || identifier.hasSuffix("/disk") {
                                self.discNumber = await Self.parseIntMetadata(item)
                            }
                        }
                        break
                    }
                }
            }
            
            if let lyricsText = foundLyricsText {
                self.lyrics = Self.parseLyricsText(lyricsText, duration: duration)
            }

        } catch {
            print("Failed to load metadata for \(url): \(error)")
        }
    }

    mutating func updateLyrics(from text: String) {
        self.lyrics = Self.parseLyricsText(text, duration: duration)
    }

    private static func parseIntMetadata(_ item: AVMetadataItem) async -> Int? {
        if let number = try? await item.load(.numberValue) {
            return number.intValue
        }
        if let string = try? await item.load(.stringValue), let value = Int(string) {
            return value
        }
        return nil
    }

    static func parseLyricsText(_ text: String, duration: TimeInterval) -> [LyricLine]? {
        if let synced = parseLRC(text), !synced.isEmpty { return synced }

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        if duration > 0, lines.count > 1 {
            let spacing = duration / Double(lines.count)
            return lines.enumerated().map { index, line in
                LyricLine(time: spacing * Double(index), text: line)
            }
        }

        return lines.map { LyricLine(time: 0, text: $0) }
    }

    private static func parseLRC(_ text: String) -> [LyricLine]? {
        var lines: [LyricLine] = []
        let pattern = "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        let stringLines = text.components(separatedBy: .newlines)
        for line in stringLines {
            let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
            if let match = regex.firstMatch(in: line, options: [], range: nsRange) {
                if let minRange = Range(match.range(at: 1), in: line),
                   let secRange = Range(match.range(at: 2), in: line),
                   let fracRange = Range(match.range(at: 3), in: line),
                   let textRange = Range(match.range(at: 4), in: line) {
                    
                    let min = Double(line[minRange]) ?? 0
                    let sec = Double(line[secRange]) ?? 0
                    let fracString = String(line[fracRange])
                    let frac = (Double(fracString) ?? 0) / pow(10.0, Double(fracString.count))
                    
                    let time = (min * 60) + sec + frac
                    let text = String(line[textRange]).trimmingCharacters(in: .whitespaces)
                    
                    lines.append(LyricLine(time: time, text: text))
                }
            }
        }
        
        return lines.isEmpty ? nil : lines.sorted(by: { $0.time < $1.time })
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}
