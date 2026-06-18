import { useMemo } from 'react';
import styles from './Confetti.module.css';

const COLORS = ['#4F46E5', '#7C3AED', '#06B6D4', '#10B981', '#F59E0B', '#EF4444', '#EC4899'];

export default function Confetti() {
  const pieces = useMemo(() =>
    Array.from({ length: 60 }, (_, i) => ({
      id: i,
      left: Math.random() * 100,
      delay: Math.random() * 3,
      duration: 3 + Math.random() * 3,
      color: COLORS[Math.floor(Math.random() * COLORS.length)],
      size: 6 + Math.random() * 8,
      rotate: Math.random() * 360,
    })),
  []);

  return (
    <div className={styles.container} aria-hidden>
      {pieces.map((p) => (
        <div
          key={p.id}
          className={styles.piece}
          style={{
            left: `${p.left}%`,
            width: p.size,
            height: p.size * (0.5 + Math.random() * 0.8),
            background: p.color,
            borderRadius: Math.random() > 0.5 ? '50%' : '2px',
            animationDuration: `${p.duration}s`,
            animationDelay: `${p.delay}s`,
            transform: `rotate(${p.rotate}deg)`,
          }}
        />
      ))}
    </div>
  );
}
