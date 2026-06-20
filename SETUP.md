# Mimiq — Xcode Project Setup

## Requirements
- Xcode 15+
- iOS 17+ deployment target (SwiftData requires iOS 17)
- **Physical device** strongly recommended — Speech recognition + AVAudioRecorder work best on hardware

---

## 1. Create the Xcode project

1. Open Xcode → **File › New › Project**
2. Choose **iOS › App**
3. Set:

   | Field | Value |
   |---|---|
   | Product Name | `Mimiq` |
   | Bundle Identifier | `com.yourname.lingolab` |
   | Interface | SwiftUI |
   | Language | Swift |
   | Storage | None *(SwiftData is managed manually)* |

4. Save the project inside `/path/to/lingolab/`

---

## 2. Add source files

Delete the default stub files, then drag the **entire `Mimiq/` folder** into the Xcode Project Navigator:
- Check *Create groups* (not folder references)
- Check *Add to target: Mimiq*

Final Xcode file tree:

```
Mimiq/
├── App/
│   ├── MimiqApp.swift
│   └── ContentView.swift
├── Models/
│   ├── AccentProfile.swift
│   └── ChatMessage.swift
├── Services/
│   ├── AudioRecordingService.swift
│   ├── AudioPlaybackService.swift
│   ├── SpeechAnalysisService.swift
│   ├── AnthropicService.swift
│   ├── AccentProfileService.swift
│   ├── KeychainService.swift
│   └── TTSService.swift
├── ViewModels/
│   └── CoachViewModel.swift
└── Views/
    ├── Coach/
    │   ├── CoachView.swift          ← Main screen
    │   ├── MessageBubbleView.swift
    │   ├── RecordingWidget.swift
    │   └── InputBar.swift
    ├── Profile/
    │   └── AccentProfileView.swift
    ├── Onboarding/
    │   └── OnboardingView.swift
    ├── Settings/
    │   └── SettingsView.swift
    ├── Practice/
    │   └── AudioWaveformView.swift  ← shared waveform component
    └── Components/
        ├── PhonemeBreakdownView.swift
        └── ScoreGaugeView.swift
```

---

## 3. Info.plist — Required permission keys

In **Target › Info tab**, add:

| Key | Value |
|---|---|
| `NSMicrophoneUsageDescription` | `Mimiq needs microphone access to record your pronunciation.` |
| `NSSpeechRecognitionUsageDescription` | `Mimiq uses speech recognition to analyse your pronunciation.` |
| `NSUserNotificationsUsageDescription` | `Mimiq sends a daily reminder to help you build a practice habit.` |

---

## 4. Frameworks (auto-linked, just verify)

**Target › Build Phases › Link Binary with Libraries:**
- `AVFoundation.framework`
- `Speech.framework`

Both are system frameworks — no SPM packages needed.

---

## 5. Signing

**Target › Signing & Capabilities** → select your personal team.

---

## 6. Add your Anthropic API key

1. Build & run on device (⌘R)
2. Open the **Coach tab**
3. Tap ⚙️ Settings → paste your Anthropic API key → tap **Save Key**
4. The key is stored in the iOS Keychain and never transmitted anywhere except Anthropic's API

Get a key at: https://console.anthropic.com

---

## How the app works

```
User: "How do I say Nguyen?"
       ↓
CoachViewModel.send()
       ↓
AnthropicService.streamCompletion()  ← streams Claude claude-opus-4-6 response
       ↓
Claude responds with coaching text
+ ends message with: [RECORD: Nguyen]
       ↓
CoachView detects tag → RecordingWidget slides up
"Your turn to say: Nguyen  [🔊 Hear it]  [🎙 Record]"
       ↓
User taps 🔊 → TTSService.speak("Nguyen")
User taps 🎙 → AudioRecordingService records
User taps Stop
       ↓
SpeechAnalysisService.analyze(url, targetWord: "Nguyen")
→ transcription: "win"
→ score: 87%
       ↓
AccentProfileService.record() updates AccentProfile phoneme patterns
       ↓
CoachViewModel sends to Claude:
"User recorded 'Nguyen'. I heard: 'win'. Score: 87%."
       ↓
Claude gives accent-aware coaching response
```

---

## Architecture

| Layer | Files |
|---|---|
| **Models** | `AccentProfile` (SwiftData, phoneme patterns), `ChatMessage` (SwiftData, session history) |
| **Services** | `AudioRecordingService`, `AudioPlaybackService`, `SpeechAnalysisService`, `TTSService`, `AnthropicService` (streaming SSE), `AccentProfileService` (phoneme detector + prompt builder), `KeychainService` |
| **ViewModel** | `CoachViewModel` — single state machine driving the entire coaching loop |
| **Views** | `CoachView` (main), `MessageBubbleView`, `RecordingWidget`, `InputBar`, `AccentProfileView` |

### CoachState machine

```
idle ──send()──────────────────────► thinking
thinking ──Claude responds──────────► idle
thinking ──Claude adds [RECORD:]───► awaitingAttempt(word)
awaitingAttempt ──startRecording()─► recording(word)
recording ──stopAndAnalyze()───────► analyzing(word)
analyzing ──result ready────────────► thinking (sends result to Claude)
thinking ──Claude coaching response► idle or awaitingAttempt
```

---

## Answers to your original questions

| Question | Decision |
|---|---|
| Languages? | English-first; swap `SpeechAnalysisService(locale:)` for other targets |
| Privacy? | Fully on-device — Keychain (API key), SwiftData (profile + history) |
| Pre-loaded content? | **None** — 100% user-driven, any word/name they ask |
| Accent groups | 8 built-in (Spanish, Mandarin, French, German, Japanese, Korean, Arabic, Hindi) with per-phoneme teaching hints passed to Claude |

---

## Roadmap

- [ ] Voice input in chat (transcribe question, not just recording attempt)
- [ ] Daily notification reminders
- [ ] iCloud sync of `AccentProfile`
- [ ] Pitch/prosody analysis with AVAudioEngine + FFT
- [ ] On-device Core ML phoneme classifier for more accurate IPA matching
- [ ] Multiple target languages (swap SFSpeechRecognizer locale)
