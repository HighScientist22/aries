//
//  CompactWaveformView.swift
//  Aries
//

import SwiftUI

struct CompactWaveformView: View {
    let points: [Float]
    var progress: CGFloat = 0
    var height: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let bars = resampledPoints(for: size.width)
                guard !bars.isEmpty else { return }

                let barWidth = max(1, size.width / CGFloat(bars.count))
                let gap = barWidth * 0.25
                let drawWidth = max(0.5, barWidth - gap)
                let midY = size.height / 2
                let splitX = size.width * min(max(progress, 0), 1)

                for (index, value) in bars.enumerated() {
                    let x = CGFloat(index) * barWidth
                    let barHeight = max(2, CGFloat(value) * size.height * 0.9)
                    let rect = CGRect(
                        x: x + gap / 2,
                        y: midY - barHeight / 2,
                        width: drawWidth,
                        height: barHeight
                    )
                    let played = x + drawWidth / 2 <= splitX
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 1),
                        with: .color(.primary.opacity(played ? 0.85 : 0.25))
                    )
                }
            }
        }
        .frame(height: height)
    }

    private func resampledPoints(for width: CGFloat) -> [CGFloat] {
        let targetCount = max(24, Int(width / 3))
        guard !points.isEmpty else {
            return Array(repeating: 0.12, count: targetCount)
        }
        guard points.count > 1 else {
            return Array(repeating: CGFloat(points[0]), count: targetCount)
        }
        return (0..<targetCount).map { index in
            let position = CGFloat(index) / CGFloat(max(targetCount - 1, 1)) * CGFloat(points.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, points.count - 1)
            let fraction = position - CGFloat(lower)
            let value = CGFloat(points[lower]) * (1 - fraction) + CGFloat(points[upper]) * fraction
            return max(0.08, value)
        }
    }
}
