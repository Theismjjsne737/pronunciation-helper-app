import SwiftUI
import SwiftData

/// Standalone pronunciation practice screen.
/// Flow: word entry → hear native reference → record → score + phoneme breakdown.
struct PracticeView: View {

    @StateObject private var vm = PracticeViewModel()
    @StateObject private var dailyChallenge = DailyChallengeService.shared
    @ObservedObject private var streak = StreakService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @State private var wordHistory: [Double] = []
    @State private var recentWords: [String] = []
    @State private var wordBestScores: [String: Double] = [:]

    private let violet   = Color(red: 0.48, green: 0.33, blue: 1.0)
    private let lavender = Color(red: 0.773, green: 0.722, blue: 1.0)

    var body: some View {
        NavigationStack {
            phaseContent
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                .animation(.spring(duration: 0.35), value: phaseTag)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.027, green: 0.020, blue: 0.059).ignoresSafeArea())
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
            .task { recentWords = fetchRecentWords(); wordBestScores = fetchBestScores() }
            .onChange(of: phaseTag) { _, _ in
                if case .result(let word, let result, _) = vm.phase {
                    saveResult(word: word, result: result)
                    wordHistory = fetchHistory(for: word)
                    recentWords = fetchRecentWords()
                    wordBestScores = fetchBestScores()
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

    private func fetchBestScores() -> [String: Double] {
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.kindRaw == "pronunciationResult" }
        )
        let msgs = (try? modelContext.fetch(descriptor)) ?? []
        var best: [String: Double] = [:]
        for msg in msgs {
            if let word = msg.targetWord?.lowercased(), let score = msg.pronunciationScore {
                best[word] = max(best[word] ?? 0, score)
            }
        }
        return best
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
            VStack(alignment: .leading, spacing: 0) {

                // Headline
                VStack(alignment: .leading, spacing: 6) {
                    Text("One word a day.\nMassive gains.")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0))
                        .lineSpacing(2)
                    Text("A new tricky word every morning. Beat your score.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0).opacity(0.58))
                        .lineSpacing(4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 20)

                // Daily Challenge pill
                Button {
                    vm.wordInput = dailyChallenge.todaysWord
                    vm.startPractice()
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(violet)
                                .frame(width: 46, height: 46)
                            Text("🎯").font(.system(size: 22))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TODAY'S CHALLENGE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(violet)
                                .tracking(1.0)
                            Text(dailyChallenge.todaysWord)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0))
                            if let ipa = IPAMapper.ipa(for: dailyChallenge.todaysWord) {
                                Text(ipa)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0).opacity(0.58))
                            }
                        }
                        Spacer()
                        Text("›")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(violet)
                    }
                    .padding(18)
                    .background(violet.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(violet.opacity(0.30), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(dailyChallenge.completedToday)
                .padding(.horizontal, 20)

                // Streak row
                HStack(spacing: 14) {
                    Text("🔥").font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(streak.currentStreak)-day streak")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color(red: 0.984, green: 0.573, blue: 0.235))
                        Text(streak.practicedToday ? "You practiced today — great!" : "Keep it going")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0).opacity(0.58))
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color(red: 0.984, green: 0.573, blue: 0.235).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.984, green: 0.573, blue: 0.235).opacity(0.25), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Custom word entry
                HStack(spacing: 10) {
                    TextField("Enter any word or name…", text: $vm.wordInput)
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0))
                        .tint(violet)
                        .submitLabel(.go)
                        .onSubmit { if !vm.wordInput.trimmingCharacters(in: .whitespaces).isEmpty { vm.startPractice() } }
                    if !vm.wordInput.isEmpty {
                        Button(action: vm.startPractice) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(violet)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(violet.opacity(vm.wordInput.isEmpty ? 0.15 : 0.45), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 12)

                // Practice Library header
                Text("PRACTICE LIBRARY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.941, green: 0.933, blue: 1.0).opacity(0.58))
                    .tracking(0.08 * 11)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)

                // Word rows
                VStack(spacing: 8) {
                    ForEach(PracticeItem.library.prefix(12), id: \.word) { item in
                        wordRow(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Library word row

    private func wordRow(_ item: PracticeItem) -> some View {
        Button {
            vm.wordInput = item.word
            vm.startPractice()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.word)
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(item.phonetic)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
                Spacer()
                wordBadge(for: item)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(violet.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func wordBadge(for item: PracticeItem) -> some View {
        if let best = wordBestScores[item.word.lowercased()] {
            let pct = Int(best * 100)
            let good = best >= 0.55
            let color: Color = best >= 0.75 ? Color(red: 0.20, green: 0.85, blue: 0.55) : .orange
            Text(good ? "✓ \(pct)%" : "\(pct)%")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(color.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(color.opacity(0.30), lineWidth: 1))
        } else if item.difficulty == .advanced {
            Text("Hard")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.orange)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.orange.opacity(0.30), lineWidth: 1))
        } else {
            Text("New")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(lavender)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(lavender.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(lavender.opacity(0.30), lineWidth: 1))
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
