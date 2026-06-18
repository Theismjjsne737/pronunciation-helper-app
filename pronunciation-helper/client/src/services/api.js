const BASE = '/api';

export async function fetchTTS(text) {
  const res = await fetch(`${BASE}/tts`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ text }),
  });
  if (!res.ok) {
    const data = await res.json().catch(() => ({}));
    if (data.unconfigured) return null; // TTS not yet configured
    throw new Error(`TTS failed: ${res.status}`);
  }
  const blob = await res.blob();
  return URL.createObjectURL(blob);
}

export async function analyzeAudio(audioBlob, targetName, attemptNumber) {
  const form = new FormData();
  form.append('audio', audioBlob, 'recording.webm');
  form.append('targetName', targetName);
  form.append('attemptNumber', String(attemptNumber));

  const res = await fetch(`${BASE}/analyze`, { method: 'POST', body: form });
  if (!res.ok) throw new Error(`Analyze failed: ${res.status}`);
  return res.json(); // { transcription, score, feedback }
}
