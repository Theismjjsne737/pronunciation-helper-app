import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case englishUS    = "en-US"
    case englishGB    = "en-GB"
    case spanishES    = "es-ES"
    case frenchFR     = "fr-FR"
    case germanDE     = "de-DE"
    case portugueseBR = "pt-BR"
    case italianIT    = "it-IT"
    case japaneseJP   = "ja-JP"
    case mandarinCN   = "zh-CN"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .englishUS:    return "English (US)"
        case .englishGB:    return "English (UK)"
        case .spanishES:    return "Spanish"
        case .frenchFR:     return "French"
        case .germanDE:     return "German"
        case .portugueseBR: return "Portuguese (BR)"
        case .italianIT:    return "Italian"
        case .japaneseJP:   return "Japanese"
        case .mandarinCN:   return "Mandarin"
        }
    }

    var flag: String {
        switch self {
        case .englishUS:    return "🇺🇸"
        case .englishGB:    return "🇬🇧"
        case .spanishES:    return "🇪🇸"
        case .frenchFR:     return "🇫🇷"
        case .germanDE:     return "🇩🇪"
        case .portugueseBR: return "🇧🇷"
        case .italianIT:    return "🇮🇹"
        case .japaneseJP:   return "🇯🇵"
        case .mandarinCN:   return "🇨🇳"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    static var `default`: SupportedLanguage { .englishUS }
}
