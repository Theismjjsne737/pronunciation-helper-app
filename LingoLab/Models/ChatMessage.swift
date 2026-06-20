import Foundation
import SwiftData

// MARK: - Message role

enum MessageRole: String, Codable {
    case user
    case assistant
}

// MARK: - Message kind (controls rendering)

enum MessageKind: String, Codable {
    case text                   // Normal chat text
    case recordingRequest       // Bot asked user to record; shows inline recording widget
    case pronunciationResult    // User's attempt result (shown as a result card)
    case typing                 // Ephemeral: "..." while streaming
}

// MARK: - Model

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var kindRaw: String
    var content: String             // Display text (recording tag already stripped)
    var targetWord: String?         // Set when kind == .recordingRequest
    var pronunciationScore: Double? // Set when kind == .pronunciationResult
    var transcription: String?      // What Speech heard (for pronunciationResult)
    var detectedPatternsRaw: String? // e.g. "th→d, v→b" — nil when no patterns found
    var timestamp: Date
    var sessionID: UUID             // Groups messages into a session

    init(
        role: MessageRole,
        kind: MessageKind = .text,
        content: String,
        targetWord: String? = nil,
        pronunciationScore: Double? = nil,
        transcription: String? = nil,
        detectedPatterns: [String] = [],
        sessionID: UUID
    ) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.kindRaw = kind.rawValue
        self.content = content
        self.targetWord = targetWord
        self.pronunciationScore = pronunciationScore
        self.transcription = transcription
        self.detectedPatternsRaw = detectedPatterns.isEmpty ? nil : detectedPatterns.joined(separator: ", ")
        self.timestamp = Date()
        self.sessionID = sessionID
    }

    // MARK: Computed

    var role: MessageRole { MessageRole(rawValue: roleRaw) ?? .assistant }
    var kind: MessageKind { MessageKind(rawValue: kindRaw) ?? .text }
    var isUser: Bool { role == .user }
}
