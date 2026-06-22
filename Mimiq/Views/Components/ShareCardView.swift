import SwiftUI
import UIKit

/// Branded result card rendered to PNG and shared via UIActivityViewController.
struct ShareCardView: View {

    let word: String
    let score: Double      // 0.0–1.0
    let transcription: String

    var body: some View {
        ZStack {
            Color(red: 0.027, green: 0.020, blue: 0.059)

            Circle()
                .fill(accentColor.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(y: -20)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text("Mimiq")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("pronunciation coach")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)

                Spacer()

                Text(word)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 28)

                Spacer().frame(height: 24)

                ZStack {
                    Circle()
                        .trim(from: 0.15, to: 0.85)
                        .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(90))

                    Circle()
                        .trim(from: 0.15, to: 0.15 + 0.7 * score)
                        .stroke(accentColor.gradient, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(90))

                    VStack(spacing: 2) {
                        Text("\(Int(score * 100))")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("/ 100")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(width: 160, height: 160)

                Spacer().frame(height: 20)

                Text(scoreLabel)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accentColor)

                if !transcription.isEmpty {
                    Text("heard: \"\(transcription)\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.top, 6)
                }

                Spacer()

                Text("Can you beat me? 🎯  mimiq.app")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 360, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var accentColor: Color {
        switch score {
        case 0.9...:      return .green
        case 0.75..<0.9:  return Color(red: 0.48, green: 0.33, blue: 1.0)
        case 0.55..<0.75: return .orange
        default:          return .red
        }
    }

    private var scoreLabel: String {
        switch score {
        case 0.9...:      return "Native-level 🎉"
        case 0.75..<0.9:  return "Excellent 🔥"
        case 0.55..<0.75: return "Good effort 💪"
        default:          return "Keep going ✨"
        }
    }
}

// MARK: - Share helper

@MainActor
func shareScoreCard(word: String, score: Double, transcription: String) {
    let card = ShareCardView(word: word, score: score, transcription: transcription)
    let renderer = ImageRenderer(content: card)
    renderer.scale = 3.0

    guard let image = renderer.uiImage else { return }

    let text = "I scored \(Int(score * 100))% on '\(word)' in Mimiq! Can you beat me? 🎙️"
    let vc = UIActivityViewController(activityItems: [image, text], applicationActivities: nil)

    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first?.rootViewController else { return }

    vc.popoverPresentationController?.sourceView = root.view
    vc.popoverPresentationController?.sourceRect = CGRect(
        x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0
    )
    root.present(vc, animated: true)
}
