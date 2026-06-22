import ActivityKit
import Foundation

/// Live Activity shown in the Dynamic Island while the user is recording or waiting for analysis.
struct RecordingActivityAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        var targetWord: String
        var phase: Phase
        var score: Double?         // 0–1, available in .complete phase
        var transcription: String? // what was heard

        enum Phase: String, Codable {
            case recording  // mic is hot
            case analyzing  // processing
            case complete   // score ready
        }
    }

    var sessionID: String
}
