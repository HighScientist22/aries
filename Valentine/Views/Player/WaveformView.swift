import SwiftUI

struct WaveformView: View {
    @ObservedObject var engine: AudioEngine

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                Canvas { context, size in
                    drawWaveform(context: &context, size: size)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            seek(to: value.location.x, in: geometry.size.width)
                        }
                )
            }

            HStack {
                Text(formatTime(engine.currentTime))
                Spacer()
                Text("-\(formatTime(max(0, engine.duration - engine.currentTime)))")
            }
            .font(.caption)
            .foregroundColor(.primary.opacity(0.8))
            .monospacedDigit()
        }
    }

    private var currentProgress: CGFloat {
        guard engine.duration > 0 else { return 0 }
        return CGFloat(engine.currentTime / engine.duration)
    }

    private func drawWaveform(context: inout GraphicsContext, size: CGSize) {
        let points = engine.waveformPoints
        let barCount = max(points.count, 50)
        let spacing: CGFloat = 2
        let barWidth = max(2, (size.width - CGFloat(barCount - 1) * spacing) / CGFloat(barCount))
        let progress = currentProgress

        for index in 0..<barCount {
            let amplitude: CGFloat
            if points.isEmpty {
                amplitude = 0.15
            } else {
                amplitude = max(0.05, CGFloat(points[index]))
            }

            let barProgress = CGFloat(index) / CGFloat(barCount)
            let isPlayed = barProgress <= progress
            let height = max(4, amplitude * size.height)
            let x = CGFloat(index) * (barWidth + spacing)
            let rect = CGRect(x: x, y: size.height - height, width: barWidth, height: height)
            let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)
            context.fill(
                path,
                with: .color(isPlayed ? .primary : .primary.opacity(points.isEmpty ? 0.2 : 0.3))
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
