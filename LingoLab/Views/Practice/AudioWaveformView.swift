import SwiftUI

/// Animated bar waveform. Pass live `samples` (0–1) from AudioRecordingService.
struct AudioWaveformView: View {

    let samples: [Float]
    var barColor: Color = .indigo
    var idleColor: Color = Color(.systemGray5)
    var isActive: Bool = true

    // Geometric constants
    private let barSpacing: CGFloat = 3
    private let cornerRadius: CGFloat = 3
    private let minBarHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let barCount = samples.count
            let totalSpacing = barSpacing * CGFloat(barCount - 1)
            let barWidth = max(2, (geo.size.width - totalSpacing) / CGFloat(barCount))
            let maxBarHeight = geo.size.height

            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(samples.indices, id: \.self) { i in
                    let height = isActive
                        ? max(minBarHeight, CGFloat(samples[i]) * maxBarHeight)
                        : minBarHeight

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(isActive && samples[i] > 0.05 ? barColor : idleColor)
                        .frame(width: barWidth, height: height)
                        .animation(.easeInOut(duration: 0.05), value: samples[i])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

/// Static waveform for playback visualisation (mirrors the recorded sample array).
struct StaticWaveformView: View {

    let samples: [Float]
    var color: Color = .indigo.opacity(0.6)

    var body: some View {
        GeometryReader { geo in
            let count = samples.count
            let spacing: CGFloat = 2
            let barWidth = max(1, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            let mid = geo.size.height / 2

            Canvas { ctx, size in
                for (i, sample) in samples.enumerated() {
                    let x = (barWidth + spacing) * CGFloat(i)
                    let halfH = max(2, CGFloat(sample) * mid)
                    let rect = CGRect(x: x, y: mid - halfH, width: barWidth, height: halfH * 2)
                    let path = Path(roundedRect: rect, cornerRadius: 2)
                    ctx.fill(path, with: .color(color))
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        AudioWaveformView(
            samples: (0..<50).map { _ in Float.random(in: 0...1) },
            isActive: true
        )
        .frame(height: 80)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        StaticWaveformView(
            samples: (0..<50).map { _ in Float.random(in: 0...1) }
        )
        .frame(height: 60)
        .padding()
    }
    .padding()
    .background(Color(.secondarySystemBackground))
}
