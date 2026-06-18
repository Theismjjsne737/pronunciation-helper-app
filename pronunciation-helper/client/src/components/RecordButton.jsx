import styles from './RecordButton.module.css';

export default function RecordButton({ isRecording, disabled, onStart, onStop }) {
  return (
    <div className={styles.wrapper}>
      {isRecording && (
        <>
          <div className={styles.pulseRing} />
          <div className={styles.pulseRing2} />
        </>
      )}
      <button
        className={`${styles.btn} ${isRecording ? styles.recording : ''}`}
        disabled={disabled && !isRecording}
        onClick={isRecording ? onStop : onStart}
        aria-label={isRecording ? 'Stop recording' : 'Start recording'}
      >
        {isRecording ? (
          <StopIcon />
        ) : (
          <MicIcon />
        )}
      </button>
      <span className={styles.label}>
        {isRecording ? 'Recording… tap to stop' : 'Tap to record'}
      </span>
    </div>
  );
}

function MicIcon() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 1a4 4 0 0 1 4 4v6a4 4 0 0 1-8 0V5a4 4 0 0 1 4-4z"/>
      <path d="M19 10v1a7 7 0 0 1-14 0v-1" stroke="currentColor" strokeWidth="1.5" fill="none" strokeLinecap="round"/>
      <line x1="12" y1="18" x2="12" y2="22" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
      <line x1="9" y1="22" x2="15" y2="22" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/>
    </svg>
  );
}

function StopIcon() {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
      <rect x="5" y="5" width="14" height="14" rx="2"/>
    </svg>
  );
}
