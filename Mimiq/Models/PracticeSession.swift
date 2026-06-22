import Foundation
import SwiftData

/// Captures per-session practice stats. One row per coaching session.
@Model
final class PracticeSession {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID          // matches ChatMessage.sessionID for cross-referencing
    var date: Date
    var wordsAttempted: Int
    var totalScore: Double

    init(sessionID: UUID) {
        self.id = UUID()
        self.sessionID = sessionID
        self.date = Date()
        self.wordsAttempted = 0
        self.totalScore = 0
    }

    var averageScore: Double {
        wordsAttempted > 0 ? totalScore / Double(wordsAttempted) : 0
    }

    var averageScorePercentage: Int { Int(averageScore * 100) }
}
