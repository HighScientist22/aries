import SwiftUI

enum WaveformTimeStyle {
    case inlineTotal
    case hidden
}

struct WaveformView: View {
    @ObservedObject var engine: AudioEngine
    var timeStyle: WaveformTimeStyle = .inlineTotal
    var interactive: Bool = true
    var playedOpacity: Double = 0.92
    var unplayedOpacity: Double = 0.28

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if timeStyle == .inlineTotal {
                Text(formatTime(engine.currentTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .trailing)
            }

            GeometryReader { geometry in
                Canvas { context, size in
                    drawRoonWaveform(context: &context, size: size)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    interactive
                        ? DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                seek(to: value.location.x, in: geometry.size.width)
                            }
                        : nil
                )
            }

            if timeStyle == .inlineTotal {
                Text(formatTime(engine.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 38, alignment: .leading)
            }
        }
    }

    private var currentProgress: CGFloat {
        guard engine.duration > 0 else { return 0 }
        return CGFloat(engine.currentTime / engine.duration)
    }

    private func resampledPoints(for width: CGFloat) -> [CGFloat] {
        let source = engine.waveformPoints
        let targetCount = max(48, Int(width / 2))
        guard !source.isEmpty else {
            return Array(repeating: 0.1, count: targetCount)
        }
        guard source.count > 1 else {
            return Array(repeating: CGFloat(source[0]), count: targetCount)
        }

        return (0..<targetCount).map { index in
            let position = CGFloat(index) / CGFloat(targetCount - 1) * CGFloat(source.count - 1)
            let lower = Int(position)
            let upper = min(lower + 1, source.count - 1)
            let fraction = position - CGFloat(lower)
            let lowerValue = CGFloat(source[lower])
            let upperValue = CGFloat(source[upper])
            return lowerValue + (upperValue - lowerValue) * fraction
        }
    }

    private func drawRoonWaveform(context: inout GraphicsContext, size: CGSize) {
        let barWidth: CGFloat = 1
        let barGap: CGFloat = 1
        let pitch = barWidth + barGap
        let barCount = max(1, Int((size.width + barGap) / pitch))
        let points = resampledPoints(for: size.width)
        let centerY = size.height / 2
        let maxHalfHeight = size.height * 0.44
        let progress = currentProgress
        let playedBoundaryX = progress * size.width

        for index in 0..<barCount {
            let sampleIndex = min(points.count - 1, Int(CGFloat(index) / CGFloat(max(barCount - 1, 1)) * CGFloat(points.count - 1)))
            let amplitude = max(0.05, points[sampleIndex]) * maxHalfHeight
            let x = CGFloat(index) * pitch + barWidth / 2
            let isPlayed = x <= playedBoundaryX

            var bar = Path()
            bar.move(to: CGPoint(x: x, y: centerY - amplitude))
            bar.addLine(to: CGPoint(x: x, y: centerY + amplitude))

            context.stroke(
                bar,
                with: .color(.primary.opacity(isPlayed ? playedOpacity : unplayedOpacity)),
                lineWidth: barWidth
            )
        }
    }

    private func seek(to xOffset: CGFloat, in width: CGFloat) {
        let percentage = max(0, min(1, xOffset / width))
        let targetTime = TimeInterval(percentage) * engine.duration
        engine.seek(to: targetTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
