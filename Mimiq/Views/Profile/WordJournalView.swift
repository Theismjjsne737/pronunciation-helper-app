import SwiftUI
import SwiftData

/// Word Journal — every word the user has practiced, with best score, attempt count, and trend.
struct WordJournalView: View {

    @Query(sort: \ChatMessage.timestamp, order: .reverse) private var allMessages: [ChatMessage]
    @State private var searchText = ""
    @State private var sortMode: SortMode = .recentFirst

    enum SortMode: String, CaseIterable {
        case recentFirst = "Recent"
        case worstFirst  = "Needs Work"
        case bestFirst   = "Best Score"
        case az          = "A–Z"
    }

    private var wordEntries: [WordEntry] {
        let attempts = allMessages.filter { $0.kind == .pronunciationResult }
        var map: [String: [ChatMessage]] = [:]
        for msg in attempts {
            guard let word = msg.targetWord else { continue }
            map[word, default: []].append(msg)
        }
        return map.map { word, msgs in
            let scores = msgs.compactMap(\.pronunciationScore)
            let best   = scores.max() ?? 0
            let last   = scores.first ?? 0
            let avg    = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
            let firstAt = msgs.map(\.timestamp).min() ?? Date()
            let lastAt  = msgs.map(\.timestamp).max() ?? Date()
            return WordEntry(word: word, bestScore: best, lastScore: last,
                             avgScore: avg, attempts: msgs.count, firstAt: firstAt, lastAt: lastAt)
        }
    }

    private var filtered: [WordEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let base = q.isEmpty ? wordEntries : wordEntries.filter { $0.word.lowercased().contains(q) }
        switch sortMode {
        case .recentFirst: return base.sorted { $0.lastAt > $1.lastAt }
        case .worstFirst:  return base.sorted { $0.bestScore < $1.bestScore }
        case .bestFirst:   return base.sorted { $0.bestScore > $1.bestScore }
        case .az:          return base.sorted { $0.word < $1.word }
        }
    }

    var body: some View {
        Group {
            if filtered.isEmpty && searchText.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(filtered) { entry in
                        WordJournalRow(entry: entry)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .searchable(text: $searchText, prompt: "Search words…")
            }
        }
        .navigationTitle("Word Journal")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(SortMode.allCases, id: \.self) { mode in
                        Button {
                            sortMode = mode
                        } label: {
                            if sortMode == mode {
                                Label(mode.rawValue, systemImage: "checkmark")
                            } else {
                                Text(mode.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No words yet")
                .font(.title3.weight(.semibold))
            Text("Practice words with your coach and they'll appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Word Entry model

struct WordEntry: Identifiable {
    var id: String { word }
    let word: String
    let bestScore: Double
    let lastScore: Double
    let avgScore: Double
    let attempts: Int
    let firstAt: Date
    let lastAt: Date

    var masteryColor: Color {
        switch bestScore {
        case 0.85...: return .green
        case 0.65...: return .orange
        default:      return .red
        }
    }

    var masteryLabel: String {
        switch bestScore {
        case 0.85...: return "Mastered"
        case 0.65...: return "Learning"
        default:      return "Struggling"
        }
    }
}

// MARK: - Row

private struct WordJournalRow: View {
    let entry: WordEntry

    private var lastAtLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(entry.lastAt) { return "Today" }
        if cal.isDateInYesterday(entry.lastAt) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: entry.lastAt)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: entry.bestScore)
                    .stroke(entry.masteryColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(entry.bestScore * 100))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(entry.masteryColor)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.word)
                    .font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    Text(entry.masteryLabel)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(entry.masteryColor.opacity(0.15))
                        .foregroundStyle(entry.masteryColor)
                        .clipShape(Capsule())
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(entry.attempts) attempt\(entry.attempts == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(lastAtLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if entry.attempts > 1 {
                    let trend = entry.lastScore - entry.avgScore
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0.02 ? "arrow.up" : trend <= -0.02 ? "arrow.down" : "minus")
                            .font(.caption2)
                        Text("avg \(Int(entry.avgScore * 100))%")
                            .font(.caption2)
                    }
                    .foregroundStyle(trend >= 0.02 ? Color.green : trend <= -0.02 ? Color.red : Color.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}
