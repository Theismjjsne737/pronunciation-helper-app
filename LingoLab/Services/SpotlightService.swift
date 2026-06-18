import CoreSpotlight
import Foundation

/// Indexes practiced words in Spotlight so users can search them from the home screen.
enum SpotlightService {

    static let domainID = "com.lingolab.words"

    // MARK: - Index a practiced word

    static func index(word: String, score: Double, transcription: String?) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = word
        attributeSet.contentDescription = "Pronunciation score: \(Int(score * 100))%"
        if let heard = transcription {
            attributeSet.keywords = [word, heard, "pronunciation", "practice", "LingoLab"]
        }
        // TODO: Fix UIImage encoding issue
        // attributeSet.thumbnailData = UIImage(systemName: "waveform.and.mic")?.pngData()

        let item = CSSearchableItem(
            uniqueIdentifier: "word_\(word.lowercased())",
            domainIdentifier: domainID,
            attributeSet: attributeSet
        )
        item.expirationDate = .distantFuture

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error { print("Spotlight index error: \(error)") }
        }
    }

    // MARK: - Remove all indexed items

    static func removeAll() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domainID]) { _ in }
    }
}
