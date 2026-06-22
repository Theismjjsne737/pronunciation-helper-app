import Testing
@testable import LingoLab

@Suite("PhonemePattern")
struct PhonemePatternTests {

    @Test("accuracy returns 0.5 when no attempts")
    func accuracyNoAttempts() {
        let p = PhonemePattern(phoneme: "th")
        #expect(p.accuracy == 0.5)
    }

    @Test("accuracy is 1.0 when no errors")
    func accuracyPerfect() {
        var p = PhonemePattern(phoneme: "th")
        p.attemptCount = 4
        p.errorCount = 0
        #expect(p.accuracy == 1.0)
    }

    @Test("accuracy is 0.0 when all attempts are errors")
    func accuracyAllErrors() {
        var p = PhonemePattern(phoneme: "r")
        p.attemptCount = 3
        p.errorCount = 3
        #expect(p.accuracy == 0.0)
    }

    @Test("accuracy computes correctly for partial errors")
    func accuracyPartial() {
        var p = PhonemePattern(phoneme: "v")
        p.attemptCount = 4
        p.errorCount = 1
        #expect(p.accuracy == 0.75)
    }

    @Test("substitution defaults to nil")
    func substitutionDefault() {
        let p = PhonemePattern(phoneme: "th")
        #expect(p.substitution == nil)
    }

    @Test("substitution can be set at init")
    func substitutionSet() {
        let p = PhonemePattern(phoneme: "th", substitution: "d")
        #expect(p.substitution == "d")
    }

    @Test("each instance gets unique id")
    func uniqueIDs() {
        let a = PhonemePattern(phoneme: "r")
        let b = PhonemePattern(phoneme: "r")
        #expect(a.id != b.id)
    }

    @Test("mastered threshold is accuracy >= 0.80")
    func tierMastered() {
        var p = PhonemePattern(phoneme: "l")
        p.attemptCount = 5
        p.errorCount = 1  // 4/5 = 0.80
        #expect(p.accuracy >= 0.80)
    }

    @Test("challenge threshold is accuracy < 0.55")
    func tierChallenge() {
        var p = PhonemePattern(phoneme: "w")
        p.attemptCount = 4
        p.errorCount = 2  // 2/4 = 0.50
        #expect(p.accuracy < 0.55)
    }
}
