import Foundation
import SwiftData

@Model
final class SavedWord {
    var word: String
    var note: String?
    var createdAt: Date

    init(word: String, note: String? = nil) {
        self.word = word
        self.note = note
        self.createdAt = Date()
    }
}
