//
//  AlbumTheme.swift
//  Aries
//

import SwiftUI
import AppKit
import Combine

// Derives a UI theme (accent + background gradient) from album artwork by
// downsampling the image and picking a vivid dominant color. Updated by the
// engine whenever the current track changes.
@MainActor
final class AlbumTheme: ObservableObject {
    @Published var accent: Color = .accentColor
    @Published var background: [Color] = [Color(NSColor.windowBackgroundColor)]

    private var cache: [String: (accent: NSColor, background: [NSColor])] = [:]

    func update(from image: NSImage?, key: String?) {
        guard let image else {
            reset()
            return
        }
        if let key, let cached = cache[key] {
            apply(cached.accent, cached.background)
            return
        }

        Task.detached(priority: .utility) {
            let colors = Self.extract(from: image)
            await MainActor.run {
                if let key { self.cache[key] = colors }
                self.apply(colors.accent, colors.background)
            }
        }
    }

    func reset() {
        withAnimation(.easeInOut(duration: 0.6)) {
            accent = .accentColor
            background = [Color(NSColor.windowBackgroundColor)]
        }
    }

    private func apply(_ accent: NSColor, _ background: [NSColor]) {
        withAnimation(.easeInOut(duration: 0.8)) {
            self.accent = Color(accent)
            self.background = background.map(Color.init)
        }
    }

    // Downsample to a small grid, bucket colors, and pick the most saturated
    // populous bucket as the accent plus a darkened pair for the background.
    nonisolated private static func extract(from image: NSImage) -> (accent: NSColor, background: [NSColor]) {
        let side = 48
        guard let bitmap = downsample(image, side: side) else {
            return (.controlAccentColor, [Color(NSColor.windowBackgroundColor)].map { NSColor($0) })
        }

        var buckets: [Int: (count: Int, r: CGFloat, g: CGFloat, b: CGFloat)] = [:]
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                let r = color.redComponent, g = color.greenComponent, b = color.blueComponent
                // Skip near-black and near-white so the accent has character.
                let maxC = max(r, g, b), minC = min(r, g, b)
                let brightness = maxC
                let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
                if brightness < 0.15 || (saturation < 0.12 && brightness > 0.9) { continue }
                let key = (Int(r * 7) << 6) | (Int(g * 7) << 3) | Int(b * 7)
                var bucket = buckets[key] ?? (0, 0, 0, 0)
                bucket.count += 1
                bucket.r += r; bucket.g += g; bucket.b += b
                buckets[key] = bucket
            }
        }

        guard let best = buckets.values.max(by: { lhs, rhs in
            score(lhs) < score(rhs)
        }), best.count > 0 else {
            return (.controlAccentColor, [NSColor.windowBackgroundColor])
        }

        let accent = NSColor(
            red: best.r / CGFloat(best.count),
            green: best.g / CGFloat(best.count),
            blue: best.b / CGFloat(best.count),
            alpha: 1
        )

        let top = accent.usingColorSpace(.deviceRGB) ?? accent
        let bottom = top.blended(withFraction: 0.6, of: .black) ?? .black
        let darkTop = top.blended(withFraction: 0.35, of: .black) ?? top
        return (accent, [darkTop, bottom])
    }

    // Prefer buckets that are both populous and saturated.
    nonisolated private static func score(_ bucket: (count: Int, r: CGFloat, g: CGFloat, b: CGFloat)) -> CGFloat {
        let n = CGFloat(bucket.count)
        let r = bucket.r / n, g = bucket.g / n, b = bucket.b / n
        let maxC = max(r, g, b), minC = min(r, g, b)
        let saturation = maxC == 0 ? 0 : (maxC - minC) / maxC
        return n * (0.4 + saturation)
    }

    nonisolated private static func downsample(_ image: NSImage, side: Int) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
}
