//
//  ScrollWheelHandler.swift
//  Aries
//

import SwiftUI
import AppKit

struct ScrollWheelHandler: NSViewRepresentable {
    var onHorizontalScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelView {
        let view = ScrollWheelView()
        view.onHorizontalScroll = onHorizontalScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelView, context: Context) {
        nsView.onHorizontalScroll = onHorizontalScroll
    }
}

final class ScrollWheelView: NSView {
    var onHorizontalScroll: ((CGFloat) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY
        if abs(deltaX) > abs(deltaY), abs(deltaX) > 1.5 {
            onHorizontalScroll?(deltaX)
        } else {
            super.scrollWheel(with: event)
        }
    }
}

extension View {
    func horizontalScrollToSkip(
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        threshold: CGFloat = 8
    ) -> some View {
        background {
            ScrollWheelHandler { delta in
                if delta > threshold {
                    onPrevious()
                } else if delta < -threshold {
                    onNext()
                }
            }
        }
    }
}
