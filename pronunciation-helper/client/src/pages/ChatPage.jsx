import { useEffect, useRef, useState } from 'react';
import MessageBubble from '../components/MessageBubble.jsx';
import RecordButton from '../components/RecordButton.jsx';
import Confetti from '../components/Confetti.jsx';
import { useAudioRecorder } from '../hooks/useAudioRecorder.js';
import { usePronunciationChat } from '../hooks/usePronunciationChat.js';
import styles from './ChatPage.module.css';

export default function ChatPage({ targetName, onReset }) {
  const chat = usePronunciationChat(targetName);
  const recorder = useAudioRecorder();
  const bottomRef = useRef(null);
  const ttsRef = useRef(null);
  const [ttsPlaying, setTtsPlaying] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // Init chat on mount
  useEffect(() => { chat.init(); }, []); // eslint-disable-line

  // Scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [chat.messages]);

  // Wire up TTS audio element
  useEffect(() => {
    if (chat.ttsURL && ttsRef.current) {
      ttsRef.current.src = chat.ttsURL;
    }
  }, [chat.ttsURL]);

  const handleStopAndSubmit = async () => {
    recorder.stop();
    setSubmitted(true);
    // Give MediaRecorder a tick to finish writing chunks
    await new Promise((r) => setTimeout(r, 250));
    const blob = recorder.getBlob();
    if (blob) {
      await chat.submitAttempt(blob);
    }
    recorder.reset();
    setSubmitted(false);
  };

  const handlePlayTTS = () => {
    if (ttsRef.current) {
      ttsRef.current.currentTime = 0;
      ttsRef.current.play();
      setTtsPlaying(true);
    }
  };

  const isBlocked = recorder.isRecording || chat.isProcessing || submitted;

  return (
    <div className={styles.page}>
      {chat.mastered && <Confetti />}

      {/* Hidden TTS audio element */}
      {chat.ttsURL && (
        <audio ref={ttsRef} onEnded={() => setTtsPlaying(false)} style={{ display: 'none' }} />
      )}

      {/* Header */}
      <header className={styles.header}>
        <button className={styles.backBtn} onClick={onReset} aria-label="Back">
          ← Back
        </button>

        <div className={styles.nameTag}>
          <span className={styles.nameTagLabel}>Practicing</span>
          <span className={styles.nameTagValue}>"{targetName}"</span>
        </div>

        <div className={styles.stats}>
          {chat.attemptCount > 0 && (
            <>
              <span className={styles.statPill}>
                🏆 Best: <strong>{chat.bestScore}%</strong>
              </span>
              <span className={styles.statPill}>
                🎯 Attempts: <strong>{chat.attemptCount}</strong>
              </span>
            </>
          )}
        </div>
      </header>

      {/* TTS Banner */}
      {chat.ttsURL && (
        <div className={styles.ttsBanner}>
          <span>🔊 Correct pronunciation:</span>
          <button
            className={`${styles.ttsPlayBtn} ${ttsPlaying ? styles.ttsPlaying : ''}`}
            onClick={handlePlayTTS}
          >
            {ttsPlaying ? '▶ Playing…' : '▶ Play'}
          </button>
          <span className={styles.ttsName}>{targetName}</span>
        </div>
      )}

      {/* Messages */}
      <div className={styles.messages}>
        {chat.messages.map((msg) => (
          <MessageBubble key={msg.id} message={msg} />
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input bar */}
      <div className={styles.inputBar}>
        {recorder.error && (
          <div className={styles.errorBanner}>{recorder.error}</div>
        )}

        {chat.mastered ? (
          <div className={styles.masteredActions}>
            <div className={styles.masteredMsg}>🎉 You've mastered it!</div>
            <button className={styles.newNameBtn} onClick={onReset}>
              Practice a new name →
            </button>
          </div>
        ) : (
          <div className={styles.controls}>
            <div className={styles.hint}>
              {chat.isProcessing
                ? <><Spinner /> Analyzing your pronunciation…</>
                : recorder.isRecording
                ? 'Recording in progress…'
                : chat.attemptCount === 0
                ? 'Ready when you are!'
                : 'Try again whenever you\'re ready'}
            </div>

            <RecordButton
              isRecording={recorder.isRecording}
              disabled={chat.isProcessing || submitted}
              onStart={recorder.start}
              onStop={handleStopAndSubmit}
            />
          </div>
        )}
      </div>
    </div>
  );
}

function Spinner() {
  return (
    <span
      style={{
        display: 'inline-block',
        width: 14,
        height: 14,
        border: '2px solid #E5E7EB',
        borderTopColor: '#4F46E5',
        borderRadius: '50%',
        animation: 'spin 0.7s linear infinite',
        marginRight: 6,
        verticalAlign: 'middle',
      }}
    />
  );
}
