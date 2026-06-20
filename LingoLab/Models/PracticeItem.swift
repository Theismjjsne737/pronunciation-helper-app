import SwiftUI

// MARK: - Difficulty

enum PracticeDifficulty: Int, CaseIterable, Comparable, Identifiable {
    case beginner     = 0
    case intermediate = 1
    case advanced     = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .beginner:     "Beginner"
        case .intermediate: "Intermediate"
        case .advanced:     "Advanced"
        }
    }

    var color: Color {
        switch self {
        case .beginner:     .green
        case .intermediate: .orange
        case .advanced:     .red
        }
    }

    static func < (lhs: PracticeDifficulty, rhs: PracticeDifficulty) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Category

enum PracticeCategory: String, CaseIterable, Identifiable {
    case commonWords     = "Common Words"
    case difficultSounds = "Difficult Sounds"
    case namesAndPlaces  = "Names & Places"
    case businessTerms   = "Business Terms"
    case borrowedWords   = "Borrowed Words"
    case tongueTwisters  = "Tongue Twisters"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .commonWords:     "text.bubble"
        case .difficultSounds: "waveform"
        case .namesAndPlaces:  "mappin.and.ellipse"
        case .businessTerms:   "briefcase"
        case .borrowedWords:   "globe"
        case .tongueTwisters:  "tornado"
        }
    }

    var color: Color {
        switch self {
        case .commonWords:     .indigo
        case .difficultSounds: .purple
        case .namesAndPlaces:  .teal
        case .businessTerms:   .blue
        case .borrowedWords:   .orange
        case .tongueTwisters:  .pink
        }
    }
}

// MARK: - Model

struct PracticeItem: Identifiable, Hashable {
    let id = UUID()
    let word: String
    let phonetic: String
    let category: PracticeCategory
    let difficulty: PracticeDifficulty
    let tip: String?
}

// MARK: - Library

extension PracticeItem {
    static let library: [PracticeItem] = commonWords + difficultSounds + namesAndPlaces + businessTerms + borrowedWords + tongueTwisters

    private static let commonWords: [PracticeItem] = [
        PracticeItem(word: "particularly",   phonetic: "pər-TIK-yə-lər-lee",  category: .commonWords, difficulty: .beginner,     tip: "Stress the second syllable"),
        PracticeItem(word: "comfortable",    phonetic: "KUMF-tər-bəl",         category: .commonWords, difficulty: .beginner,     tip: "Often mispronounced with 4 syllables; it's 3"),
        PracticeItem(word: "library",        phonetic: "LY-brer-ee",           category: .commonWords, difficulty: .beginner,     tip: "Don't skip the first R"),
        PracticeItem(word: "February",       phonetic: "FEB-roo-er-ee",        category: .commonWords, difficulty: .beginner,     tip: "Two Rs: both should be audible"),
        PracticeItem(word: "probably",       phonetic: "PROB-ə-blee",          category: .commonWords, difficulty: .beginner,     tip: nil),
        PracticeItem(word: "vegetable",      phonetic: "VEJ-tə-bəl",           category: .commonWords, difficulty: .beginner,     tip: "3 syllables, not 4"),
        PracticeItem(word: "interesting",    phonetic: "IN-trəs-ting",         category: .commonWords, difficulty: .intermediate, tip: "Can be 3 or 4 syllables; 3 is more natural"),
        PracticeItem(word: "mischievous",    phonetic: "MIS-chə-vəs",          category: .commonWords, difficulty: .intermediate, tip: "3 syllables — not 'mis-CHEEV-ee-əs'"),
        PracticeItem(word: "et cetera",      phonetic: "et-SET-ər-ə",          category: .commonWords, difficulty: .intermediate, tip: "Not 'ex-cetera'"),
        PracticeItem(word: "supposedly",     phonetic: "sə-POH-zəd-lee",       category: .commonWords, difficulty: .advanced,     tip: nil),
    ]

