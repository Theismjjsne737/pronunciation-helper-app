import ProgressRing from './ProgressRing.jsx';
import styles from './MessageBubble.module.css';

function formatText(text) {
  // Bold **text**
  const parts = text.split(/(\*\*[^*]+\*\*)/g);
  return parts.map((part, i) =>
    part.startsWith('**') && part.endsWith('**')
      ? <strong key={i}>{part.slice(2, -2)}</strong>
      : part
  );
}

export default function MessageBubble({ message }) {
  const { role, text, typing, score, isMastered, isError, audioBlob } = message;
  const isBot = role === 'bot';

  if (typing) {
    return (
      <div className={`${styles.row} ${styles.botRow}`}>
        <div className={styles.avatar}>🤖</div>
        <div className={`${styles.bubble} ${styles.botBubble} ${styles.typingBubble}`}>
          <span className={styles.dot} />
          <span className={styles.dot} />
          <span className={styles.dot} />
        </div>
      </div>
    );
  }

  return (
    <div className={`${styles.row} ${isBot ? styles.botRow : styles.userRow}`}>
      {isBot && <div className={styles.avatar}>🤖</div>}

      <div className={`${styles.bubble} ${isBot ? styles.botBubble : styles.userBubble} ${isError ? styles.errorBubble : ''} ${isMastered ? styles.masteredBubble : ''}`}>
        {score !== undefined && (
          <div className={styles.scoreRow}>
            <ProgressRing score={score} />
            <span className={styles.scoreLabel}>
              {score >= 90 ? 'Mastered! 🎉' : score >= 70 ? 'Almost there!' : score >= 40 ? 'Getting better' : 'Keep going'}
            </span>
          </div>
        )}
        <p className={styles.text}>{formatText(text)}</p>

        {audioBlob && (
          <audio
            className={styles.audio}
            src={URL.createObjectURL(audioBlob)}
            controls
          />
        )}
      </div>

      {!isBot && <div className={styles.avatar}>🎤</div>}
    </div>
  );
}
