import { useState, useCallback, useRef } from 'react';
import { fetchTTS, analyzeAudio } from '../services/api.js';

function botMsg(text, extra = {}) {
  return { id: Date.now() + Math.random(), role: 'bot', text, ...extra };
}
function userMsg(text, extra = {}) {
  return { id: Date.now() + Math.random(), role: 'user', text, ...extra };
}

export function usePronunciationChat(targetName) {
  const [messages, setMessages] = useState([]);
  const [attemptCount, setAttemptCount] = useState(0);
  const [bestScore, setBestScore] = useState(0);
  const [mastered, setMastered] = useState(false);
  const [ttsURL, setTtsURL] = useState(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const initializedRef = useRef(false);

  const push = (msg) => setMessages((prev) => [...prev, msg]);
  const pushTyping = () => {
    const id = Date.now() + Math.random();
    setMessages((prev) => [...prev, { id, role: 'bot', typing: true }]);
    return id;
  };
  const resolveTyping = (id, msg) => {
    setMessages((prev) => prev.map((m) => m.id === id ? { ...msg, id } : m));
  };

  const init = useCallback(async () => {
    if (initializedRef.current) return;
    initializedRef.current = true;
    push(botMsg(`👋 Let's practice **"${targetName}"**! I'll play the correct pronunciation — then it's your turn.`));

    // Try to load TTS
    try {
      const url = await fetchTTS(targetName);
      if (url) {
        setTtsURL(url);
        push(botMsg(`🔊 Listen to the correct pronunciation above, then hit the record button and give it a go!`, { hasTTS: true }));
      } else {
        push(botMsg(`🎙️ ElevenLabs isn't configured yet, so I can't play the correct pronunciation — but I can still score your attempts! Hit the record button whenever you're ready.`));
      }
    } catch {
      push(botMsg(`🎙️ Hit the record button and say **"${targetName}"** — I'll analyze your pronunciation!`));
    }
  }, [targetName]);

  const submitAttempt = useCallback(async (audioBlob) => {
    if (!audioBlob || isProcessing) return;
    setIsProcessing(true);

    const attempt = attemptCount + 1;
    setAttemptCount(attempt);

    push(userMsg(`🎤 Attempt #${attempt}`, { audioBlob }));

    const typingId = pushTyping();

    try {
      const { score, feedback } = await analyzeAudio(audioBlob, targetName, attempt);

      const newBest = Math.max(bestScore, score);
      setBestScore(newBest);

      const isMastered = score >= 90;
      if (isMastered) setMastered(true);

      resolveTyping(typingId, botMsg(feedback, { score, isMastered }));

      if (!isMastered) {
        setTimeout(() => {
          push(botMsg(`Go ahead and say **"${targetName}"** again — you've got this! 💪`));
        }, 600);
      }
    } catch (err) {
      resolveTyping(typingId, botMsg(`Sorry, I had trouble analyzing that. Make sure your microphone is working and try again.`, { isError: true }));
      console.error('Analyze error:', err);
    } finally {
      setIsProcessing(false);
    }
  }, [attemptCount, bestScore, isProcessing, targetName]);

  return { messages, attemptCount, bestScore, mastered, ttsURL, isProcessing, init, submitAttempt };
}
