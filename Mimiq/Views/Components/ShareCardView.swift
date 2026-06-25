import SwiftUI
import UIKit

// MARK: - Design tokens (file-local)
private let _navy     = Color(red: 0.027, green: 0.020, blue: 0.059)
private let _violet   = Color(red: 0.482, green: 0.333, blue: 1.0)
private let _lavender = Color(red: 0.773, green: 0.722, blue: 1.0)
private let _offWhite = Color(red: 0.941, green: 0.933, blue: 1.0)
private let _muted    = Color(red: 0.941, green: 0.933, blue: 1.0).opacity(0.58)

// MARK: - Share card (the image that gets shared)

/// Branded result card rendered to PNG and shared via UIActivityViewController.
struct ShareCardView: View {

    let word: String
    let score: Double      // 0.0–1.0
    let transcription: String

    var body: some View {
        ZStack {
            _navy

            Circle()
                .fill(_violet.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(y: -20)

            VStack(spacing: 0) {
                // Logo row
                HStack {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(_violet)
                    Text("Pronce")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(_offWhite)
                    Spacer()
                    Text("pronunciation coach")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(_muted)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                Text(word)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(_offWhite)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                // Score ring
                ZStack {
                    Circle()
                        .trim(from: 0.15, to: 0.85)
                        .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(90))
                    Circle()
                        .trim(from: 0.15, to: 0.15 + 0.7 * score)
                        .stroke(
                            LinearGradient(colors: [_violet, _lavender],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))
                    VStack(spacing: 2) {
                        Text("\(Int(score * 100))")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(_offWhite)
                        Text("/ 100")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(_muted)
                    }
                }
                .frame(width: 140, height: 140)

                Spacer().frame(height: 16)

                Text(scoreLabel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(_violet)

                if !transcription.isEmpty {
                    Text("heard: \"\(transcription)\"")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(_muted)
                        .padding(.top, 4)
                }

                Spacer()

                Text("Can you beat me? 🎯  pronce.app")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(_muted)
                    .padding(.bottom, 24)
            }
        }
        .frame(width: 280, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(_violet.opacity(0.35), lineWidth: 1))
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

// MARK: - Share sheet wrapper

struct ShareSheetView: View {
    let word: String
    let score: Double
    let transcription: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            _navy.ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                VStack(spacing: 6) {
                    Text("Flex your\npronunciation.")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(_offWhite)
                        .lineSpacing(2)
                        .multilineTextAlignment(.center)
                    Text("Share your score and challenge your friends.")
                        .font(.system(size: 13))
                        .foregroundStyle(_muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                // Card preview
                ShareCardView(word: word, score: score, transcription: transcription)
                    .shadow(color: _violet.opacity(0.25), radius: 24, y: 8)

                Spacer()

                VStack(spacing: 12) {
                    // Share to Stories
                    Button {
                        shareScoreCard(word: word, score: score, transcription: transcription)
                    } label: {
                        Text("Share to Stories")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [_violet, Color(red: 0.35, green: 0.20, blue: 0.90)],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Copy image
                    Button {
                        copyCardImage()
                    } label: {
                        Label("Copy Image", systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(_violet)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(_violet.opacity(0.45), lineWidth: 1))
                    }

                    Text("Also: iMessage, X, WhatsApp, Instagram…")
                        .font(.system(size: 12))
                        .foregroundStyle(_muted)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func copyCardImage() {
        let card = ShareCardView(word: word, score: score, transcription: transcription)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        guard let image = renderer.uiImage else { return }
        UIPasteboard.general.image = image
    }
}

// MARK: - Share helper

@MainActor
func shareScoreCard(word: String, score: Double, transcription: String) {
    let card = ShareCardView(word: word, score: score, transcription: transcription)
    let renderer = ImageRenderer(content: card)
    renderer.scale = 3.0

    guard let image = renderer.uiImage else { return }

    let text = "I scored \(Int(score * 100))% on '\(word)' in Pronce! Can you beat me? 🎙️"
    let vc = UIActivityViewController(activityItems: [image, text], applicationActivities: nil)

    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let root = scene.windows.first?.rootViewController else { return }

    vc.popoverPresentationController?.sourceView = root.view
    vc.popoverPresentationController?.sourceRect = CGRect(
        x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0
    )
    root.present(vc, animated: true)
}
