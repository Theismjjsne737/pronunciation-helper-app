import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Live Activity Views (used in the Widget Extension target)
// Requires: Target → Capabilities → Live Activities enabled

struct RecordingLiveActivityView: View {
    let state: RecordingActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            // Phase icon
            ZStack {
                Circle()
                    .fill(phaseColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: phaseIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(phaseColor)
                    .symbolEffect(.variableColor.iterative, isActive: state.phase == .recording)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(state.targetWord)
                    .font(.headline)
                    .lineLimit(1)
                Text(phaseLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let score = state.score {
                VStack(spacing: 0) {
                    Text("\(Int(score * 100))%")
                        .font(.title2.weight(.black))
                        .foregroundStyle(scoreColor(score))
                    Text("score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var phaseIcon: String {
        switch state.phase {
        case .recording:  return "waveform.and.mic"
        case .analyzing:  return "gearshape.2"
        case .complete:   return "checkmark.seal.fill"
        }
    }

    private var phaseColor: Color {
        switch state.phase {
        case .recording:  return .red
        case .analyzing:  return .orange
        case .complete:   return scoreColor(state.score ?? 0)
        }
    }

    private var phaseLabel: String {
        switch state.phase {
        case .recording:  return "Recording…"
        case .analyzing:  return "Analysing pronunciation…"
        case .complete:
            if let heard = state.transcription { return "I heard: \"\(heard)\"" }
            return "Analysis complete"
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.9...: return .green
        case 0.75..<0.9: return .blue
        case 0.55..<0.75: return .orange
        default: return .red
        }
    }
}

// MARK: - Live Activity widget (add to Widget Extension target)

struct LingoLabLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock screen / banner view
            RecordingLiveActivityView(state: context.state)
                .activityBackgroundTint(Color(.systemBackground))
                .activitySystemActionForegroundColor(.indigo)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.phase == .recording ? "waveform.and.mic" : "gearshape.2")
                        .font(.title2)
                        .foregroundStyle(context.state.phase == .recording ? .red : .orange)
                        .symbolEffect(.variableColor.iterative, isActive: context.state.phase == .recording)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let score = context.state.score {
                        Text("\(Int(score * 100))%")
                            .font(.title.weight(.black))
                            .foregroundStyle(score >= 0.9 ? .green : score >= 0.6 ? .blue : .orange)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.targetWord)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.phase == .recording ? "Recording… tap Done when finished"
                         : context.state.phase == .analyzing ? "Scoring your pronunciation…"
                         : "Check the app for detailed feedback")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "waveform.and.mic")
                    .foregroundStyle(.red)
                    .symbolEffect(.variableColor.iterative, isActive: context.state.phase == .recording)
            } compactTrailing: {
                if let score = context.state.score {
                    Text("\(Int(score * 100))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(score >= 0.75 ? .green : .orange)
                } else {
                    ProgressView().scaleEffect(0.6).tint(.orange)
                }
            } minimal: {
                Image(systemName: context.state.phase == .complete ? "checkmark.circle.fill" : "waveform.and.mic")
                    .foregroundStyle(context.state.phase == .complete ? .green : .red)
            }
        }
    }
}
