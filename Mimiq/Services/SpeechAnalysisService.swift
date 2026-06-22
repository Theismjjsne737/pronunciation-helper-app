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

    var locale: Locale

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

        let sfResult = try await transcribe(url: recordingURL, recognizer: recognizer, target: targetWord)

        // Pick the N-best hypothesis closest to the target word — accented speech often
        // produces the correct pronunciation as hypothesis 2-5, not hypothesis 1.
        let target = targetWord.lowercased().trimmingCharacters(in: .whitespaces)
        let bestTranscription = sfResult.transcriptions
            .min(by: { a, b in
                let da = levenshteinDistance(
                    Array(a.formattedString.lowercased().trimmingCharacters(in: .whitespaces)),
                    Array(target)
                )
                let db = levenshteinDistance(
                    Array(b.formattedString.lowercased().trimmingCharacters(in: .whitespaces)),
                    Array(target)
                )
                return da < db
            }) ?? sfResult.bestTranscription

        let transcription = bestTranscription.formattedString
        let segments = bestTranscription.segments

        let score = computeScore(transcription: transcription, target: targetWord, segments: segments)
        let phonemes = buildPhonemeScores(targetWord: targetWord, heard: transcription, segments: segments)

        return AnalysisResult(
            transcription: transcription,
            score: score,
            phonemeScores: phonemes,
            targetWord: targetWord
        )
    }

    // MARK: - Transcription

    private func transcribe(url: URL, recognizer: SFSpeechRecognizer, target: String) async throws -> SFSpeechRecognitionResult {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        // .search is tuned for short isolated-word utterances; .dictation is for continuous speech
        request.taskHint = .search
        if #available(iOS 16, *) { request.addsPunctuation = false }
        // Prime the acoustic model to heavily favour the target word in the N-best list
        request.contextualStrings = [target, target.lowercased(), target.uppercased()]

        return try await withCheckedThrowingContinuation { continuation in
            var resolved = false
            let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                guard !resolved else { return }
                if let error {
                    resolved = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else { return }
                if result.isFinal {
                    resolved = true
                    continuation.resume(returning: result)
                }
            }
            Task {
                try? await Task.sleep(for: .seconds(15))
                guard !resolved else { return }
                resolved = true
                recognitionTask.cancel()
                continuation.resume(throwing: AnalysisError.noResult)
            }
        }
    }

    // MARK: - Scoring

    /// 65% string similarity + 35% Speech framework confidence, with bonuses/penalties.
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
        let exactBonus: Double = t == s ? 0.08 : 0
        // Penalise when the first phoneme is wrong — it's the strongest perceptual cue
        let firstCharPenalty: Double = (!t.isEmpty && !s.isEmpty && t.first != s.first) ? 0.08 : 0
        return max(0, min(1, similarity * 0.65 + confidence * 0.35 + exactBonus - firstCharPenalty))
    }

    private func buildPhonemeScores(targetWord: String, heard: String, segments: [SFTranscriptionSegment]) -> [PhonemeScore] {
        let heardLower = heard.lowercased()
        return phonemeGroups(targetWord).enumerated().map { i, group in
            let seg = segments.indices.contains(i) ? segments[i] : nil
            let rawScore: Double
            if let seg {
                rawScore = Double(seg.confidence) * 1.05
            } else {
                // Fall back to presence check: was this phoneme group audible in what was heard?
                rawScore = heardLower.contains(group.lowercased()) ? 0.75 : 0.35
            }
            return PhonemeScore(
                phoneme: group,
                ipaSymbol: IPAMapper.fromSyllable(group),
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

    // MARK: - Digraph-aware phoneme tokenizer

    /// Splits a word into phoneme groups, treating common digraphs as single units.
    /// Example: "think" → ["th", "ink"] rather than ["t", "h", "ink"]
    private func phonemeGroups(_ word: String) -> [String] {
        let digraphs = ["tch", "dge", "sch", "th", "sh", "ch", "wh", "ng", "ph", "ck", "qu", "gh"]
        var groups: [String] = []
        var i = word.startIndex

        while i < word.endIndex {
            var matched = false
            for digraph in digraphs {
                if word[i...].lowercased().hasPrefix(digraph) {
                    let end = word.index(i, offsetBy: digraph.count, limitedBy: word.endIndex) ?? word.endIndex
                    groups.append(String(word[i..<end]))
                    i = end
                    matched = true
                    break
                }
            }
            if !matched {
                groups.append(String(word[i]))
                i = word.index(after: i)
            }
        }

        // Merge lone vowels into the preceding group so each group has phonetic weight
        let vowels = Set("aeiouAEIOU")
        var merged: [String] = []
        for group in groups {
            if group.count == 1 && vowels.contains(group.first!), let last = merged.last {
                merged[merged.count - 1] = last + group
            } else {
                merged.append(group)
            }
        }

        return merged.isEmpty ? [word] : merged
    }
}
