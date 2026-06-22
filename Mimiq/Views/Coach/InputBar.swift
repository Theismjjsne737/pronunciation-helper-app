import SwiftUI

/// Bottom text input bar with voice input support.
struct InputBar: View {

    @ObservedObject var vm: CoachViewModel
    @StateObject private var voice = VoiceInputService()
    @FocusState private var focused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isDisabled: Bool {
        switch vm.coachState {
        case .idle: return false
        default: return true
        }
    }

    private var placeholder: String {
        if voice.isListening { return "Listening…" }
        switch vm.coachState {
        case .thinking:                          return "Coach is responding…"
        case .awaitingAttempt, .recording, .analyzing: return "Record your attempt above"
        default:                                 return "Ask about any word or name…"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Voice transcript preview
            if voice.isListening && !voice.transcript.isEmpty {
                HStack {
                    Text(voice.transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    Spacer()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 8) {

                // ── Voice mic button ─────────────────────────
                Button {
                    HapticsService.light()
                    if voice.isListening {
                        let text = voice.consume()
                        voice.stop()
                        if !text.isEmpty {
                            vm.inputText = text
                            focused = true
                        }
                    } else {
                        focused = false
                        Task { await voice.start() }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(voice.isListening ? Color.red.opacity(0.12) : Color(.secondarySystemGroupedBackground))
                            .frame(width: 40, height: 40)

                        Image(systemName: voice.isListening ? "mic.fill" : "mic")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(voice.isListening ? .red : .secondary)
                            .symbolEffect(.pulse, isActive: voice.isListening && !reduceMotion)
                    }
                }
                .disabled(isDisabled)
                .accessibilityLabel(voice.isListening ? "Stop listening" : "Speak your question")

                // ── Text field ───────────────────────────────
                TextField(placeholder, text: $vm.inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .focused($focused)
                    .disabled(isDisabled)
                    .submitLabel(.send)
                    .onSubmit { sendIfReady() }
                    .onChange(of: voice.transcript) { _, t in
                        if voice.isListening { vm.inputText = t }
                    }

                // ── Send button ──────────────────────────────
                Button {
                    focused = false
                    voice.stop()
                    sendIfReady()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(sendEnabled ? Color.indigo : Color(.tertiaryLabel))
                        .animation(.easeInOut(duration: 0.15), value: sendEnabled)
                }
                .disabled(!sendEnabled)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, max(8, 0))
        }
        .background(
            Color(.systemGroupedBackground)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.spring(duration: 0.25), value: voice.isListening)
    }

    private var sendEnabled: Bool {
        !vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty && !isDisabled
    }

    private func sendIfReady() {
        guard sendEnabled else { return }
        HapticsService.light()
        Task { await vm.send() }
    }
}
