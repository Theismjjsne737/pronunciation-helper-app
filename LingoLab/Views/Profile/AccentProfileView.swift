import SwiftUI
import SwiftData
import Charts

/// Rich progress dashboard — streak, accuracy chart, phoneme challenges, recent attempts.
struct AccentProfileView: View {

    @Query(filter: #Predicate<AccentProfile> { _ in true }) private var profiles: [AccentProfile]
    @Query(sort: \ChatMessage.timestamp, order: .reverse) private var allMessages: [ChatMessage]
    @ObservedObject private var streak = StreakService.shared
    @State private var showOnboarding = false
    @Environment(\.modelContext) private var modelContext

    private var profile: AccentProfile? { profiles.first }

    private var attemptMessages: [ChatMessage] {
        allMessages.filter { $0.kind == .pronunciationResult }
    }

    private var averageScore: Double {
        guard !attemptMessages.isEmpty else { return 0 }
        let scores = attemptMessages.compactMap(\.pronunciationScore)
        return scores.reduce(0, +) / Double(scores.count)
    }

    private var bestScore: Double {
        attemptMessages.compactMap(\.pronunciationScore).max() ?? 0
    }

    private var wordsCount: Int {
        Set(attemptMessages.compactMap(\.targetWord)).count
    }

    private var recentTrend: Double? {
        let scores = attemptMessages.compactMap(\.pronunciationScore)
        guard scores.count >= 4 else { return nil }
        let recentAvg = scores.prefix(5).reduce(0, +) / Double(min(5, scores.count))
        let older = Array(scores.dropFirst(5).prefix(5))
        guard !older.isEmpty else { return nil }
        return recentAvg - older.reduce(0, +) / Double(older.count)
    }

    private var chartData: [ScorePoint] {
        attemptMessages
            .prefix(20)
            .reversed()
            .compactMap { msg -> ScorePoint? in
                guard let score = msg.pronunciationScore,
                      let word = msg.targetWord else { return nil }
                return ScorePoint(date: msg.timestamp, score: score * 100, word: word)
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    streakSection
                    statsGrid
                    if chartData.count >= 2 { progressChart }
                    if let p = profile, !p.topChallenges.isEmpty { challengesCard(p) }
                    recentAttemptsCard
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit accent") { showOnboarding = true }
                        .font(.subheadline)
                }
            }
            .sheet(isPresented: $showOnboarding) {
                if let p = profile { OnboardingView(profile: p) }
            }
        }
    }

    // MARK: - Streak section

    private var streakSection: some View {
        VStack(spacing: 16) {
            // Main streak display
            HStack(alignment: .center, spacing: 20) {
                VStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 48))
                    Text("\(streak.currentStreak)")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(streak.currentStreak > 0 ? Color.orange : Color.secondary)
                    Text("day streak")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    streakStat(label: "Longest", value: "\(streak.longestStreak) days", icon: "trophy.fill", color: .yellow)
                    streakStat(label: "Total days", value: "\(streak.totalPracticeDays)", icon: "calendar", color: .indigo)
                    streakStat(label: "Today", value: streak.practicedToday ? "Done ✓" : "Not yet", icon: "sun.max.fill", color: .orange)
                }

                Spacer()
            }

            // Week activity dots
            HStack(spacing: 10) {
                ForEach(Array(streak.weekActivity.enumerated()), id: \.offset) { i, active in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(active ? Color.orange : Color(.systemGray5))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if active {
                                    Text("🔥").font(.system(size: 14))
                                }
                            }
                        Text(weekDayLabel(daysAgo: streak.weekActivity.count - 1 - i))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }

    private func streakStat(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
        }
    }

    private func weekDayLabel(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(value: "\(attemptMessages.count)", label: "Attempts",   icon: "mic.fill",        color: .indigo)
            StatTile(value: "\(Int(averageScore * 100))%", label: "Avg Score", icon: "chart.bar.fill", color: .blue)
            StatTile(value: "\(wordsCount)",               label: "Words",     icon: "textformat.abc",  color: .purple)
            StatTile(value: "\(Int(bestScore * 100))%",    label: "Best",      icon: "star.fill",       color: .yellow)
        }
    }

    // MARK: - Progress chart

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Accuracy Over Time", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let trend = recentTrend {
                    let trendColor: Color = trend >= 0.02 ? .green : trend <= -0.02 ? .red : .secondary
                    let trendIcon = trend >= 0.02 ? "arrow.up" : trend <= -0.02 ? "arrow.down" : "minus"
                    HStack(spacing: 3) {
                        Image(systemName: trendIcon).font(.caption2.weight(.bold))
                        Text("\(abs(Int(trend * 100)))%").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(trendColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(trendColor.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            Chart(chartData) { point in
                LineMark(
                    x: .value("Session", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(Color.indigo.gradient)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Session", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.indigo.opacity(0.25), .indigo.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Session", point.date),
                    y: .value("Score", point.score)
                )
                .foregroundStyle(scoreColor(point.score / 100))
                .symbolSize(30)
                .annotation(position: .top) {
                    Text(point.word)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                    AxisGridLine().foregroundStyle(Color(.systemGray5))
                    AxisValueLabel("\(val.as(Int.self) ?? 0)%")
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .frame(height: 160)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Phoneme challenges

    private func challengesCard(_ profile: AccentProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Phoneme Challenges", systemImage: "waveform.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))

            ForEach(profile.topChallenges) { pattern in
                PhonemeRow(pattern: pattern)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Recent attempts

    @ViewBuilder
    private var recentAttemptsCard: some View {
        if !attemptMessages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Recent Attempts", systemImage: "clock")
                    .font(.subheadline.weight(.semibold))

                ForEach(Array(attemptMessages.prefix(10).enumerated()), id: \.element.id) { i, msg in
                    if i > 0 { Divider() }
                    RecentAttemptRow(message: msg)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        } else {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: "waveform.and.mic")
                    .font(.system(size: 36))
                    .foregroundStyle(.indigo.opacity(0.4))
                Text("No attempts yet")
                    .font(.headline)
                Text("Head to the Practice tab to try your first word, or ask your coach to help!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.9...: return .green
        case 0.75..<0.9: return .blue
        case 0.55..<0.75: return .orange
        default: return .red
        }
    }
}

// MARK: - Chart data model

private struct ScorePoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double   // 0–100
    let word: String
}

// MARK: - Supporting views

private struct StatTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

private struct PhonemeRow: View {
    let pattern: PhonemePattern

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Text("'\(pattern.phoneme)'")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                    if let sub = pattern.substitution {
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                        Text("'\(sub)'").font(.subheadline).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Text("\(Int(pattern.accuracy * 100))%")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color(.systemGray5)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor.gradient)
                        .frame(width: geo.size.width * pattern.accuracy, height: 5)
                        .animation(.easeOut(duration: 0.6), value: pattern.accuracy)
                }
            }
            .frame(height: 5)
            Text("\(pattern.attemptCount) attempt\(pattern.attemptCount == 1 ? "" : "s")")
                .font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private var barColor: Color {
        pattern.accuracy >= 0.75 ? .green : pattern.accuracy >= 0.5 ? .orange : .red
    }
}

private struct RecentAttemptRow: View {
    let message: ChatMessage

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                    .frame(width: 42, height: 42)
                Circle()
                    .trim(from: 0, to: message.pronunciationScore ?? 0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: message.pronunciationScore)
                Text("\(Int((message.pronunciationScore ?? 0) * 100))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(scoreColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(message.targetWord ?? "—")
                    .font(.subheadline.weight(.semibold))
                if let heard = message.transcription, !heard.isEmpty {
                    Text("Heard: \"\(heard)\"")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(Self.fmt.string(from: message.timestamp))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.targetWord ?? "word"), scored \(Int((message.pronunciationScore ?? 0) * 100)) percent")
    }

    private var scoreColor: Color {
        switch message.pronunciationScore ?? 0 {
        case 0.9...: return .green
        case 0.75..<0.9: return .blue
        case 0.55..<0.75: return .orange
        default: return .red
        }
    }
}
