import SwiftUI
import Charts

struct PracticeResultView: View {

    let word: String
    let result: AnalysisResult
    let wordHistory: [Double]       // 0–1 scores, chronological, current attempt included
    @ObservedObject var vm: PracticeViewModel

    @State private var revealScore = false

    private var weakestPhoneme: PhonemeScore? {
        result.phonemeScores.min(by: { $0.score < $1.score })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                scoreCard
                    .padding(.horizontal, 20)

                if wordHistory.count >= 2 {
                    wordHistoryChart
                        .padding(.horizontal, 20)
                }

                if let worst = weakestPhoneme, worst.score < 0.8 {
                    focusAreaCard(worst)
                        .padding(.horizontal, 20)
                }

                if !result.phonemeScores.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Sound Breakdown", systemImage: "list.bullet.rectangle")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 20)
                        PhonemeBreakdownView(scores: result.phonemeScores)
                            .padding(.horizontal, 20)
                    }
                }

                waveformCard
                    .padding(.horizontal, 20)

                actionsCard
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5).delay(0.15)) { revealScore = true }
            ReviewService.shared.recordGoodScore(result.score)
        }
    }

    // MARK: - Score card

    private var scoreCard: some View {
        VStack(spacing: 20) {
            Text(word)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            ScoreGaugeView(score: revealScore ? result.score : 0, size: 110)

            VStack(spacing: 6) {
                Text(result.scoreLabel)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(scoreColor(result.score))
                Text(result.feedbackMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !result.transcription.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "ear.fill").font(.caption).foregroundStyle(.secondary)
                    Text("I heard:").font(.caption).foregroundStyle(.secondary)
                    Text("\"\(result.transcription)\"").font(.caption.weight(.medium)).italic()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // MARK: - Word history chart

    private var wordHistoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Your Progress on \"\(word)\"", systemImage: "chart.line.uptrend.xyaxis")
                .font(.subheadline.weight(.semibold))

            let points = wordHistory.enumerated().map { ($0.offset, $0.element * 100) }

            Chart {
                ForEach(points, id: \.0) { i, score in
                    LineMark(
                        x: .value("Attempt", i + 1),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(Color.indigo.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Attempt", i + 1),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(Color.indigo.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Attempt", i + 1),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(i == points.count - 1 ? Color.indigo : Color.indigo.opacity(0.4))
                    .symbolSize(i == points.count - 1 ? 60 : 30)
                }

                RuleMark(y: .value("Good", 75))
                    .foregroundStyle(Color.green.opacity(0.5))
                    .lineStyle(StrokeStyle(dash: [4]))
                    .annotation(position: .trailing) {
                        Text("75%").font(.caption2).foregroundStyle(.green)
                    }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) {
                    AxisValueLabel().font(.caption2)
                }
            }
            .frame(height: 110)

            Text("\(wordHistory.count) attempt\(wordHistory.count == 1 ? "" : "s") · Latest: \(Int((wordHistory.last ?? 0) * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Focus area card

    private func focusAreaCard(_ phoneme: PhonemeScore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Focus Area", systemImage: "target")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(phoneme.phoneme)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(Int(phoneme.score * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.orange)
                }
                .frame(width: 72, height: 72)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Weakest syllable")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(articulationTip(for: phoneme.phoneme))
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Button {
                vm.speakNative(slowly: true)
            } label: {
                Label("Hear the word slowly", systemImage: "tortoise.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Waveform comparison

    private var waveformCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Waveform Comparison", systemImage: "waveform")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Native").font(.caption.weight(.medium)).foregroundStyle(.indigo)
                StaticWaveformView(samples: idealWaveform(count: 60), color: .indigo.opacity(0.5))
                    .frame(height: 36)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("You").font(.caption.weight(.medium)).foregroundStyle(.red)
                StaticWaveformView(samples: vm.capturedSamples, color: .red.opacity(0.7))
                    .frame(height: 36)
                Button { vm.playRecording() } label: {
                    Label("Replay your recording", systemImage: "play.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button { vm.tryAgain() } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            HStack(spacing: 10) {
                Button { vm.newWord() } label: {
                    Text("New Word")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.indigo.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    shareScoreCard(word: word, score: result.score, transcription: result.transcription)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.48, green: 0.33, blue: 1.0))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(red: 0.48, green: 0.33, blue: 1.0).opacity(0.25), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 0.9...:      return .green
        case 0.75..<0.9:  return .blue
        case 0.55..<0.75: return .orange
        default:          return .red
        }
    }

    private func idealWaveform(count: Int) -> [Float] {
        (0..<count).map { i in
            let t = Float(i) / Float(count)
            let v = sin(t * .pi * 6) * 0.4 + sin(t * .pi * 11) * 0.25
            return max(0.1, min(1.0, abs(v) + 0.15))
        }
    }

    private func articulationTip(for syllable: String) -> String {
        let s = syllable.lowercased()
        if s.contains("th") {
            return "Place your tongue between your upper and lower teeth for the 'th' sound."
        } else if s.contains("r") && !s.contains("l") {
            return "Curl your tongue back slightly — don't let it touch the roof of your mouth."
        } else if s.contains("l") && !s.contains("r") {
            return "Touch your tongue tip to the ridge just behind your upper teeth."
        } else if s.contains("w") {
            return "Round your lips into a tight circle before releasing into the vowel."
        } else if s.contains("v") || s.contains("f") {
            return "Bring your upper teeth to your lower lip and let air escape through."
        } else {
            return "Slow down on this syllable, over-articulate it, then blend back in at normal speed."
        }
    }
}
