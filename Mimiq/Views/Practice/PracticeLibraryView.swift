import SwiftUI
import SwiftData

struct PracticeLibraryView: View {

    @ObservedObject var vm: PracticeViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var savedWords: [SavedWord]

    @State private var selectedCategory: PracticeCategory? = nil
    @State private var selectedDifficulty: PracticeDifficulty? = nil
    @State private var showSavedOnly = false

    private var filtered: [PracticeItem] {
        let base = showSavedOnly
            ? PracticeItem.library.filter { item in savedWords.contains { $0.word == item.word } }
            : PracticeItem.library
        return base.filter { item in
            (selectedCategory == nil || item.category == selectedCategory) &&
            (selectedDifficulty == nil || item.difficulty == selectedDifficulty)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader
            categoryPicker
            difficultyPicker
            if filtered.isEmpty {
                emptyState
            } else {
                itemGrid
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Label("Practice Library", systemImage: "books.vertical.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.indigo)
            Spacer()
            Text("\(filtered.count) words")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Category chips

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(label: "All", icon: "square.grid.2x2", color: .indigo, isSelected: selectedCategory == nil && !showSavedOnly) {
                    selectedCategory = nil
                    showSavedOnly = false
                }
                CategoryChip(label: "Saved", icon: "bookmark.fill", color: .purple, isSelected: showSavedOnly) {
                    showSavedOnly.toggle()
                    if showSavedOnly { selectedCategory = nil }
                }
                ForEach(PracticeCategory.allCases) { cat in
                    CategoryChip(label: cat.rawValue, icon: cat.icon, color: cat.color, isSelected: selectedCategory == cat) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Difficulty pills

    private var difficultyPicker: some View {
        HStack(spacing: 8) {
            ForEach(PracticeDifficulty.allCases) { diff in
                DifficultyPill(difficulty: diff, isSelected: selectedDifficulty == diff) {
                    selectedDifficulty = selectedDifficulty == diff ? nil : diff
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Grid

    private var itemGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filtered) { item in
                WordCard(item: item, vm: vm,
                         isSaved: savedWords.contains { $0.word == item.word },
                         onToggleSave: {
                    if let existing = savedWords.first(where: { $0.word == item.word }) {
                        modelContext.delete(existing)
                    } else {
                        modelContext.insert(SavedWord(word: item.word))
                    }
                    try? modelContext.save()
                })
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No words match your filters")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .foregroundStyle(isSelected ? .white : color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(isSelected ? 0 : 0.4), lineWidth: 1))
        }
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: - DifficultyPill

private struct DifficultyPill: View {
    let difficulty: PracticeDifficulty
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(difficulty.label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? difficulty.color : Color(.tertiarySystemFill))
                .foregroundStyle(isSelected ? .white : .secondary)
                .clipShape(Capsule())
        }
        .animation(.spring(duration: 0.2), value: isSelected)
    }
}

// MARK: - WordCard

private struct WordCard: View {

    let item: PracticeItem
    @ObservedObject var vm: PracticeViewModel
    let isSaved: Bool
    let onToggleSave: () -> Void

    private var isPreviewPlaying: Bool { vm.previewingWord == item.word }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 4) {
                Image(systemName: item.category.icon).font(.caption2)
                Text(item.difficulty.label).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(item.difficulty.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(item.difficulty.color.opacity(0.12))
            .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.word)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Text(item.phonetic)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let tip = item.tip {
                Text(tip)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    vm.preview(item.word)
                } label: {
                    Image(systemName: isPreviewPlaying ? "speaker.wave.2.fill" : "play.fill")
                        .font(.caption)
                        .foregroundStyle(item.category.color)
                        .frame(width: 30, height: 30)
                        .background(item.category.color.opacity(0.12))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Hear \(item.word)")

                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.caption)
                        .foregroundStyle(isSaved ? .purple : .secondary)
                        .frame(width: 30, height: 30)
                        .background(isSaved ? Color.purple.opacity(0.12) : Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .accessibilityLabel(isSaved ? "Remove from saved" : "Save \(item.word)")

                Button {
                    vm.select(item)
                } label: {
                    Text("Practice")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.indigo)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
