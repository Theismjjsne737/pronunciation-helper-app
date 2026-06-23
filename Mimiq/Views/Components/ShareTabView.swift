import SwiftUI
import SwiftData

struct ShareTabView: View {

    @Query(sort: \ChatMessage.timestamp, order: .reverse) private var messages: [ChatMessage]

    private let navy     = Color(red: 0.027, green: 0.020, blue: 0.059)
    private let violet   = Color(red: 0.482, green: 0.333, blue: 1.0)
    private let offWhite = Color(red: 0.941, green: 0.933, blue: 1.0)
    private let muted    = Color(red: 0.941, green: 0.933, blue: 1.0).opacity(0.58)

    private var bestAttempt: ChatMessage? {
        messages
            .filter { $0.kind == .pronunciationResult }
            .max { ($0.pronunciationScore ?? 0) < ($1.pronunciationScore ?? 0) }
    }

    var body: some View {
        if let msg = bestAttempt,
           let word = msg.targetWord,
           let score = msg.pronunciationScore {
            ShareSheetView(
                word: word,
                score: score,
                transcription: msg.transcription ?? ""
            )
        } else {
            ZStack {
                navy.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "square.and.arrow.up.circle")
                        .font(.system(size: 52))
                        .foregroundStyle(violet.opacity(0.6))
                    Text("Nothing to share yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(offWhite)
                    Text("Practice a word and your best score will appear here.")
                        .font(.system(size: 14))
                        .foregroundStyle(muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