    private static let difficultSounds: [PracticeItem] = [
        PracticeItem(word: "rural",          phonetic: "ROO-rəl",              category: .difficultSounds, difficulty: .intermediate, tip: "Two Rs close together — say it slowly first"),
        PracticeItem(word: "squirrel",       phonetic: "SKWIR-əl",             category: .difficultSounds, difficulty: .intermediate, tip: "The -rl combination is tricky"),
        PracticeItem(word: "world",          phonetic: "WURLD",                category: .difficultSounds, difficulty: .beginner,     tip: "W + R + L in rapid succession"),
        PracticeItem(word: "sixth",          phonetic: "SIKSTH",               category: .difficultSounds, difficulty: .advanced,     tip: "Three consonants at the end: -xth"),
        PracticeItem(word: "strengths",      phonetic: "STRENGKTHS",           category: .difficultSounds, difficulty: .advanced,     tip: "8 letters, one syllable — a consonant cluster challenge"),
        PracticeItem(word: "clothes",        phonetic: "KLOHZ",                category: .difficultSounds, difficulty: .intermediate, tip: "Silent E, the TH is barely voiced"),
        PracticeItem(word: "thorough",       phonetic: "THUR-oh",              category: .difficultSounds, difficulty: .intermediate, tip: "Rhymes with 'burrow'"),
        PracticeItem(word: "colonel",        phonetic: "KUR-nəl",              category: .difficultSounds, difficulty: .advanced,     tip: "Sounds like 'kernel' — completely irregular spelling"),
        PracticeItem(word: "worcestershire", phonetic: "WUS-tər-sheer",        category: .difficultSounds, difficulty: .advanced,     tip: "Say 'Wooster-sheer' — most letters are silent"),
        PracticeItem(word: "queue",          phonetic: "KYOO",                 category: .difficultSounds, difficulty: .beginner,     tip: "Just say the letter Q"),
    ]

    private static let namesAndPlaces: [PracticeItem] = [
        PracticeItem(word: "Nguyen",         phonetic: "NWIN",                 category: .namesAndPlaces, difficulty: .advanced,     tip: "The NG is almost silent; sounds like 'nwin'"),
        PracticeItem(word: "Siobhan",        phonetic: "shih-VAWN",            category: .namesAndPlaces, difficulty: .advanced,     tip: "Irish name — 'Sh' sound from SI"),
        PracticeItem(word: "Gloucester",     phonetic: "GLOS-tər",             category: .namesAndPlaces, difficulty: .advanced,     tip: "Silent OUC — just 'Gloster'"),
        PracticeItem(word: "Leicester",      phonetic: "LES-tər",              category: .namesAndPlaces, difficulty: .advanced,     tip: "Silent CE — rhymes with 'Lester'"),
        PracticeItem(word: "Edinburgh",      phonetic: "ED-in-brə",            category: .namesAndPlaces, difficulty: .intermediate, tip: "The GH is silent; 'burgh' sounds like 'bruh'"),
        PracticeItem(word: "Cannes",         phonetic: "KAN",                  category: .namesAndPlaces, difficulty: .intermediate, tip: "Rhymes with 'can' — the S is silent"),
        PracticeItem(word: "Versailles",     phonetic: "vər-SY",               category: .namesAndPlaces, difficulty: .intermediate, tip: "The LES is silent in French — say 'ver-SY'"),
        PracticeItem(word: "Reykjavik",      phonetic: "RAY-kyah-vik",         category: .namesAndPlaces, difficulty: .intermediate, tip: nil),
        PracticeItem(word: "Ouagadougou",    phonetic: "wah-gah-DOO-goo",      category: .namesAndPlaces, difficulty: .advanced,     tip: "Capital of Burkina Faso — it's 4 smooth syllables"),
        PracticeItem(word: "Łódź",           phonetic: "WOOJ",                 category: .namesAndPlaces, difficulty: .advanced,     tip: "Polish city — sounds like 'woodge'"),
    ]

    private static let businessTerms: [PracticeItem] = [
        PracticeItem(word: "entrepreneur",   phonetic: "ahn-trə-prə-NUR",      category: .businessTerms, difficulty: .intermediate, tip: "French origin — stress the last syllable"),
        PracticeItem(word: "liaison",        phonetic: "lee-AY-zon",           category: .businessTerms, difficulty: .intermediate, tip: "Soft S sound at the end — not 'lay-a-son'"),
        PracticeItem(word: "niche",          phonetic: "NITCH or NEESH",       category: .businessTerms, difficulty: .beginner,     tip: "Both pronunciations are accepted; US prefers 'nitch'"),
        PracticeItem(word: "suite",          phonetic: "SWEET",                category: .businessTerms, difficulty: .beginner,     tip: "Rhymes with 'sweet' — not 'soot'"),
        PracticeItem(word: "cache",          phonetic: "KASH",                 category: .businessTerms, difficulty: .beginner,     tip: "Rhymes with 'cash' — not 'cash-ay'"),
        PracticeItem(word: "paradigm",       phonetic: "PAIR-ə-dyme",          category: .businessTerms, difficulty: .intermediate, tip: "Silent GN at the end"),
        PracticeItem(word: "hyperbole",      phonetic: "hy-PUR-bə-lee",        category: .businessTerms, difficulty: .advanced,     tip: "4 syllables — not 'hyper-bowl'"),
        PracticeItem(word: "synergy",        phonetic: "SIN-ər-jee",           category: .businessTerms, difficulty: .beginner,     tip: nil),
        PracticeItem(word: "quinoa",         phonetic: "KEEN-wah",             category: .businessTerms, difficulty: .intermediate, tip: "The QU sounds like K, the OA like 'wah'"),
        PracticeItem(word: "data",           phonetic: "DAY-tə or DAH-tə",     category: .businessTerms, difficulty: .beginner,     tip: "Both pronunciations are common and correct"),
    ]

