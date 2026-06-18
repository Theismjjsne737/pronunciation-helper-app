import SwiftUI

// MARK: - Main dispatcher

struct MessageBubbleView: View {
    let message: ChatMessage
    let onSpeak: (String) -> Void     // called when user taps the speaker button

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 52) }
            if !message.isUser { CoachAvatar() }

            Group {
                switch message.kind {
                case .pronunciationResult:
                    AttemptResultBubble(message: message)
                case .recordingRequest:
                    CoachBubble(message: message, onSpeak: onSpeak, showSpeaker: true)
                default:
                    if message.isUser {
                        UserTextBubble(text: message.content)
                    } else {
                        CoachBubble(message: message, onSpeak: onSpeak, showSpeaker: false)
                    }
                }
            }

            if !message.isUser { Spacer(minLength: 52) }
        }
    }
}

// MARK: - User text bubble

private struct UserTextBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.indigo.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Coach text bubble (with optional speaker button)

private struct CoachBubble: View {
    let message: ChatMessage
    let onSpeak: (String) -> Void
    let showSpeaker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Speaker button shown when message contains a recording request
            if showSpeaker, let word = message.targetWord {
                Button {
                    onSpeak(word)
                } label: {
                    Label("Hear \"\(word)\"", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.indigo.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Pronunciation attempt result card

private struct AttemptResultBubble: View {
    let message: ChatMessage

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundStyle(.white.opacity(0.9))
                Text(message.targetWord ?? "Recording")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let score = message.pronunciationScore {
                    Text("\(Int(score * 100))%")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            if let heard = message.transcription, !heard.isEmpty {
                HStack {
                    Text("Heard:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\"\(heard)\"")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .italic()
                    Spacer()
                    if let score = message.pronunciationScore {
                        Text(scoreLabel(score))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(scoreGradient)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func scoreLabel(_ s: Double) -> String {
        switch s {
        case 0.9...: return "Excellent"
        case 0.75..<0.9: return "Good"
        case 0.55..<0.75: return "Fair"
        default: return "Keep going"
        }
    }

    private var scoreGradient: LinearGradient {
        let c: Color = {
            switch message.pronunciationScore ?? 0 {
            case 0.9...: return .green
            case 0.75..<0.9: return .blue
            case 0.55..<0.75: return .orange
            default: return .red
            }
        }()
        return LinearGradient(colors: [c, c.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Streaming / typewriter bubble

struct StreamingBubbleView: View {
    let text: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            CoachAvatar()

            Group {
                if text.isEmpty {
                    TypingIndicatorView()
                } else {
                    Text(text)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)

            Spacer(minLength: 52)
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicatorView: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.38, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color(.tertiaryLabel))
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.4 : 0.9)
                    .animation(.easeInOut(duration: 0.3), value: phase)
            }
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

// MARK: - Coach avatar

struct CoachAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 34, height: 34)
            Image(systemName: "waveform")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
