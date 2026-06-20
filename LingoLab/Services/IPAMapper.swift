import Foundation

/// Pattern-based English phoneme → IPA mapper.
/// Two modes:
///   1. `ipa(for:)` — library lookup via PracticeItem.phonetic strings
///   2. `fromSyllable(_:)` — heuristic for arbitrary syllabify() chunks
enum IPAMapper {

    // MARK: - Public API

    /// Returns IPA transcription for a word in the practice library, or nil if not found.
    static func ipa(for word: String) -> String? {
        guard let item = PracticeItem.library.first(where: {
            $0.word.lowercased() == word.lowercased()
        }) else { return nil }
        return fromPhonetic(item.phonetic)
    }

    /// Converts a respelling phonetic string ("pər-TIK-yə-lər-lee") to IPA ("/pərˈtɪkjʊlərliː/").
    /// Uppercase syllable → primary stress mark ˈ.
    static func fromPhonetic(_ phonetic: String) -> String {
        let parts = phonetic.components(separatedBy: ", ")
        let converted = parts.map { part -> String in
            let syllables = part.components(separatedBy: "-")
            let ipa = syllables.map { syl -> String in
                let isStressed = syl == syl.uppercased() && syl.rangeOfCharacter(from: .letters) != nil
                let lower = syl.lowercased()
                let mapped = syllableToIPA(lower)
                return isStressed ? "ˈ" + mapped : mapped
            }.joined()
            return ipa
        }.joined(separator: " ")
        return "/\(converted)/"
    }

    /// Heuristic IPA for a single syllabify() chunk — used for arbitrary words.
    /// Returns nil when the chunk is too short to map confidently.
    static func fromSyllable(_ syllable: String) -> String? {
        let s = syllable.lowercased()
        guard s.count >= 2 else { return nil }
        let mapped = syllableToIPA(s)
        return mapped == s ? nil : "/\(mapped)/"
    }

    // MARK: - Core Mapping

    private static func syllableToIPA(_ raw: String) -> String {
        var s = raw

        // Digraphs and trigraphs — must run before single-letter rules
        s = s.replacingOccurrences(of: "tch", with: "tʃ")
        s = s.replacingOccurrences(of: "tion", with: "ʃən")
        s = s.replacingOccurrences(of: "sion", with: "ʒən")
        s = s.replacingOccurrences(of: "ture", with: "tʃər")
        s = s.replacingOccurrences(of: "dge", with: "dʒ")
        s = s.replacingOccurrences(of: "sch", with: "sk")
        s = s.replacingOccurrences(of: "que", with: "k")
        s = s.replacingOccurrences(of: "ph", with: "f")
        s = s.replacingOccurrences(of: "gh", with: "")
        s = s.replacingOccurrences(of: "kn", with: "n")
        s = s.replacingOccurrences(of: "wr", with: "r")
        s = s.replacingOccurrences(of: "mb", with: "m")

        // TH
        s = replaceTH(in: s)

        // SH / CH
        s = s.replacingOccurrences(of: "sh", with: "ʃ")
        s = s.replacingOccurrences(of: "ch", with: "tʃ")
        s = s.replacingOccurrences(of: "ng", with: "ŋ")
        s = s.replacingOccurrences(of: "nk", with: "ŋk")

        // Vowel digraphs
        s = s.replacingOccurrences(of: "ee", with: "iː")
        s = s.replacingOccurrences(of: "ea", with: "iː")
        s = s.replacingOccurrences(of: "oo", with: "uː")
        s = s.replacingOccurrences(of: "ou", with: "aʊ")
        s = s.replacingOccurrences(of: "ow", with: "aʊ")
        s = s.replacingOccurrences(of: "oi", with: "ɔɪ")
        s = s.replacingOccurrences(of: "oy", with: "ɔɪ")
        s = s.replacingOccurrences(of: "au", with: "ɔː")
        s = s.replacingOccurrences(of: "aw", with: "ɔː")
        s = s.replacingOccurrences(of: "ai", with: "eɪ")
        s = s.replacingOccurrences(of: "ay", with: "eɪ")
        s = s.replacingOccurrences(of: "ey", with: "eɪ")
        s = s.replacingOccurrences(of: "ie", with: "iː")
        s = s.replacingOccurrences(of: "ue", with: "uː")
        s = s.replacingOccurrences(of: "ui", with: "uː")

        // R-coloured vowels
        s = s.replacingOccurrences(of: "air", with: "ɛər")
        s = s.replacingOccurrences(of: "are", with: "ɛər")
        s = s.replacingOccurrences(of: "ear", with: "ɪər")
        s = s.replacingOccurrences(of: "eer", with: "ɪər")
        s = s.replacingOccurrences(of: "ure", with: "jʊər")
        s = s.replacingOccurrences(of: "or",  with: "ɔːr")
        s = s.replacingOccurrences(of: "er",  with: "ər")
        s = s.replacingOccurrences(of: "ir",  with: "ɜːr")
        s = s.replacingOccurrences(of: "ur",  with: "ɜːr")
        s = s.replacingOccurrences(of: "ar",  with: "ɑːr")

        // Schwa / short vowels (position-dependent — approximate)
        s = s.replacingOccurrences(of: "ə", with: "ə")   // passthrough from phonetic strings
        s = s.replacingOccurrences(of: "ɪ", with: "ɪ")
        s = s.replacingOccurrences(of: "ʊ", with: "ʊ")

        // Consonants
        s = s.replacingOccurrences(of: "zh", with: "ʒ")
        s = s.replacingOccurrences(of: "j",  with: "dʒ")
        s = s.replacingOccurrences(of: "y",  with: "j")
        s = s.replacingOccurrences(of: "w",  with: "w")
        s = s.replacingOccurrences(of: "z",  with: "z")
        s = s.replacingOccurrences(of: "v",  with: "v")

        return s
    }

    // Voiced (the/this) → ð, voiceless (think/three) → θ
    // Heuristic: "the", "this", "that", "there", "they", "them", "these", "those",
    // "their" and common grammatical words are voiced; content words are voiceless.
    private static func replaceTH(in s: String) -> String {
        let voicedRoots = ["the", "this", "that", "there", "they", "them",
                           "these", "those", "their", "with", "then", "though"]
        let useVoiced = voicedRoots.contains(where: { s.contains($0) })
        return s.replacingOccurrences(of: "th", with: useVoiced ? "ð" : "θ")
    }
}
