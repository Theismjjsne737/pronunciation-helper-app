import Speech
import Combine

// MARK: - Analysis result

struct AnalysisResult {
    let transcription: String
    let score: Double               // 0.0 – 1.0
    let phonemeScores: [PhonemeScore]
    let targetWord: String

    var scorePercentage: Int { Int(score * 100) }

    var scoreLabel: String {
        switch score {
        case 0.9...: return "Excellent"
        case 0.75..<0.9: return "Good"
        case 0.55..<0.75: return "Fair"
        default: return "Keep Practising"
        }
    }

    var feedbackMessage: String {
        switch score {
        case 0.9...: return "That was very clear!"
        case 0.75..<0.9: return "Nice — a few sounds to sharpen."
        case 0.55..<0.75: return "You're on the right track. Try slowing down."
        default: return "No worries, let's break it down."
        }
    }
}

// MARK: - Errors

enum AnalysisError: LocalizedError {
    case recognizerUnavailable
    case noResult
    case audioFileMissing

    var errorDescription: String? {
        switch self {
        case .recognizerUnavailable: return "Speech recognizer is unavailable."
        case .noResult:              return "Couldn't understand the recording. Try again."
        case .audioFileMissing:      return "Recording file not found."
        }
    }
}

// MARK: - Service

/// Transcribes a recording with the Speech framework and produces a pronunciation score.
@MainActor
final class SpeechAnalysisService: ObservableObject {

    @Published private(set) var isAnalyzing = false

    private let locale: Locale

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Analysis

    /// Transcribes `recordingURL` and scores it against `targetWord`.
    func analyze(recordingURL: URL, targetWord: String) async throws -> AnalysisResult {
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            throw AnalysisError.audioFileMissing
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw AnalysisError.recognizerUnavailable
        }

        isAnalyzing = true
        defer { isAnalyzing = false }

        let sfResult = try await transcribe(url: recordingURL, recognizer: recognizer)
        let transcription = sfResult.bestTranscription.formattedString
        let segments = sfResult.bestTranscription.segments

        let score = computeScore(transcription: transcription, target: targetWord, segments: segments)
        let phonemes = buildPhonemeScores(targetWord: targetWord, segments: segments)

        return AnalysisResult(
            transcription: transcription,
            score: score,
            phonemeScores: phonemes,
            targetWord: targetWord
        )
    }

    // MARK: - Transcription

    private func transcribe(url: URL, recognizer: SFSpeechRecognizer) async throws -> SFSpeechRecognitionResult {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        if #available(iOS 16, *) { request.addsPunctuation = false }

        return try await withCheckedThrowingContinuation { continuation in
            var resolved = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resolved else { return }
                if let error { resolved = true; continuation.resume(throwing: error); return }
                guard let result, result.isFinal else { return }
                resolved = true
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Scoring

    /// 70% string similarity + 30% Speech framework confidence.
    private func computeScore(
        transcription: String,
        target: String,
        segments: [SFTranscriptionSegment]
    ) -> Double {
        let t = transcription.lowercased().trimmingCharacters(in: .whitespaces)
        let s = target.lowercased().trimmingCharacters(in: .whitespaces)
        let similarity = stringSimilarity(t, s)
        let confidence = segments.isEmpty
            ? 0.0
            : Double(segments.map(\.confidence).reduce(0, +)) / Double(segments.count)
        let bonus: Double = t == s ? 0.05 : 0
        return max(0, min(1, similarity * 0.7 + confidence * 0.3 + bonus))
    }

    private func buildPhonemeScores(targetWord: String, segments: [SFTranscriptionSegment]) -> [PhonemeScore] {
        syllabify(targetWord).enumerated().map { i, syllable in
            let seg = segments.indices.contains(i) ? segments[i] : nil
            let rawScore = seg.map { Double($0.confidence) * 1.1 } ?? 0.5
            return PhonemeScore(
                phoneme: syllable,
                ipaSymbol: IPAMapper.fromSyllable(syllable),
                score: max(0, min(1, rawScore)),
                startTime: seg?.timestamp ?? 0,
                endTime: (seg?.timestamp ?? 0) + (seg?.duration ?? 0)
            )
        }
    }

    // MARK: - String similarity (Levenshtein)

    private func stringSimilarity(_ a: String, _ b: String) -> Double {
        if a == b { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }
        let d = levenshteinDistance(Array(a), Array(b))
        return 1.0 - Double(d) / Double(max(a.count, b.count))
    }

    private func levenshteinDistance<T: Equatable>(_ s: [T], _ t: [T]) -> Int {
        let m = s.count, n = t.count
        var dp = (0...m).map { i in (0...n).map { j in i == 0 ? j : (j == 0 ? i : 0) } }
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = s[i-1] == t[j-1] ? dp[i-1][j-1] : 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
            }
        }
        return dp[m][n]
    }

    // MARK: - Syllabification

    private func syllabify(_ word: String) -> [String] {
        let vowels = Set("aeiouAEIOU")
        var syllables: [String] = []
        var current = ""
        var inVowelRun = false
        for (i, ch) in word.enumerated() {
            let isVowel = vowels.contains(ch)
            if !current.isEmpty && !isVowel && inVowelRun && i < word.count - 1 {
                syllables.append(current); current = String(ch)
            } else { current.append(ch) }
            inVowelRun = isVowel
        }
        if !current.isEmpty { syllables.append(current) }
        return syllables.isEmpty ? [word] : syllables
    }
}
