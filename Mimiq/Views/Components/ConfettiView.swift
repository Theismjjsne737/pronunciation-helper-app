import SwiftUI

// MARK: - Confetti overlay (fired on high scores ≥ 90%)

struct ConfettiView: View {

    @State private var particles: [Particle] = []
    @State private var startTime: Date = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let colors: [Color] = [.indigo, .purple, .pink, .orange, .yellow, .green, .cyan, .red]

    var body: some View {
        if reduceMotion {
            // Skip animation for accessibility
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1/60)) { timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(startTime)
                    for p in particles {
                        draw(particle: p, elapsed: elapsed, in: context, size: size)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                startTime = Date()
                particles = (0..<120).map { _ in Particle(colors: colors) }
            }
        }
    }

    private func draw(particle p: Particle, elapsed: TimeInterval, in context: GraphicsContext, size: CGSize) {
        let t = min(elapsed / p.duration, 1.0)
        guard t < 1.0 else { return }

        let x = p.startX * size.width + p.hDrift * t * size.width
        let y = (p.startY * size.height) + p.speed * t * size.height
        let rotation = Angle.degrees(p.rotationStart + p.rotationSpeed * t * 360)
        let fade = t > 0.65 ? 1.0 - (t - 0.65) / 0.35 : 1.0

        var ctx = context
        ctx.opacity = fade
        ctx.translateBy(x: x, y: y)
        ctx.rotate(by: rotation)

        let rect = CGRect(x: -p.width / 2, y: -p.height / 2, width: p.width, height: p.height)
        ctx.fill(Path(roundedRect: rect, cornerRadius: p.width * 0.2), with: .color(p.color))
    }
}

// MARK: - Particle data

private struct Particle {
    let startX: CGFloat
    let startY: CGFloat
    let hDrift: CGFloat
    let speed: CGFloat
    let rotationStart: Double
    let rotationSpeed: Double
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let duration: Double

    init(colors: [Color]) {
        startX        = CGFloat.random(in: 0.05...0.95)
        startY        = CGFloat.random(in: -0.15...0.05)
        hDrift        = CGFloat.random(in: -0.15...0.15)
        speed         = CGFloat.random(in: 0.8...1.4)
        rotationStart = Double.random(in: 0...360)
        rotationSpeed = Double.random(in: 1...3) * (Bool.random() ? 1 : -1)
        width         = CGFloat.random(in: 6...12)
        height        = CGFloat.random(in: 10...18)
        color         = colors.randomElement()!
        duration      = Double.random(in: 1.8...3.2)
    }
}

// MARK: - Convenience modifier

extension View {
    /// Overlays confetti when `isActive` becomes true.
    func confetti(isActive: Binding<Bool>) -> some View {
        overlay {
            if isActive.wrappedValue {
                ConfettiView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                            isActive.wrappedValue = false
                        }
                    }
            }
        }
    }
}
