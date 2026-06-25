import Testing
import Foundation
@testable import Mimiq

// SubscriptionManager is a @MainActor singleton backed by UserDefaults.
// Each test clears the storage key in init/deinit for isolation.
@Suite("SubscriptionManager — word counter")
@MainActor
final class SubscriptionManagerWordCounterTests {

    private let storageKey = "pronce_free_words_v1"

    init() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        SubscriptionManager.shared.resetWordCounterForTesting()
    }

    deinit {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Constants

    @Test("freeWordLimit is 5")
    func freeWordLimit() {
        #expect(SubscriptionManager.freeWordLimit == 5)
    }

    // MARK: - hasSeenWord

    @Test("hasSeenWord returns false for unseen word")
    func hasSeenWordFalse() {
        #expect(!SubscriptionManager.shared.hasSeenWord("Nguyen"))
    }

    @Test("hasSeenWord returns true after markWordSeen")
    func hasSeenWordTrue() {
        SubscriptionManager.shared.markWordSeen("Nguyen")
        #expect(SubscriptionManager.shared.hasSeenWord("Nguyen"))
    }

    // MARK: - Canonicalization

    @Test("hasSeenWord is case-insensitive")
    func caseInsensitive() {
        SubscriptionManager.shared.markWordSeen("Nguyen")
        #expect(SubscriptionManager.shared.hasSeenWord("nguyen"))
        #expect(SubscriptionManager.shared.hasSeenWord("NGUYEN"))
    }

    @Test("hasSeenWord trims leading and trailing whitespace")
    func trimsWhitespace() {
        SubscriptionManager.shared.markWordSeen("  colonel  ")
        #expect(SubscriptionManager.shared.hasSeenWord("colonel"))
    }

    // MARK: - uniqueWordCount

    @Test("uniqueWordCount starts at zero after reset")
    func startsAtZero() {
        #expect(SubscriptionManager.shared.uniqueWordCount == 0)
    }

    @Test("uniqueWordCount increments on each new word")
    func incrementsOnNewWord() {
        SubscriptionManager.shared.markWordSeen("one")
        #expect(SubscriptionManager.shared.uniqueWordCount == 1)
        SubscriptionManager.shared.markWordSeen("two")
        #expect(SubscriptionManager.shared.uniqueWordCount == 2)
    }

    @Test("markWordSeen does not increment count for duplicate word")
    func noDuplicateCount() {
        SubscriptionManager.shared.markWordSeen("chipotle")
        SubscriptionManager.shared.markWordSeen("chipotle")
        #expect(SubscriptionManager.shared.uniqueWordCount == 1)
    }

    // MARK: - wordsRemaining

    @Test("wordsRemaining equals freeWordLimit when no words seen")
    func wordsRemainingFull() {
        #expect(SubscriptionManager.shared.wordsRemaining == SubscriptionManager.freeWordLimit)
    }

    @Test("wordsRemaining decrements as words are marked")
    func wordsRemainingDecrements() {
        SubscriptionManager.shared.markWordSeen("a")
        SubscriptionManager.shared.markWordSeen("b")
        #expect(SubscriptionManager.shared.wordsRemaining == SubscriptionManager.freeWordLimit - 2)
    }

    @Test("wordsRemaining never goes below zero")
    func wordsRemainingFloor() {
        for i in 0..<(SubscriptionManager.freeWordLimit + 3) {
            SubscriptionManager.shared.markWordSeen("word\(i)")
        }
        #expect(SubscriptionManager.shared.wordsRemaining == 0)
    }

    // MARK: - hasUsedAllFreeWords

    @Test("hasUsedAllFreeWords is false when under limit")
    func hasUsedAllFalse() {
        SubscriptionManager.shared.markWordSeen("only-one")
        #expect(!SubscriptionManager.shared.hasUsedAllFreeWords)
    }

    @Test("hasUsedAllFreeWords is true when limit reached")
    func hasUsedAllTrue() {
        for i in 0..<SubscriptionManager.freeWordLimit {
            SubscriptionManager.shared.markWordSeen("word\(i)")
        }
        #expect(SubscriptionManager.shared.hasUsedAllFreeWords)
    }
}