    private static let borrowedWords: [PracticeItem] = [
        PracticeItem(word: "genre",          phonetic: "ZHAHN-rə",             category: .borrowedWords, difficulty: .intermediate, tip: "French G = soft ZH sound"),
        PracticeItem(word: "hors d'oeuvre",  phonetic: "or-DURV",              category: .borrowedWords, difficulty: .advanced,     tip: "The H, S, and E are all silent"),
        PracticeItem(word: "croissant",      phonetic: "kwah-SAHN",            category: .borrowedWords, difficulty: .intermediate, tip: "French nasal vowel at the end"),
        PracticeItem(word: "coup",           phonetic: "KOO",                  category: .borrowedWords, difficulty: .beginner,     tip: "Rhymes with 'who' — silent P"),
        PracticeItem(word: "faux pas",       phonetic: "FOH PAH",              category: .borrowedWords, difficulty: .intermediate, tip: "Both X and S are silent"),
        PracticeItem(word: "cliché",         phonetic: "klee-SHAY",            category: .borrowedWords, difficulty: .beginner,     tip: "Stress the second syllable"),
        PracticeItem(word: "schadenfreude",  phonetic: "SHAH-dən-froy-də",     category: .borrowedWords, difficulty: .advanced,     tip: "German word — 'pleasure from others' misfortune'"),
        PracticeItem(word: "sycophant",      phonetic: "SIK-ə-fənt",           category: .borrowedWords, difficulty: .advanced,     tip: "Greek origin — 'sy' is a short I sound"),
        PracticeItem(word: "zeitgeist",      phonetic: "TSYT-gyst",            category: .borrowedWords, difficulty: .advanced,     tip: "German — Z sounds like 'ts'"),
        PracticeItem(word: "karaoke",        phonetic: "kair-ee-OH-kee",       category: .borrowedWords, difficulty: .beginner,     tip: "4 syllables — not 'carry-oaky'"),
    ]

    private static let tongueTwisters: [PracticeItem] = [
        PracticeItem(word: "red lorry, yellow lorry", phonetic: "RED LOR-ee, YEL-oh LOR-ee", category: .tongueTwisters, difficulty: .intermediate, tip: "Repeat 3× fast — the R and L switch places"),
        PracticeItem(word: "unique New York",         phonetic: "yoo-NEEK NOO YORK",          category: .tongueTwisters, difficulty: .beginner,     tip: "Say it 3 times fast — the NY sounds blend"),
        PracticeItem(word: "toy boat",                phonetic: "TOY BOHT",                   category: .tongueTwisters, difficulty: .beginner,     tip: "Try 5 times fast — OY and O alternate"),
        PracticeItem(word: "Irish wristwatch",        phonetic: "EYE-rish RIST-woch",         category: .tongueTwisters, difficulty: .advanced,     tip: "The -rish and wrist- blend is the trap"),
        PracticeItem(word: "she sells seashells",     phonetic: "SHEE SELZ SEE-shelz",        category: .tongueTwisters, difficulty: .intermediate, tip: "SH vs S alternation — keep them distinct"),
        PracticeItem(word: "truly rural",             phonetic: "TROO-lee ROO-rəl",           category: .tongueTwisters, difficulty: .advanced,     tip: "Four R sounds — the ultimate R challenge"),
        PracticeItem(word: "which witch is which",    phonetic: "WICH WICH IZ WICH",          category: .tongueTwisters, difficulty: .beginner,     tip: "All three words sound identical — focus on clarity"),
        PracticeItem(word: "pre-shrunk silk shirts",  phonetic: "PREE-shrungk SILK SHURTS",   category: .tongueTwisters, difficulty: .advanced,     tip: "Three consonant clusters back to back"),
    ]
}
