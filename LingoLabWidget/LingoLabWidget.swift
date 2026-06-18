import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let practicedToday: Bool
    let longestStreak: Int
}

// MARK: - Provider

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 7, practicedToday: true, longestStreak: 14)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        // Refresh at midnight so the "practiced today" dot resets
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
        completion(Timeline(entries: [entry()], policy: .after(midnight)))
    }

    private func entry() -> StreakEntry {
        let defaults = UserDefaults(suiteName: "group.com.yourname.lingolab") ?? .standard
        let streak   = defaults.integer(forKey: "streak_current")
        let longest  = defaults.integer(forKey: "streak_longest")
        let practiced: Bool = {
            guard let last = defaults.object(forKey: "streak_last_date") as? Date else { return false }
            return Calendar.current.isDateInToday(last)
        }()
        return StreakEntry(date: Date(), streak: streak, practicedToday: practiced, longestStreak: longest)
    }
}

// MARK: - Small widget view

struct StreakWidgetView: View {
    let entry: StreakEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:  smallView
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    // Small: flame + streak number + CTA
    private var smallView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                Text("🔥")
                    .font(.system(size: 26))
            }

            Text(entry.streak > 0 ? "\(entry.streak)" : "0")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(entry.streak > 0 ? .orange : .secondary)

            Text(entry.streak == 1 ? "day streak" : "day streak")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(entry.practicedToday ? "✓ Done today" : "Tap to practise")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(entry.practicedToday ? .green : .indigo)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((entry.practicedToday ? Color.green : Color.indigo).opacity(0.12))
                .clipShape(Capsule())
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "lingolab://practice"))
    }

    // Medium: flame + streak + week dots + stats
    private var mediumView: some View {
        HStack(spacing: 20) {
            // Left: flame + count
            VStack(spacing: 4) {
                Text("🔥").font(.system(size: 40))
                Text("\(entry.streak)")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(entry.streak > 0 ? .orange : .secondary)
                Text("day streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Right: stats + CTA
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill").font(.caption).foregroundStyle(.yellow)
                    Text("Best: \(entry.longestStreak) days")
                        .font(.caption.weight(.medium))
                }

                HStack(spacing: 6) {
                    Image(systemName: entry.practicedToday ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(entry.practicedToday ? .green : .secondary)
                    Text(entry.practicedToday ? "Practised today" : "Not practised yet")
                        .font(.caption)
                        .foregroundStyle(entry.practicedToday ? .green : .secondary)
                }

                if !entry.practicedToday {
                    Text("Tap to keep your streak →")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.indigo)
                }
            }

            Spacer()
        }
        .padding(16)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "lingolab://practice"))
    }
}

// MARK: - Widget configuration

struct LingoLabStreakWidget: Widget {
    let kind = "LingoLabStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Practice Streak")
        .description("Keep your daily pronunciation streak alive.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget bundle (supports multiple widgets)

@main
struct LingoLabWidgetBundle: WidgetBundle {
    var body: some Widget {
        LingoLabStreakWidget()
    }
}
