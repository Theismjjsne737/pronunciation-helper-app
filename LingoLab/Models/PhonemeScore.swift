import Foundation

// MARK: - Phoneme Analysis

struct PhonemeScore: Identifiable {
    let id = UUID()
    let phoneme: String
    let score: Double              // 0.0 – 1.0 accuracy
    let startTime: Double          // seconds
    let endTime: Double            // seconds

    var duration: Double {
        endTime - startTime
    }

    var accuracy: Double {
        score
    }
}
