import Foundation
import SwiftData

// MARK: - Known phoneme substitution patterns (heuristic detector)

private enum PhonemeDetector {

    typealias Detector = (_ target: String, _ heard: String) -> (phoneme: String, sub: String?)?

    static let all: [Detector] = [
        // th → d  (Spanish, Korean, Mandarin)
        { t, h in t.contains("th") && !h.contains("th") && h.contains("d") ? ("th", "d") : nil },
        { t, h in t.contains("th") && !h.contains("th") && h.contains("t") ? ("th", "t") : nil },
        // th → s  (French, Greek)
        { t, h in t.contains("th") && !h.contains("th") && h.contains("s") ? ("th", "s") : nil },
        // r → l  (East Asian)
        { t, h in t.contains("r") && !t.contains("l") && h.contains("l") ? ("r", "l") : nil },
        // l → r
        { t, h in t.contains("l") && !t.contains("r") && h.contains("r") ? ("l", "r") : nil },
        // v → b  (Spanish, Punjabi)
        { t, h in t.contains("v") && !h.contains("v") && h.contains("b") ? ("v", "b") : nil },
        // w → v  (German, Hindi)
        { t, h in t.contains("w") && !h.contains("w") && h.contains("v") ? ("w", "v") : nil },
        // silent h  (Spanish, French)
        { t, h in (t.hasPrefix("h") || t.contains(" h")) && !h.contains("h") ? ("h", nil) : nil },
        // p → b  (Arabic)
        { t, h in t.contains("p") && !h.contains("p") && h.contains("b") ? ("p", "b") : nil },
        // final consonant dropped  (Mandarin, Japanese)
        { t, h in
            guard !t.isEmpty, !h.isEmpty else { return nil }
            let finalConsonants = Set("ptksdbgmnlr")
            return finalConsonants.contains(t.last!) && !finalConsonants.contains(h.last!)
                ? ("final-consonants", nil) : nil
        },
    ]

    static func detect(target: String, heard: String) -> [(phoneme: String, sub: String?)] {
        let t = target.lowercased(), h = heard.lowercased()
        return all.compactMap { $0(t, h) }
    }
}

// MARK: - Service

@MainActor
final class AccentProfileService {

    // MARK: - Profile update

    func record(
        targetWord: String,
        transcription: String,
        score: Double,
        into profile: AccentProfile
    ) {
        let detected = PhonemeDetector.detect(target: targetWord, heard: transcription)
        let isMistake = score < 0.75

        for (phoneme, sub) in detected {
            if let idx = profile.phonemePatterns.firstIndex(where: { $0.phoneme == phoneme }) {
                profile.phonemePatterns[idx].attemptCount += 1
                if isMistake { profile.phonemePatterns[idx].errorCount += 1 }
                if sub != nil { profile.phonemePatterns[idx].substitution = sub }
            } else {
                var p = PhonemePattern(phoneme: phoneme, substitution: sub)
                p.attemptCount = 1
                if isMistake { p.errorCount = 1 }
                profile.phonemePatterns.append(p)
            }
        }

        profile.totalPracticeWords += 1
        profile.lastUpdatedAt = Date()
    }

    // MARK: - Pattern detection (public for ViewModel use)

    func detectPatterns(target: String, heard: String) -> [(phoneme: String, sub: String?)] {
        PhonemeDetector.detect(target: target, heard: heard)
    }

    // MARK: - System prompt

    func buildSystemPrompt(for profile: AccentProfile) -> String {
        let nativeLine: String
        if let lang = profile.nativeLanguage {
            nativeLine = "Native language: \(lang)"
        } else {
            nativeLine = "Native language: not specified — I'll learn patterns as we practise."
        }

        let challengesText = profile.challengeSummary

        let nativeRef = profile.nativeLanguage.map { "For \($0) speakers, " } ?? ""

        return """
        You are Mimiq, a conversational pronunciation coach accessed via chat.
        Users ask you about any word, name, or phrase they want to pronounce correctly.

        ## User Accent Profile
        \(nativeLine)
        Sessions: \(profile.totalSessions) | Words practised: \(profile.totalPracticeWords)

        ## Known Phoneme Challenges
        \(challengesText)

        ## Your Personality
        - Like a patient, knowledgeable friend — warm, encouraging, never condescending
        - Concise: under 130 words per response unless doing a full breakdown
        - Use phonetic spelling in [BRACKETS]: [WIN] for Nguyen, [WUSS-ter] for Worcester
        - Never say "mispronounced" — say "how it came out" or "what I heard"

        ## When a User Asks About a Word or Name
        1. Give the actual pronunciation in phonetic brackets: "It's [WIN]"
        2. Briefly explain why (silent letters, syllable compression, origin)
        3. \(nativeRef)reference their language background if relevant
        4. Always invite them to try — end your message with exactly: [RECORD: exact_word]

        Example:
        User: "How do I say Nguyen?"
        You: "Nguyen is a Vietnamese name — in English it's almost always said as [WIN], just like the word 'win'. The 'Ngu' and 'ye' are swallowed completely. \(nativeRef)the tricky part is trusting how short it really is. Give it a go:
        [RECORD: Nguyen]"

        ## After a Pronunciation Attempt
        You'll receive: "User recorded 'X'. I heard: 'Y'. Score: Z%."
        It may also include:
        - "Detected pattern: th→d" — the exact phoneme substitution that just occurred
        - "Session so far: N words, X% average" — how this session is going
        - "MILESTONE: ..." — a breakthrough moment that MUST be celebrated first, before anything else

        When a MILESTONE is present: lead with genuine excitement about their improvement. Name the numbers ("you went from 42% to 78%!"). Then continue with normal feedback.

        For the phoneme feedback:
        1. What you noticed — specific, not generic ("I heard 'wor-chest-er' rather than [WUSS-ter]")
        2. WHY it happened — name the pattern if detected ("That's the th→d swap we've been tackling")
        3. ONE concrete technique matching the Known Phoneme Challenges hint for that pattern
        4. Score ≥ 85%: celebrate + suggest a harder variant ("Want to try 'throughout' next — same sound, harder context?")
           Score 60–84%: encourage, one specific fix, end with [RECORD: word]
           Score < 60%: slow down, break the word into syllables, give a bridge word, end with [RECORD: word]

        Vary your encouragement — never use the exact same phrasing twice in a session.

        ## Rules for [RECORD: word]
        - Use it when you genuinely want to hear them speak — not in general conversation
        - Put the EXACT word/phrase the user should say inside it
        - Only ONE per message
        - Place it on its own line at the end of your message
        """
    }

    // MARK: - Welcome message

    func welcomeMessage(for profile: AccentProfile) -> String {
        if profile.totalSessions == 0 {
            return "Hi! I'm your pronunciation coach. Ask me about any word, name, or phrase — type something like \"How do I say Nguyen?\" and we'll work through it together. 🎙"
        }
        let challenges = profile.topChallenges.prefix(2).map { "'\($0.phoneme)'" }.joined(separator: " and ")
        if !challenges.isEmpty {
            return "Welcome back! Last time we were working on \(challenges). Want to keep practising, or try a new word?"
        }
        return "Welcome back! What word or name would you like to nail today?"
    }
}
