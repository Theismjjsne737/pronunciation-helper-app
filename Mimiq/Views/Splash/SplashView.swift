import SwiftUI

struct SplashView: View {

    var onComplete: () -> Void

    @State private var logoScale: CGFloat = 0.4
    @State private var logoOpacity: Double = 0
    @State private var glowRadius: CGFloat = 0
    @State private var lettersVisible: [Bool] = Array(repeating: false, count: 5)
    @State private var taglineOpacity: Double = 0
    @State private var wavePhase: Double = 0
    @State private var waveAmplitudes: [CGFloat] = (0..<28).map { _ in CGFloat.random(in: 0.15...0.45) }
    @State private var screenOpacity: Double = 1

    private let letters: [String] = ["M", "I", "M", "I", "Q"]
    private let letterDelays: [Double] = [0.3, 0.45, 0.6, 0.75, 0.9]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    // Glow halo behind the M
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.indigo.opacity(0.35), .clear],
                                center: .center,
                                startRadius: 20,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .blur(radius: glowRadius)
                        .opacity(logoOpacity)

                    // M monogram
                    Text("M")
                        .font(.system(size: 100, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.60, green: 0.45, blue: 1.0),
                                    Color(red: 0.38, green: 0.27, blue: 0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(color: Color.indigo.opacity(0.6), radius: 20, x: 0, y: 8)
                }

                Spacer().frame(height: 28)

                // "IMIQ" letters staggered in beside the M
                HStack(spacing: 3) {
                    ForEach(1..<letters.count, id: \.self) { i in
                        Text(letters[i])
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.9))
                            .opacity(lettersVisible[i] ? 1 : 0)
                            .offset(y: lettersVisible[i] ? 0 : 12)
                    }
                }
                .tracking(8)

                Spacer().frame(height: 18)

                Text("your accent, perfected")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .tracking(2)
                    .opacity(taglineOpacity)

                Spacer().frame(height: 56)

                waveformBars
                    .frame(height: 48)
                    .padding(.horizontal, 40)
                    .opacity(taglineOpacity)

                Spacer()
            }
        }
        .opacity(screenOpacity)
        .onAppear { runSequence() }
    }

    // MARK: - Sub-views

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.04, blue: 0.14),
                Color(red: 0.08, green: 0.05, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var waveformBars: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<waveAmplitudes.count, id: \.self) { i in
                let phase = wavePhase + Double(i) * 0.35
                let factor = CGFloat(0.5 + 0.5 * sin(phase))
                let height = max(4, waveAmplitudes[i] * factor * 48)

                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.60, green: 0.45, blue: 1.0),
                                Color.indigo.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: height)
                    .animation(.easeInOut(duration: 0.12), value: height)
            }
        }
    }

    // MARK: - Animation sequence

    private func runSequence() {
        // Logo spring pop
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.15)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
            glowRadius = 40
        }

        // Letters stagger in
        for i in 1..<letters.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(letterDelays[i])) {
                lettersVisible[i] = true
            }
        }

        // Tagline + waveform fade in
        withAnimation(.easeIn(duration: 0.5).delay(1.1)) {
            taglineOpacity = 1.0
        }

        // Animate waveform bars at ~30 fps
        let waveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            wavePhase += 0.12
        }

        // Dismiss after 2.3 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            waveTimer.invalidate()
            withAnimation(.easeInOut(duration: 0.45)) {
                screenOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                onComplete()
            }
        }
    }
}

#Preview {
    SplashView(onComplete: {})
}
