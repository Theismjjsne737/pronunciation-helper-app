import SwiftUI

struct SplashView: View {

    var onComplete: () -> Void

    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.7
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkOffset: CGFloat = 12
    @State private var taglineOpacity: Double = 0
    @State private var wavePhase: Double = 0
    @State private var screenOpacity: Double = 1

    // Heights from icon.html (normalised to 0–1, original max = 240)
    private let barHeights: [CGFloat] = [
        52, 88, 136, 104, 188, 220, 172, 208,
        240, 196, 224, 184, 152, 112, 76, 48
    ].map { $0 / 240.0 }

    private let violet   = Color(red: 0.48, green: 0.33, blue: 1.0)
    private let lavender = Color(red: 0.835, green: 0.804, blue: 1.0)

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                // Waveform logo mark
                ZStack {
                    // Glow halo
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [violet.opacity(0.40), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 80
                            )
                        )
                        .frame(width: 180, height: 100)
                        .blur(radius: 24)
                        .opacity(logoOpacity)

                    waveformBars
                        .frame(width: 160, height: 64)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                Spacer().frame(height: 28)

                // "Mimiq" wordmark
                Text("Mimiq")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, lavender],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(1)
                    .opacity(wordmarkOpacity)
                    .offset(y: wordmarkOffset)

                Spacer().frame(height: 10)

                // Tagline
                Text("PRONUNCIATION COACH")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .foregroundStyle(lavender.opacity(0.52))
                    .tracking(3.2)
                    .opacity(taglineOpacity)

                Spacer().frame(height: 72)
            }
        }
        .opacity(screenOpacity)
        .onAppear { runSequence() }
    }

    // MARK: - Waveform bars

    private var waveformBars: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(barHeights.indices, id: \.self) { i in
                let phase = wavePhase + Double(i) * 0.38
                let factor = CGFloat(0.72 + 0.28 * sin(phase))
                let h = max(4, barHeights[i] * factor * 64)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [lavender, violet, violet.opacity(0.35)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: h)
                    .animation(.easeInOut(duration: 0.14), value: h)
            }
        }
    }

    // MARK: - Background

    private var background: some View {
        Color(red: 0.027, green: 0.020, blue: 0.059)
            .ignoresSafeArea()
    }

    // MARK: - Animation sequence

    private func runSequence() {
        // Logo waveform springs in
        withAnimation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }

        // Wordmark slides up
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.55)) {
            wordmarkOpacity = 1.0
            wordmarkOffset = 0
        }

        // Tagline fades in
        withAnimation(.easeIn(duration: 0.4).delay(0.85)) {
            taglineOpacity = 1.0
        }

        // Animate waveform bars at ~24 fps
        let waveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { _ in
            wavePhase += 0.10
        }

        // Dismiss after 2.4 s total
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            waveTimer.invalidate()
            withAnimation(.easeInOut(duration: 0.40)) {
                screenOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}
