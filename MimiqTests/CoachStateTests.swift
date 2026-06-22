import Testing
@testable import LingoLab

@Suite("CoachState")
struct CoachStateTests {

    @Test("idle equals idle")
    func idleEquality() {
        #expect(CoachState.idle == .idle)
    }

    @Test("thinking equals thinking")
    func thinkingEquality() {
        #expect(CoachState.thinking == .thinking)
    }

    @Test("awaitingAttempt equal when same word")
    func awaitingAttemptSameWord() {
        #expect(CoachState.awaitingAttempt(word: "Nguyen") == .awaitingAttempt(word: "Nguyen"))
    }

    @Test("awaitingAttempt not equal when different word")
    func awaitingAttemptDifferentWord() {
        #expect(CoachState.awaitingAttempt(word: "Nguyen") != .awaitingAttempt(word: "colonel"))
    }

    @Test("recording equal when same word")
    func recordingSameWord() {
        #expect(CoachState.recording(word: "chipotle") == .recording(word: "chipotle"))
    }

    @Test("recording not equal when different word")
    func recordingDifferentWord() {
        #expect(CoachState.recording(word: "chipotle") != .recording(word: "Siobhan"))
    }

    @Test("analyzing equal when same word")
    func analyzingSameWord() {
        #expect(CoachState.analyzing(word: "Worcester") == .analyzing(word: "Worcester"))
    }

    @Test("analyzing not equal when different word")
    func analyzingDifferentWord() {
        #expect(CoachState.analyzing(word: "Worcester") != .analyzing(word: "quinoa"))
    }

    @Test("different cases are not equal")
    func differentCasesNotEqual() {
        #expect(CoachState.idle != .thinking)
        #expect(CoachState.idle != .awaitingAttempt(word: "test"))
        #expect(CoachState.thinking != .recording(word: "test"))
        #expect(CoachState.awaitingAttempt(word: "x") != .recording(word: "x"))
        #expect(CoachState.recording(word: "x") != .analyzing(word: "x"))
    }

    @Test("pattern matching on awaitingAttempt extracts word")
    func patternMatchAwaitingAttempt() {
        let state = CoachState.awaitingAttempt(word: "GIF")
        if case .awaitingAttempt(let w) = state {
            #expect(w == "GIF")
        } else {
            Issue.record("Expected awaitingAttempt case")
        }
    }

    @Test("pattern matching on recording extracts word")
    func patternMatchRecording() {
        let state = CoachState.recording(word: "Worcestershire")
        if case .recording(let w) = state {
            #expect(w == "Worcestershire")
        } else {
            Issue.record("Expected recording case")
        }
    }
}
