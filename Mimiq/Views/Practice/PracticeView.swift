import SwiftUI
import SwiftData

/// Standalone pronunciation practice screen.
/// Flow: word entry → hear native reference → record → score + phoneme breakdown.
struct PracticeView: View {

    @StateObject private var vm = PracticeViewModel()
    @StateObject private var dailyChallenge = DailyChallengeService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @State private var wordHistory: [Double] = []
    @State private var recentWords: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.027, green: 0.020, blue: 0.059).ignoresSafeArea()
                phaseContent
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.spring(duration: 0.35), value: phaseTag)
            }
            .preferredColorScheme(.dark)
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .task { await vm.requestPermissions() }
            .task { recentWords = fetchRecentWords() }
            .onChange(of: phaseTag) { _, _ in
                if case .result(let word, let result, _) = vm.phase {
                    saveResult(word: word, result: result)
                    wordHistory = fetchHistory(for: word)
                    recentWords = fetchRecentWords()
                }
            }
        }
    }

    // MARK: - Persistence

    private func saveResult(word: String, result: AnalysisResult) {
        let msg = ChatMessage(
            role: .user,
            kind: .pronunciationResult,
            content: "\(word): \(result.scorePercentage)%",
            targetWord: word,
            pronunciationScore: result.score,
            transcription: result.transcription,
            sessionID: UUID()
        )
        modelContext.insert(msg)

        let descriptor = FetchDescriptor<AccentProfile>()
        if let profile = try? modelContext.fetch(descriptor).first {
            AccentProfileService().record(
                targetWord: word,
                transcription: result.transcription,
                score: result.score,
                into: profile
            )
        }

        StreakService.shared.recordPractice()

        if word.lowercased() == dailyChallenge.todaysWord.lowercased() {
            dailyChallenge.markCompleted()
        }
    }

    private func fetchRecentWords() -> [String] {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.kindRaw == "pronunciationResult" },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let msgs = (try? modelContext.fetch(descriptor)) ?? []
        var seen = Set<String>()
        var result: [String] = []
        for msg in msgs {
            if let w = msg.targetWord, seen.insert(w).inserted {
                result.append(w)
                if result.count == 5 { break }
            }
        }
        return result
    }

    private func fetchHistory(for word: String) -> [Double] {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.targetWord == word && $0.kindRaw == "pronunciationResult" },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let msgs = (try? modelContext.fetch(descriptor)) ?? []
        return msgs.suffix(10).compactMap(\.pronunciationScore)
    }

    // MARK: - Phase routing

    @ViewBuilder
    private var phaseContent: some View {
        switch vm.phase {
        case .wordEntry:
            wordEntryView
        case .preRecord(let word):
            preRecordView(word: word)
        case .recording(let word):
            recordingView(word: word)
        case .analyzing(let word):
            analyzingView(word: word)
        case .result(let word, let result, _):
            PracticeResultView(word: word, result: result, wordHistory: wordHistory, vm: vm)
        }
    }

    // MARK: - Word Entry

    private var wordEntryView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 16)

                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [.indigo.opacity(0.15), .purple.opacity(0.08)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 100, height: 100)
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                }

                VStack(spacing: 8) {
                    Text("What would you like to master?")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text("Enter any word, name, or short phrase.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    TextField("e.g. \"Nguyen\", \"worcestershire\"", text: $vm.wordInput)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(vm.wordInput.isEmpty ? 0.15 : 0.55), lineWidth: 1.5)
                        )
                        .submitLabel(.go)
                        .onSubmit { vm.startPractice() }

                    Button(action: vm.startPractice) {
                        Text("Start Practicing")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                if vm.wordInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                    Color.white.opacity(0.08)
                                } else {
                                    LinearGradient(colors: [Color(red: 0.48, green: 0.33, blue: 1.0), Color(red: 0.35, green: 0.20, blue: 0.85)], startPoint: .leading, endPoint: .trailing)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(vm.wordInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24)

                // Daily Challenge
                Button {
                    vm.wordInput = dailyChallenge.todaysWord
                    vm.startPractice()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: dailyChallenge.completedToday ? "checkmark.seal.fill" : "seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(dailyChallenge.completedToday ? .green : Color(red: 0.48, green: 0.33, blue: 1.0))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TODAY'S CHALLENGE")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                                .tracking(1)
                            Text(dailyChallenge.todaysWord)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        if dailyChallenge.completedToday {
                            Text("Done ✓")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        dailyChallenge.completedToday
                            ? Color.green.opacity(0.08)
                            : Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                dailyChallenge.completedToday
                                    ? Color.green.opacity(0.3)
                                    : Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.3),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(dailyChallenge.completedToday)

                if !recentWords.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recent")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 24)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recentWords, id: \.self) { word in
                                    Button {
                                        vm.wordInput = word
                                        vm.startPractice()
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "arrow.clockwise").font(.caption2)
                                            Text(word).font(.subheadline.weight(.semibold))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(Color.indigo.opacity(0.1))
                                        .foregroundStyle(.indigo)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.indigo.opacity(0.25), lineWidth: 1))
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                Divider()
                    .padding(.horizontal, 20)

                PracticeLibraryView(vm: vm)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Pre-Record

    private func preRecordView(word: String) -> some View {
        ScrollView {
            VStack(spacing: 20) {

                // Word hero
                VStack(spacing: 6) {
                    Text("PRACTICE WORD")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Text(word)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    if let ipa = IPAMapper.ipa(for: word) {
                        Text(ipa)
                            .font(.system(size: 16, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 20)

                // Native reference
                VStack(alignment: .leading, spacing: 14) {
                    Label("Native Reference", systemImage: "speaker.wave.3.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    Text("Listen before you record. Try both speeds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Button { vm.speakNative() } label: {
                            HStack(spacing: 6) {
                                Image(systemName: vm.tts.isSpeaking ? "speaker.wave.3.fill" : "play.fill")
                                Text("Hear it").fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button { vm.speakNative(slowly: true) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tortoise.fill")
                                Text("Slow").fontWeight(.semibold)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.teal)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.teal.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.teal.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 20)

                // vs divider
                HStack {
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                    Text("vs").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 8)
                    Rectangle().fill(Color(.separator)).frame(height: 1)
                }
                .padding(.horizontal, 24)

                // Record prompt
                VStack(alignment: .leading, spacing: 14) {
                    Label("Your Turn", systemImage: "mic.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    Text("Record yourself saying the word as naturally as you can.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button { vm.startRecording() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "record.circle").font(.title3)
                            Text("Start Recording").fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                    }
                }
                .padding(20)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 20)

                Button("← Try a different word") { vm.newWord() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 24)
        }
    }

    // MARK: - Recording

    private func recordingView(word: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text(word)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            HStack(spacing: 8) {
                Circle().fill(Color.red).frame(width: 10, height: 10)
                Text("Recording").font(.subheadline.weight(.semibold)).foregroundStyle(.red)
                Text("·").foregroundStyle(.secondary)
                Text(formatDuration(vm.recordingDuration))
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary)
            }

            AudioWaveformView(samples: vm.waveformSamples, barColor: .red, isActive: true)
                .frame(height: 72)
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.15), lineWidth: 1))
                .padding(.horizontal, 20)

            HStack(spacing: 16) {
                Button { vm.cancelRecording() } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Cancel recording")

                Button {
                    Task { await vm.stopAndAnalyze() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("Done").fontWeight(.bold)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
                }
                .accessibilityLabel("Stop and analyze")
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Analyzing

    private func analyzingView(word: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView().scaleEffect(1.4).tint(.indigo)
            VStack(spacing: 6) {
                Text("Analysing your pronunciation…").font(.headline)
                Text("Scoring \"\(word)\"").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private var phaseTag: Int {
        switch vm.phase {
        case .wordEntry:  return 0
        case .preRecord:  return 1
        case .recording:  return 2
        case .analyzing:  return 3
        case .result:     return 4
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
