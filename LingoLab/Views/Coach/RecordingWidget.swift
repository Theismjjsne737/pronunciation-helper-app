import SwiftUI

/// Persistent bottom bar that slides up when the coach requests a recording.
struct RecordingWidget: View {

    @ObservedObject var vm: CoachViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Pull handle
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 6)

            content
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.12), radius: 24, y: -8)
                .ignoresSafeArea(edges: .bottom)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private var content: some View {
        switch vm.coachState {
        case .awaitingAttempt(let word): awaitingView(word: word)
        case .recording(let word):       recordingView(word: word)
        case .analyzing(let word):       analyzingView(word: word)
        default:                         EmptyView()
        }
    }

    // MARK: - Awaiting state

    private func awaitingView(word: String) -> some View {
        VStack(spacing: 14) {
            // Word display
            VStack(spacing: 4) {
                Text("Your turn to say")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(word)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            // Controls row
            HStack(spacing: 12) {
                // Normal speed TTS
                ttsButton(label: "Hear it", icon: vm.tts.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill", color: .indigo) {
                    HapticsService.light()
                    vm.speakWord(word)
                }

                // Slow TTS
                ttsButton(label: "Slow", icon: "tortoise.fill", color: .teal) {
                    HapticsService.light()
                    vm.speakWord(word, slowly: true)
                }

                Spacer()

                // Record button — tap OR hold & release to record + auto-analyze
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.fill")
                            .symbolEffect(.bounce, value: true)
                        Text("Record")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: .red.opacity(0.4), radius: 8, y: 4)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if case .awaitingAttempt = vm.coachState {
                                    HapticsService.medium()
                                    vm.startRecording()
                                }
                            }
                            .onEnded { _ in
                                if case .recording = vm.coachState {
                                    HapticsService.light()
                                    Task { await vm.stopAndAnalyze() }
                                }
                            }
                    )

                    Text("Hold to record")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Hold to record \(word)")
            }
        }
    }

    private func ttsButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .symbolEffect(.variableColor, isActive: vm.tts.isSpeaking && icon.contains("speaker"))
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56, height: 52)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .accessibilityLabel(label)
    }

    // MARK: - Recording state

    private func recordingView(word: String) -> some View {
        VStack(spacing: 12) {
            // Live waveform
            AudioWaveformView(samples: vm.waveformSamples, barColor: .red, isActive: true)
                .frame(height: 36)

            HStack(spacing: 12) {
                // Duration + pulsing dot
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(reduceMotion ? 1 : pulsingOpacity)
                        .animation(
                            reduceMotion ? nil : .easeInOut(duration: 0.6).repeatForever(),
                            value: pulsingOpacity
                        )
                    Text(formatDuration(vm.recordingDuration))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.red)
                }

                Spacer()

                // Cancel
                Button {
                    HapticsService.light()
                    vm.cancelRecording()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .labelStyle(.iconOnly)
                        .frame(width: 38, height: 38)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Cancel recording")

                // Stop & analyze
                Button {
                    HapticsService.medium()
                    Task { await vm.stopAndAnalyze() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                    .background(Color.red.gradient)
                    .clipShape(Capsule())
                    .shadow(color: .red.opacity(0.3), radius: 6, y: 3)
                }
                .accessibilityLabel("Stop and analyze recording")
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) { pulsingOpacity = 0.3 }
            }
        }
    }

    // MARK: - Analyzing state

    private func analyzingView(word: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.indigo.opacity(0.2), lineWidth: 3)
                    .frame(width: 36, height: 36)
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.indigo)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Analysing…")
                    .font(.subheadline.weight(.semibold))
                Text("Scoring your pronunciation of \"\(word)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - State

    @State private var pulsingOpacity: Double = 1.0

    private func formatDuration(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
