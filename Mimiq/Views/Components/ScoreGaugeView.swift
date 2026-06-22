import SwiftUI

/// Compact arc gauge — suitable for list rows or dashboards.
struct ScoreGaugeView: View {

    let score: Double       // 0.0 – 1.0
    var size: CGFloat = 44

    @State private var animate = false

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .rotationEffect(.degrees(90))

            // Fill
            Circle()
                .trim(from: 0.15, to: animate ? 0.15 + 0.7 * score : 0.15)
                .stroke(
                    gaugeColor.gradient,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .animation(.easeOut(duration: 0.7), value: animate)

            // Label
            Text("\(Int(score * 100))")
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(gaugeColor)
        }
        .frame(width: size, height: size)
        .onAppear { animate = true }
    }

    private var strokeWidth: CGFloat { size * 0.12 }

    private var gaugeColor: Color {
        switch score {
        case 0.9...: return .green
        case 0.75..<0.9: return .blue
        case 0.55..<0.75: return .orange
        default: return .red
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        ScoreGaugeView(score: 0.95, size: 60)
        ScoreGaugeView(score: 0.80, size: 60)
        ScoreGaugeView(score: 0.60, size: 60)
        ScoreGaugeView(score: 0.30, size: 60)
    }
    .padding()
}
