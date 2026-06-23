//
//  ArtworkCache.swift
//  Aries
//

import SwiftUI
import AppKit
import ImageIO

// Loads cached album-art JPEGs off the main thread and keeps decoded images in
// an NSCache so scrolling the library doesn't re-read/re-decode from disk.
actor ArtworkLoader {
    static let shared = ArtworkLoader()
    private let cache = NSCache<NSURL, NSImage>()

    init() {
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
    }

    func image(at url: URL, maxPixelSize: CGFloat? = nil) async -> NSImage? {
        let cacheKey = cacheNSURL(url, maxPixelSize: maxPixelSize)
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let loaded: NSImage?
        if url.isFileURL {
            if let maxPixelSize {
                loaded = Self.thumbnail(fromFile: url, maxPixelSize: maxPixelSize)
            } else {
                loaded = NSImage(contentsOf: url)
            }
        } else if let maxPixelSize, let image = Self.thumbnail(fromRemote: url, maxPixelSize: maxPixelSize) {
            loaded = image
        } else {
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = NSImage(data: data) else { return nil }
            loaded = image
        }

        if let loaded {
            let cost = Int(loaded.size.width * loaded.size.height * 4)
            cache.setObject(loaded, forKey: cacheKey, cost: cost)
        }
        return loaded
    }

    private func cacheNSURL(_ url: URL, maxPixelSize: CGFloat?) -> NSURL {
        guard let maxPixelSize else { return url as NSURL }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "px", value: String(Int(maxPixelSize)))]
        return (components?.url ?? url) as NSURL
    }

    private static func thumbnail(fromFile url: URL, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return NSImage(contentsOf: url)
        }
        return thumbnail(from: source, maxPixelSize: maxPixelSize)
    }

    private static func thumbnail(fromRemote url: URL, maxPixelSize: CGFloat) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return thumbnail(from: source, maxPixelSize: maxPixelSize)
    }

    private static func thumbnail(from source: CGImageSource, maxPixelSize: CGFloat) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
}

// Async artwork view: shows a placeholder until the image is loaded off-thread.
struct CachedArtwork: View {
    let url: URL?
    let size: CGFloat
    var rounded: Bool = false

    @State private var image: NSImage?

    private var shape: AnyShape {
        rounded ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: rounded ? "person.fill" : "music.note")
                            .font(.system(size: size * 0.3))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        .task(id: taskKey) {
            guard let url else { image = nil; return }
            let pixelSize = size * (NSScreen.main?.backingScaleFactor ?? 2)
            image = await ArtworkLoader.shared.image(at: url, maxPixelSize: pixelSize)
        }
    }

    private var taskKey: String {
        guard let url else { return "nil" }
        return "\(url.absoluteString)|\(size)|\(rounded)"
    }
}
