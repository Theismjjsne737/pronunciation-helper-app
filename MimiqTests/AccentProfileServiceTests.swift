import Testing
@testable import Mimiq

@Suite("AccentProfileService — detectPatterns")
struct AccentProfileServiceTests {

    let service = AccentProfileService()

    // MARK: th substitutions

    @Test("th→d detected (Spanish/Korean/Mandarin pattern)")
    func thToD() {
        let result = service.detectPatterns(target: "the", heard: "de")
        #expect(result.contains { $0.phoneme == "th" && $0.sub == "d" })
    }

    @Test("th→t detected (German/Hindi pattern)")
    func thToT() {
        let result = service.detectPatterns(target: "think", heard: "tink")
        #expect(result.contains { $0.phoneme == "th" && $0.sub == "t" })
    }

    @Test("th→s detected (French pattern)")
    func thToS() {
        let result = service.detectPatterns(target: "think", heard: "sink")
        #expect(result.contains { $0.phoneme == "th" && $0.sub == "s" })
    }

    // MARK: r / l substitutions

    @Test("r→l detected (East Asian pattern)")
    func rToL() {
        let result = service.detectPatterns(target: "right", heard: "light")
        #expect(result.contains { $0.phoneme == "r" && $0.sub == "l" })
    }

    // MARK: v / w / p substitutions

    @Test("v→b detected (Spanish pattern)")
    func vToB() {
        let result = service.detectPatterns(target: "very", heard: "berry")
        #expect(result.contains { $0.phoneme == "v" && $0.sub == "b" })
    }

    @Test("w→v detected (German/Hindi pattern)")
    func wToV() {
        let result = service.detectPatterns(target: "wine", heard: "vine")
        #expect(result.contains { $0.phoneme == "w" && $0.sub == "v" })
    }

    @Test("p→b detected (Arabic pattern)")
    func pToB() {
        let result = service.detectPatterns(target: "pan", heard: "ban")
        #expect(result.contains { $0.phoneme == "p" && $0.sub == "b" })
    }

    // MARK: silent h

    @Test("silent h detected when heard omits leading h")
    func silentH() {
        let result = service.detectPatterns(target: "hello", heard: "ello")
        #expect(result.contains { $0.phoneme == "h" && $0.sub == nil })
    }

    // MARK: final consonant drop

    @Test("final consonant drop detected")
    func finalConsonantDrop() {
        // "cat" ends in 't' (in the detector set), "ca" ends in 'a' (not in set)
        let result = service.detectPatterns(target: "cat", heard: "ca")
        #expect(result.contains { $0.phoneme == "final-consonants" })
    }

    @Test("final consonant not flagged when heard ends in consonant")
    func finalConsonantKept() {
        let result = service.detectPatterns(target: "stop", heard: "stob")
        #expect(!result.contains { $0.phoneme == "final-consonants" })
    }

    // MARK: consonant clusters

    @Test("consonant cluster simplification detected")
    func consonantCluster() {
        let result = service.detectPatterns(target: "street", heard: "seet")
        #expect(result.contains { $0.phoneme == "consonant-cluster" })
    }

    // MARK: no pattern

    @Test("no patterns returned when pronunciation matches target")
    func noPatterns() {
        let result = service.detectPatterns(target: "cat", heard: "cat")
        #expect(result.isEmpty)
    }

    @Test("empty strings return no patterns")
    func emptyStrings() {
        let result = service.detectPatterns(target: "", heard: "")
        #expect(result.isEmpty)
    }
}
