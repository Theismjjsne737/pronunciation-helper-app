import Foundation
import SwiftData

// MARK: - Phoneme pattern (tracked per phoneme)

struct PhonemePattern: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    let phoneme: String         // e.g. "th", "r", "v"
    var substitution: String?   // e.g. "d", "l", "b" — what user says instead
    var errorCount: Int = 0
    var attemptCount: Int = 0

    var accuracy: Double {
        attemptCount > 0 ? 1.0 - Double(errorCount) / Double(attemptCount) : 0.5
    }
}

// MARK: - Phoneme tier classification

enum PhonemeTier: String {
    case mastered   = "Mastered"
    case developing = "Developing"
    case challenge  = "Needs Work"
}

// MARK: - Accent group fingerprint

/// Known challenge patterns per native-language group.
/// Used to prime the accent profile before we have enough data to learn organically.
struct AccentGroupProfile {
    let name: String
    let commonChallenges: [String]      // phoneme labels
    let teachingHints: [String: String] // phoneme → hint for Claude prompt

    static let groups: [String: AccentGroupProfile] = [
        "Spanish": AccentGroupProfile(
            name: "Spanish",
            commonChallenges: ["v", "b", "th", "h", "schwa"],
            teachingHints: [
                "v":  "Spanish merges /v/ and /b/ — try touching your top teeth to your lower lip",
                "th": "Spanish lacks the /θ/ sound — place your tongue between your teeth",
                "h":  "Spanish 'h' is silent — English 'h' needs a puff of air from the throat"
            ]
        ),
        "Mandarin": AccentGroupProfile(
            name: "Mandarin",
            commonChallenges: ["r", "th", "final-consonants", "tones"],
            teachingHints: [
                "r":               "Mandarin /r/ is very different — curl your tongue up without touching the roof",
                "th":              "Replace with /d/ or /s/ and then gradually add tongue-tip placement",
                "final-consonants":"Mandarin syllables rarely end in consonants — hold the final sound a beat longer"
            ]
        ),
        "French": AccentGroupProfile(
            name: "French",
            commonChallenges: ["h", "w", "th", "nasal-vowels"],
            teachingHints: [
                "h":  "French 'h' is always silent — English 'h' needs a breathy /h/ sound",
                "w":  "French /w/ exists only in loanwords — practice with 'win', 'wet', 'west'",
                "th": "French lacks /θ/ — try /s/ first then move tongue to teeth"
            ]
        ),
        "German": AccentGroupProfile(
            name: "German",
            commonChallenges: ["w", "v", "th", "schwa"],
            teachingHints: [
                "w":  "German 'w' sounds like English 'v' — round your lips for the English /w/",
                "th": "German lacks /θ/ — tongue tip touches the back of upper teeth"
            ]
        ),
        "Japanese": AccentGroupProfile(
            name: "Japanese",
            commonChallenges: ["l", "r", "v", "final-consonants", "consonant-clusters"],
            teachingHints: [
                "l":                  "Japanese /r/ is between English /r/ and /l/ — tap tongue briefly behind upper teeth",
                "v":                  "Japanese lacks /v/ — bite your lower lip lightly and push air through",
                "consonant-clusters": "Japanese inserts vowels between consonants — suppress the extra vowel: 'su-to-raiku' → 'strike'"
            ]
        ),
        "Korean": AccentGroupProfile(
            name: "Korean",
            commonChallenges: ["f", "v", "th", "r-l", "consonant-clusters"],
            teachingHints: [
                "f":  "Korean lacks /f/ — upper teeth to lower lip, feel the air friction",
                "v":  "Korean lacks /v/ — same position as /f/ but add voice",
                "th": "Not in Korean — tongue between teeth, soft push of air"
            ]
        ),
        "Arabic": AccentGroupProfile(
            name: "Arabic",
            commonChallenges: ["p", "v", "schwa", "w-v"],
            teachingHints: [
                "p":  "Arabic has no /p/ — it's like /b/ but unvoiced, no throat vibration",
                "v":  "Arabic lacks /v/ — upper teeth to lower lip with voiced air"
            ]
        ),
        "Hindi": AccentGroupProfile(
            name: "Hindi",
            commonChallenges: ["w", "v", "th", "retroflex"],
            teachingHints: [
                "w":  "Hindi /v/ is used where English uses /w/ — round your lips more",
                "th": "Hindi 'th' is aspirated /tʰ/, not the dental /θ/ — touch tongue to teeth"
            ]
        ),
    ]
}

// MARK: - Phoneme progress snapshot (for progress tracking over time)

struct PhonemeProgressEntry: Codable, Identifiable {
    var id = UUID()
    var phoneme: String
    var accuracy: Double
    var date: Date
}

// MARK: - Accent Profile model

@Model
final class AccentProfile {
    @Attribute(.unique) var id: UUID
    var nativeLanguage: String?                 // User-selected or inferred
    var phonemePatterns: [PhonemePattern]       // Learned over time
    var progressHistory: [PhonemeProgressEntry] // Accuracy snapshots every 5 attempts
    var totalPracticeWords: Int
    var totalSessions: Int
    var onboardingCompleted: Bool
    var createdAt: Date
    var lastUpdatedAt: Date

    init() {
        self.id = UUID()
        self.phonemePatterns = []
        self.progressHistory = []
        self.totalPracticeWords = 0
        self.totalSessions = 0
        self.onboardingCompleted = false
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
    }

    // MARK: - Helpers

    /// Top phoneme challenges by error rate (worst first)
    var topChallenges: [PhonemePattern] {
        phonemePatterns
            .filter { $0.attemptCount >= 2 }
            .sorted { $0.accuracy < $1.accuracy }
            .prefix(5)
            .map { $0 }
    }

    /// Human-readable challenge summary for the Claude system prompt
    var challengeSummary: String {
        let learnedChallenges = topChallenges.map { p -> String in
            let sub = p.substitution.map { " (says '\($0)' instead)" } ?? ""
            return "'\(p.phoneme)'\(sub): \(Int(p.accuracy * 100))% accuracy"
        }

        var hints: [String] = []
        if let lang = nativeLanguage,
           let group = AccentGroupProfile.groups[lang] {
            hints = group.commonChallenges.compactMap { ph in
                group.teachingHints[ph].map { "\(ph): \($0)" }
            }
        }

        var parts: [String] = []
        if !learnedChallenges.isEmpty {
            parts.append("Learned from practice:\n" + learnedChallenges.joined(separator: "\n"))
        }
        if !hints.isEmpty {
            parts.append("Known \(nativeLanguage ?? "accent") patterns:\n" + hints.joined(separator: "\n"))
        }
        return parts.isEmpty ? "No accent data yet — learning organically." : parts.joined(separator: "\n\n")
    }

    /// Phoneme patterns grouped into mastered / developing / challenge tiers
    var phonemeTiers: [(tier: PhonemeTier, patterns: [PhonemePattern])] {
        let tracked = phonemePatterns.filter { $0.attemptCount >= 1 }
        let mastered    = tracked.filter { $0.accuracy >= 0.80 }.sorted { $0.accuracy > $1.accuracy }
        let developing  = tracked.filter { $0.accuracy >= 0.55 && $0.accuracy < 0.80 }.sorted { $0.accuracy < $1.accuracy }
        let challenge   = tracked.filter { $0.accuracy < 0.55 }.sorted { $0.accuracy < $1.accuracy }
        return [(.mastered, mastered), (.developing, developing), (.challenge, challenge)]
            .filter { !$0.patterns.isEmpty }
    }

    /// Language label shown in UI
    var languageLabel: String { nativeLanguage ?? "Not specified" }
}
