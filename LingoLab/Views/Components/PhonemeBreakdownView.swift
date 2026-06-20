import SwiftUI

/// Horizontal row of colour-coded syllable chips with score bars.
struct PhonemeBreakdownView: View {

    let scores: [PhonemeScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(scores) { ps in
                        PhonemeChip(score: ps)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Legend
            HStack(spacing: 16) {
                LegendDot(color: .green,  label: "Good (≥ 70%)")
                LegendDot(color: .orange, label: "Fair (40–69%)")
                LegendDot(color: .red,    label: "Needs work (< 40%)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Chip

private struct PhonemeChip: View {
    let score: PhonemeScore

    var body: some View {
        VStack(spacing: 4) {
            Text(score.phoneme)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(chipColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(chipColor, lineWidth: 1.5)
                )

            if let ipa = score.ipaSymbol {
                Text(ipa)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text("\(Int(score.score * 100))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(chipColor)
        }
    }

    private var chipColor: Color {
        switch score.score {
        case 0.7...: return .green
        case 0.4..<0.7: return .orange
        default: return .red
        }
    }
}

// MARK: - Legend dot

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}

#Preview {
    PhonemeBreakdownView(scores: [
        PhonemeScore(phoneme: "pro",  ipaSymbol: "/prəʊ/", score: 0.92, startTime: 0,   endTime: 0.3),
        PhonemeScore(phoneme: "nun",  ipaSymbol: "/nʌn/",  score: 0.65, startTime: 0.3, endTime: 0.6),
        PhonemeScore(phoneme: "ci",   ipaSymbol: nil,       score: 0.45, startTime: 0.6, endTime: 0.8),
        PhonemeScore(phoneme: "a",    ipaSymbol: nil,       score: 0.30, startTime: 0.8, endTime: 1.0),
        PhonemeScore(phoneme: "tion", ipaSymbol: "/ʃən/",  score: 0.88, startTime: 1.0, endTime: 1.4),
    ])
    .padding()
    .background(Color(.systemGroupedBackground))
}
