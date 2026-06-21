import SwiftUI

// MARK: - Main dispatcher

struct MessageBubbleView: View {
    let message: ChatMessage
    @ObservedObject var tts: TTSService
    @ObservedObject private var subs = SubscriptionManager.shared
    let onSpeak: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 52) }
            if !message.isUser { CoachAvatar() }

            Group {
                switch message.kind {
                case .pronunciationResult:
                    VStack(alignment: .trailing, spacing: 4) {
                        AttemptResultBubble(message: message)
                        if !subs.hasActiveSubscription {
                            let remaining = subs.wordsRemaining
                            Text(remaining > 0
                                 ? "\(remaining) free word\(remaining == 1 ? "" : "s") remaining"
                                 : "Upgrade to keep practising")
                                .font(.caption2)
                                .foregroundStyle(remaining <= 1 ? .orange : .secondary)
                                .padding(.trailing, 4)
                        }
                    }
                case .recordingRequest:
                    CoachBubble(message: message, tts: tts, onSpeak: onSpeak, showSpeaker: true)
                case .exerciseCard:
                    ExerciseCardBubble(message: message)
                default:
                    if message.isUser {
                        UserTextBubble(text: message.content)
                    } else {
                        CoachBubble(message: message, tts: tts, onSpeak: onSpeak, showSpeaker: false)
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
    @ObservedObject var tts: TTSService
    let onSpeak: (String) -> Void
    let showSpeaker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message.content)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if showSpeaker, let word = message.targetWord {
                Button { onSpeak(word) } label: {
                    HStack(spacing: 8) {
                        if tts.isSpeaking {
                            MiniWaveformView()
                        } else {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.subheadline)
                        }
                        Text(tts.isSpeaking ? "Playing…" : "Hear \"\(word)\"")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.indigo.opacity(tts.isSpeaking ? 0.15 : 0.1))
                    .clipShape(Capsule())
                    .animation(.easeInOut(duration: 0.2), value: tts.isSpeaking)
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

// MARK: - Mini animated waveform for inline audio player

private struct MiniWaveformView: View {
    @State private var phase: [CGFloat] = [0.4, 0.7, 1.0, 0.6, 0.3]
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.indigo)
                    .frame(width: 3, height: 14 * phase[i])
                    .animation(.easeInOut(duration: 0.25), value: phase[i])
            }
        }
        .frame(height: 14)
        .onReceive(timer) { _ in
            phase = phase.map { _ in CGFloat.random(in: 0.25...1.0) }
        }
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

            if let patterns = message.detectedPatternsRaw {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.badge.exclamationmark")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(patterns)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.18))
                .clipShape(Capsule())
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

// MARK: - Exercise card bubble

private struct ExerciseCardBubble: View {
    let message: ChatMessage
    @State private var expanded = false

    private struct CardData: Decodable {
        let phoneme: String
        let why: String?
        let technique: String?
        let drillWords: [String]
    }

    private var card: CardData? {
        guard let data = message.content.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CardData.self, from: data)
    }

    var body: some View {
        if let c = card {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Button { withAnimation(.spring(duration: 0.3)) { expanded.toggle() } } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(Color.indigo.opacity(0.15)).frame(width: 32, height: 32)
                            Text("💪").font(.system(size: 15))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Exercise: /\(c.phoneme)/")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Tap to \(expanded ? "collapse" : "see drill")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider().padding(.horizontal, 14)

                    VStack(alignment: .leading, spacing: 12) {
                        if let why = c.why {
                            exerciseRow(icon: "lightbulb.fill", color: .orange, label: "Why this happens", body: why)
                        }
                        if let technique = c.technique {
                            exerciseRow(icon: "graduationcap.fill", color: .indigo, label: "Try this", body: technique)
                        }
                        if !c.drillWords.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Drill words", systemImage: "speaker.wave.2.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    ForEach(c.drillWords, id: \.self) { word in
                                        Text(word)
                                            .font(.subheadline.weight(.medium))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.indigo.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    private func exerciseRow(icon: String, color: Color, label: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
