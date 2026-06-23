//
//  ArtworkCache.swift
//  Aries
//

import SwiftUI
import AppKit

// Loads cached album-art JPEGs off the main thread and keeps decoded images in
// an NSCache so scrolling the library doesn't re-read/re-decode from disk.
actor ArtworkLoader {
    static let shared = ArtworkLoader()
    private let cache = NSCache<NSURL, NSImage>()

    func image(at url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
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
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await ArtworkLoader.shared.image(at: url)
        }
    }
}
