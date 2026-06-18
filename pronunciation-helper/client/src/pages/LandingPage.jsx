import { useState } from 'react';
import styles from './LandingPage.module.css';

const EXAMPLE_NAMES = ['Siobhán', 'Nguyen', 'Przemysław', 'Aoife', 'Xiomara', 'Malachy'];

export default function LandingPage({ onStart }) {
  const [name, setName] = useState('');
  const [focused, setFocused] = useState(false);

  const handleSubmit = (e) => {
    e.preventDefault();
    const trimmed = name.trim();
    if (trimmed) onStart(trimmed);
  };

  const handleExample = (n) => {
    setName(n);
  };

  return (
    <div className={styles.page}>
      {/* Background blobs */}
      <div className={styles.blob1} aria-hidden />
      <div className={styles.blob2} aria-hidden />

      <div className={styles.container}>
        {/* Logo */}
        <div className={styles.logo}>
          <span className={styles.logoIcon}>🎤</span>
          <span className={styles.logoText}>LingoLab</span>
        </div>

        {/* Hero */}
        <div className={styles.hero}>
          <h1 className={styles.headline}>
            Perfect your pronunciation<br />
            <span className={styles.highlight}>of any name</span>
          </h1>
          <p className={styles.subheadline}>
            Say a name, get instant AI-powered feedback, and keep improving until you nail it. No embarrassment, just practice.
          </p>
        </div>

        {/* Input form */}
        <form className={styles.form} onSubmit={handleSubmit}>
          <div className={`${styles.inputWrapper} ${focused ? styles.inputWrapperFocused : ''}`}>
            <span className={styles.inputIcon}>✏️</span>
            <input
              className={styles.input}
              type="text"
              placeholder="Enter a name to practice…"
              value={name}
              onChange={(e) => setName(e.target.value)}
              onFocus={() => setFocused(true)}
              onBlur={() => setFocused(false)}
              autoFocus
              spellCheck={false}
            />
          </div>
          <button
            className={styles.startBtn}
            type="submit"
            disabled={!name.trim()}
          >
            Start Practicing →
          </button>
        </form>

        {/* Example names */}
        <div className={styles.examples}>
          <p className={styles.examplesLabel}>Try a tricky one:</p>
          <div className={styles.chips}>
            {EXAMPLE_NAMES.map((n) => (
              <button
                key={n}
                className={`${styles.chip} ${name === n ? styles.chipActive : ''}`}
                type="button"
                onClick={() => handleExample(n)}
              >
                {n}
              </button>
            ))}
          </div>
        </div>

        {/* Feature pills */}
        <div className={styles.features}>
          {[
            { icon: '🤖', text: 'AI-powered analysis' },
            { icon: '📈', text: 'Score every attempt' },
            { icon: '🔄', text: 'Iterative coaching' },
          ].map(({ icon, text }) => (
            <div key={text} className={styles.featurePill}>
              <span>{icon}</span>
              <span>{text}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
