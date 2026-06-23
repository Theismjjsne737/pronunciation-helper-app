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
        // f → p  (Korean, Japanese, Arabic)
        { t, h in t.contains("f") && !h.contains("f") && h.contains("p") ? ("f", "p") : nil },
        // z → s  (many L2 speakers)
        { t, h in t.contains("z") && !h.contains("z") && h.contains("s") ? ("z", "s") : nil },
        // sh → s  (Spanish, Italian, Portuguese)
        { t, h in t.contains("sh") && !h.contains("sh") ? ("sh", "s") : nil },
        // consonant cluster simplification  (str→s, bl→b, etc.)
        { t, h in
            let clusters = ["str", "spl", "spr", "bl", "br", "cl", "cr", "dr", "fl", "fr", "gl", "gr", "pl", "pr", "tr"]
            return clusters.contains(where: { t.contains($0) && !h.contains($0) })
                ? ("consonant-cluster", nil) : nil
        },
        // final -ng → -n  (Mandarin, Cantonese, Korean)
        { t, h in t.hasSuffix("ng") && h.hasSuffix("n") && !h.hasSuffix("ng") ? ("final-ng", "n") : nil },
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

        // Snapshot accuracy every 5 attempts for progress tracking
        for (phoneme, _) in detected {
            if let p = profile.phonemePatterns.first(where: { $0.phoneme == phoneme }),
               p.attemptCount % 5 == 0 {
                let entry = PhonemeProgressEntry(phoneme: phoneme, accuracy: p.accuracy, date: Date())
                profile.progressHistory.append(entry)
            }
        }
    }

    // MARK: - Seed profile from onboarding self-assessment

    func seedProfile(challenges: [String], nativeLanguage: String?, into profile: AccentProfile) {
        for phoneme in challenges {
            guard !profile.phonemePatterns.contains(where: { $0.phoneme == phoneme }) else { continue }
            var p = PhonemePattern(phoneme: phoneme, substitution: typicalSubstitution(phoneme: phoneme, language: nativeLanguage))
            p.attemptCount = 3
            p.errorCount = 2   // seeds at 33% accuracy — real practice quickly overrides
            profile.phonemePatterns.append(p)
        }
    }

    private func typicalSubstitution(phoneme: String, language: String?) -> String? {
        guard let lang = language else { return nil }
        switch (lang, phoneme) {
        case ("Spanish", "th"), ("Mandarin", "th"), ("Korean", "th"), ("Arabic", "th"): return "d"
        case ("French", "th"):  return "s"
        case ("German", "th"):  return "t"
        case ("Hindi", "th"):   return "t"
        case ("Mandarin", "r"), ("Japanese", "r"): return "l"
        case ("Japanese", "l"): return "r"
        case ("Spanish", "v"), ("Portuguese", "v"): return "b"
        case ("German", "w"):   return "v"
        case ("Hindi", "w"):    return "v"
        case ("Arabic", "p"):   return "b"
        case ("Korean", "f"), ("Japanese", "f"), ("Arabic", "f"): return "p"
        default: return nil
        }
    }

    // MARK: - Pattern detection (public for ViewModel use)

    func detectPatterns(target: String, heard: String) -> [(phoneme: String, sub: String?)] {
        PhonemeDetector.detect(target: target, heard: heard)
    }

    /// Runs phoneme detection across sentence pairs (expected vs transcribed).
    /// Used by the onboarding sentence assessment to prime the accent profile without a Claude call.
    func detectSentenceChallenges(expected: [String], transcriptions: [String]) -> [String] {
        let wordSeparators = CharacterSet.letters.inverted
        var detected: Set<String> = []
        for (exp, heard) in zip(expected, transcriptions) {
            let expWords   = exp.components(separatedBy: wordSeparators).filter { !$0.isEmpty }
            let heardWords = heard.components(separatedBy: wordSeparators).filter { !$0.isEmpty }
            for (t, h) in zip(expWords, heardWords) {
                PhonemeDetector.detect(target: t, heard: h).forEach { detected.insert($0.phoneme) }
            }
            // Full-sentence pass catches multi-word patterns (final consonants, clusters)
            PhonemeDetector.detect(target: exp, heard: heard).forEach { detected.insert($0.phoneme) }
        }
        return Array(detected)
    }

    // MARK: - Exercise data (public for ViewModel use)

    /// WHY explanation from native-language group + current technique based on error count.
    func exerciseTip(for phoneme: String, profile: AccentProfile) -> (why: String?, technique: String?) {
        let why: String? = profile.nativeLanguage.flatMap { lang in
            AccentGroupProfile.groups[lang]?.teachingHints[phoneme]
        }
        let technique: String? = {
            guard let techniques = Self.phonemeTechniques[phoneme] else { return nil }
            let pattern = profile.phonemePatterns.first { $0.phoneme == phoneme }
            let idx = min((pattern?.errorCount ?? 0) % 4, techniques.count - 1)
            return techniques[idx]
        }()
        return (why, technique)
    }

    /// Easiest-level drill words for a phoneme, or empty if none defined.
    func drillWords(for phoneme: String) -> [String] {
        Self.progressionWords[phoneme]?.first ?? []
    }

    // MARK: - Technique + progression data

    private static let phonemeTechniques: [String: [String]] = [
        "th": [
            "Mouth: tongue tip between front teeth, push air past — like blowing steam with your tongue peeking out",
            "Bridge: start from /d/ or /t/, then slide the tongue forward until it just touches the teeth tips",
            "Minimal pair drill: say 'den/then', 'dare/there', 'day/they' — feel the tongue shift",
            "Analogy: a sleepy snake poking its head through a fence — tongue out, air flowing past",
        ],
        "r": [
            "Mouth: curl tongue back slightly, float it — no contact with roof, sides, or teeth",
            "Bridge: start from /l/ position then retract without touching — the tongue hovers",
            "Minimal pair drill: 'led/red', 'glass/grass', 'collect/correct' — 5x each",
            "Analogy: tongue is a hawk gliding — wings slightly up, never landing",
        ],
        "v": [
            "Mouth: upper teeth lightly on lower lip edge, voice it — feel the buzz in your lip",
            "Bridge: find /f/ (same position) then switch your voice on — throat should vibrate",
            "Minimal pair drill: 'ban/van', 'best/vest', 'beer/veer'",
            "Analogy: /f/ is the car engine off, /v/ is the same car with engine running",
        ],
        "w": [
            "Mouth: tightly round lips as if about to whistle, then open into the vowel",
            "Bridge: start with 'oo' as in 'moon', then glide forward into the word",
            "Minimal pair drill: 'vine/wine', 'vent/went', 'vest/west'",
            "Analogy: your lips squeeze through a tiny hole first, then release",
        ],
        "l": [
            "Mouth: tongue tip taps the ridge just behind upper front teeth, air flows around sides",
            "Bridge: find /d/ — same tongue position, but let air flow past instead of stopping it",
            "Minimal pair drill: 'led/red', 'lice/rice', 'collect/correct'",
            "Analogy: tongue 'checks in' at the upper ridge for every /l/",
        ],
        "f": [
            "Mouth: upper teeth rest lightly on lower lip, push air — no voice, just friction",
            "Bridge: blow on hot soup but bite your lower lip slightly",
            "Minimal pair drill: 'pan/fan', 'pit/fit', 'past/fast'",
            "Analogy: a quiet cat-hiss escaping through the teeth-lip gap",
        ],
        "consonant-cluster": [
            "Slow drill: say each consonant alone first — 'S … T … R … eet', then compress",
            "Bridge: resist adding any vowel between — squeeze the consonants together like stacked bricks",
            "Speed ramp: 's-treet' → 'strEEt' → 'street', faster each pass",
            "Analogy: consonant clusters are a zipper — pull both sides together, no gap",
        ],
        "final-consonants": [
            "Hold: extend the final consonant a full beat — 'ca-T', 'sto-P', 'bi-G'",
            "Bridge: tap a finger on the table for every final consonant as you say it",
            "Drill: say the word, then say it again holding the ending 2 seconds",
            "Analogy: the final consonant is a door — you must close it fully, not leave it ajar",
        ],
        "p": [
            "Mouth: lips together, build pressure, release with a small puff — no voice before the release",
            "Bridge: /b/ is the voiced version — find /b/, then turn the voice off",
            "Minimal pair drill: 'ban/pan', 'bat/pat', 'bin/pin'",
            "Analogy: a tiny balloon pop — pressure builds, then bursts",
        ],
        "tones": [
            "English uses stress, not tones — 'content words' (nouns, verbs) get louder and slightly higher; try spotlighting one word: 'I WANT coffee' vs 'I want COFFEE' — completely different emphasis",
            "Question vs statement pitch: say 'You're coming?' — voice rises on 'coming'. Then 'You're coming.' — voice falls. Same words, opposite pitch shape",
            "Bridge: Mandarin tone 2 (rising) maps to English question intonation — 'Really?' ends like Tone 2. Use that natural rise at the end of yes/no questions only",
            "Analogy: Mandarin tones are traffic lights (fixed rule per syllable); English stress is a spotlight — you choose which word to illuminate each sentence",
        ],
        "schwa": [
            "Find 'uh' — open your mouth slightly, relax everything, make the laziest vowel possible. That's the schwa /ə/. Every unstressed English syllable wants this sound",
            "Bridge: say 'banana' — stress on the middle: buh-NA-nuh. First and last syllables collapse to schwa. Find the stressed syllable first, then let the others go flat",
            "Drill: 'the cat' = 'thuh cat', 'a dog' = 'uh dog', 'about' = 'uh-BOUT', 'sofa' = 'SO-fuh' — schwa always hides in the syllable that gets the least attention",
            "Analogy: schwa is the mumbled pause between thoughts — English speech is intentionally lazy with unstressed syllables; it's not sloppy, it's correct",
        ],
    ]

    private static let progressionWords: [String: [[String]]] = [
        "th": [["this", "that", "the"], ["threshold", "through", "weather"], ["thirteenth", "throughout", "otherwise"]],
        "r":  [["red", "run", "right"], ["rural", "rarely", "mirror"], ["particularly", "extraordinary", "entrepreneur"]],
        "v":  [["very", "van", "voice"], ["vivid", "involve", "evolve"], ["provocative", "innovative", "overwhelming"]],
        "l":  [["led", "let", "lip"], ["really", "already", "carefully"], ["relatively", "particularly", "syllable"]],
        "w":  [["win", "wet", "way"], ["whether", "always", "reward"], ["overwhelm", "worthwhile", "worldwide"]],
        "f":  [["fan", "fit", "fast"], ["affect", "effort", "different"], ["effectively", "furthermore", "sufficiently"]],
        "consonant-cluster": [["stop", "play", "free"], ["street", "strong", "splash"], ["extraordinary", "strengths", "scripts"]],
    ]

    private func adaptiveTechniqueSection(for profile: AccentProfile) -> String {
        let challenges = profile.topChallenges.prefix(3)
        guard !challenges.isEmpty else { return "" }

        var lines = ["## Adaptive Teaching Techniques", ""]
        for pattern in challenges {
            guard let techniques = Self.phonemeTechniques[pattern.phoneme] else { continue }
            let idx = min(pattern.errorCount % 4, techniques.count - 1)
            lines.append("'\(pattern.phoneme)' — \(pattern.errorCount) errors, \(Int(pattern.accuracy * 100))% accuracy")
            lines.append("  → USE: \(techniques[idx])")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private func progressionSection(for profile: AccentProfile) -> String {
        let mastered = profile.phonemePatterns.filter { $0.accuracy >= 0.80 && $0.attemptCount >= 4 }
        guard !mastered.isEmpty else { return "" }

        var lines = ["## Difficulty Progression (phonemes the user is mastering)", ""]
        for pattern in mastered {
            guard let levels = Self.progressionWords[pattern.phoneme] else { continue }
            let currentLevel = min(Int(pattern.accuracy * 100) / 33, levels.count - 1)
            let next = currentLevel + 1 < levels.count ? levels[currentLevel + 1] : levels.last!
            lines.append("'\(pattern.phoneme)' at \(Int(pattern.accuracy * 100))% — suggest next-level words: \(next.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
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
        let techniqueSection = adaptiveTechniqueSection(for: profile)
        let progressionSection = progressionSection(for: profile)

        let nativeRef = profile.nativeLanguage.map { "For \($0) speakers, " } ?? ""

        let adaptiveSections = [techniqueSection, progressionSection]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let challengesLine = challengesText.isEmpty ? "" : "\nChallenges: \(challengesText)"
        let adaptiveLine = adaptiveSections.isEmpty ? "" : "\n\(adaptiveSections)"
        return """
        You are Mimiq, a pronunciation coach. \(nativeLine).\(challengesLine)\(adaptiveLine)

        Rules:
        - Warm, concise (≤120 words). Phonetics in [BRACKETS]: [WIN], [WUSS-ter].
        - Word/name asked: give [phonetic], brief why, end with [RECORD: word] on its own line.
        - After attempt ("Recorded 'X'. Heard: 'Y'. Score: Z%"): name what you heard, one fix, re-invite [RECORD: word] if <85%. ≥85%: celebrate, suggest harder variant.
        - MILESTONE in message: lead with excitement + exact numbers first.
        - ONE [RECORD: word] per message, exact word, own line, only when inviting practice.
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
