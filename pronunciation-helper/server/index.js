import { config as loadEnv } from 'dotenv';
loadEnv({ override: true }); // override any empty shell vars with values from .env
import express from 'express';
import cors from 'cors';
import multer from 'multer';
import FormData from 'form-data';
import Anthropic from '@anthropic-ai/sdk';

// ── Startup config check ─────────────────────────────────────────────────────
const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY?.trim() || null;
const VOICE_ID = process.env.ELEVENLABS_VOICE_ID?.trim() || 'EXAVITQu4vr4xnSDxMaL';
const STT_MODEL = process.env.ELEVENLABS_STT_MODEL?.trim() || 'scribe_v1';
const PORT = Number(process.env.PORT) || 3005;

console.log('─────────────────────────────────────');
console.log('  LingoLab API Server');
console.log('─────────────────────────────────────');
console.log(`  ElevenLabs key : ${ELEVENLABS_API_KEY ? '✓ configured' : '✗ MISSING — add ELEVENLABS_API_KEY to server/.env'}`);
console.log(`  Anthropic key  : ${process.env.ANTHROPIC_API_KEY ? '✓ configured' : '✗ MISSING — add ANTHROPIC_API_KEY to server/.env'}`);
console.log(`  Voice ID       : ${VOICE_ID}`);
console.log(`  STT model      : ${STT_MODEL}`);
console.log('─────────────────────────────────────');

const app = express();
const upload = multer({ storage: multer.memoryStorage() });
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

app.use(cors({ origin: 'http://localhost:5173' }));
app.use(express.json());

// ── Health / config status ───────────────────────────────────────────────────
app.get('/api/health', (_, res) => res.json({
  ok: true,
  elevenlabs: !!ELEVENLABS_API_KEY,
  anthropic: !!process.env.ANTHROPIC_API_KEY,
}));

// ── Text-to-speech ───────────────────────────────────────────────────────────
app.post('/api/tts', async (req, res) => {
  const { text } = req.body;
  if (!text) return res.status(400).json({ error: 'text required' });

  if (!ELEVENLABS_API_KEY) {
    return res.status(503).json({
      error: 'ELEVENLABS_API_KEY not configured',
      unconfigured: true,
    });
  }

  try {
    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}`,
      {
        method: 'POST',
        headers: {
          'xi-api-key': ELEVENLABS_API_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          text,
          model_id: 'eleven_multilingual_v2',
          voice_settings: { stability: 0.5, similarity_boost: 0.75 },
        }),
      }
    );

    if (!response.ok) {
      const err = await response.text();
      console.error('ElevenLabs TTS error:', err);
      return res.status(response.status).json({ error: 'TTS request failed — check your ElevenLabs API key' });
    }

    const audioBuffer = await response.arrayBuffer();
    res.set('Content-Type', 'audio/mpeg');
    res.send(Buffer.from(audioBuffer));
  } catch (err) {
    console.error('TTS error:', err);
    res.status(500).json({ error: 'TTS request failed' });
  }
});

// ── Pronunciation analysis ───────────────────────────────────────────────────
app.post('/api/analyze', upload.single('audio'), async (req, res) => {
  const { targetName, attemptNumber } = req.body;
  const audioBuffer = req.file?.buffer;

  if (!targetName || !audioBuffer) {
    return res.status(400).json({ error: 'targetName and audio required' });
  }

  let transcription = null;

  if (ELEVENLABS_API_KEY) {
    try {
      const form = new FormData();
      form.append('audio', audioBuffer, { filename: 'recording.webm', contentType: 'audio/webm' });
      form.append('model_id', STT_MODEL);

      const sttRes = await fetch('https://api.elevenlabs.io/v1/speech-to-text', {
        method: 'POST',
        headers: { 'xi-api-key': ELEVENLABS_API_KEY, ...form.getHeaders() },
        body: form,
      });

      if (sttRes.ok) {
        const sttData = await sttRes.json();
        transcription = sttData.text?.trim() ?? null;
      } else {
        console.warn('STT non-OK:', await sttRes.text());
      }
    } catch (err) {
      console.warn('STT error (falling back to phonetic-only scoring):', err.message);
    }
  }

  const score = computePhoneticScore(targetName, transcription);
  const feedback = await generateFeedback(targetName, transcription, score, Number(attemptNumber));

  res.json({ transcription, score, feedback });
});

// ── Phonetic scoring (Levenshtein) ───────────────────────────────────────────
function computePhoneticScore(target, transcription) {
  if (!transcription) return Math.max(20, 40 - (Number(target.length) * 2));

  const a = normalize(target);
  const b = normalize(transcription);
  if (a === b) return 100;

  const dist = levenshtein(a, b);
  const raw = Math.round((1 - dist / Math.max(a.length, b.length)) * 100);
  return Math.max(10, Math.min(99, raw));
}

function normalize(s) {
  return s.toLowerCase().replace(/[^a-z]/g, '');
}

function levenshtein(a, b) {
  const m = a.length, n = b.length;
  const dp = Array.from({ length: m + 1 }, (_, i) =>
    Array.from({ length: n + 1 }, (_, j) => i === 0 ? j : j === 0 ? i : 0)
  );
  for (let i = 1; i <= m; i++) {
    for (let j = 1; j <= n; j++) {
      dp[i][j] = a[i - 1] === b[j - 1]
        ? dp[i - 1][j - 1]
        : 1 + Math.min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]);
    }
  }
  return dp[m][n];
}

// ── Claude feedback generation ───────────────────────────────────────────────
async function generateFeedback(targetName, transcription, score, attempt) {
  if (!process.env.ANTHROPIC_API_KEY) {
    if (score >= 90) return `Excellent! Your pronunciation of "${targetName}" is spot-on. You nailed it!`;
    if (score >= 70) return `You're ${score}% there! Focus on the vowel sounds and try again — you're very close.`;
    if (score >= 50) return `You're ${score}% there! Listen carefully to the example, then try matching the rhythm and stress pattern.`;
    return `You're ${score}% there. Don't worry — this name takes practice. Break it into syllables and say each one slowly.`;
  }

  const transcriptNote = transcription
    ? `The user said: "${transcription}" (detected by speech recognition).`
    : 'Speech recognition could not detect clear audio — remind them to speak clearly into the mic.';

  const prompt = `You are a friendly, encouraging pronunciation coach for the app LingoLab.

The user is practicing the name: "${targetName}"
${transcriptNote}
Pronunciation score: ${score}/100
Attempt number: ${attempt}

Write a SHORT (2-3 sentence) response that:
1. Tells them their score in a natural way (e.g. "You're ${score}% there!")
2. Gives ONE specific, actionable pronunciation tip referencing the actual letters/syllables in "${targetName}".
3. Encourages them to try again

${score >= 90 ? 'They have achieved excellent pronunciation — congratulate them warmly and tell them they have mastered this name!' : ''}
${attempt >= 5 && score < 50 ? 'They have been struggling — be extra encouraging and suggest they listen to the example pronunciation again.' : ''}

Keep it warm, specific, and under 60 words.`;

  try {
    const msg = await anthropic.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 150,
      messages: [{ role: 'user', content: prompt }],
    });
    return msg.content[0].text.trim();
  } catch (err) {
    console.error('Claude feedback error:', err.message);
    return `You're ${score}% there! Keep focusing on "${targetName}" — say it slowly, syllable by syllable.`;
  }
}

app.listen(PORT, () => console.log(`\n  Ready at http://localhost:${PORT}\n`));
