require('dotenv').config();
const express = require('express');
const fs = require('fs');
const path = require('path');
const Anthropic = require('@anthropic-ai/sdk');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const HISTORY_FILE = path.join(__dirname, 'conversations.json');
const MAX_HISTORY = 50; // max messages to keep in context

const SYSTEM_PROMPT = `You are a helpful personal assistant with memory across conversations. You remember what the user has told you in previous exchanges and refer back to it naturally when relevant. Be concise, warm, and direct.`;

function loadHistory() {
  try {
    if (fs.existsSync(HISTORY_FILE)) {
      const data = fs.readFileSync(HISTORY_FILE, 'utf8');
      return JSON.parse(data);
    }
  } catch {
    // corrupted file — start fresh
  }
  return [];
}

function saveHistory(messages) {
  // Keep only the last MAX_HISTORY messages to avoid unbounded growth
  const trimmed = messages.slice(-MAX_HISTORY);
  fs.writeFileSync(HISTORY_FILE, JSON.stringify(trimmed, null, 2));
}

// GET /api/history — return stored conversation
app.get('/api/history', (req, res) => {
  res.json(loadHistory());
});

// POST /api/chat — send a message, stream the response, persist both
app.post('/api/chat', async (req, res) => {
  const { message } = req.body;
  if (!message?.trim()) {
    return res.status(400).json({ error: 'Message is required.' });
  }

  const history = loadHistory();
  history.push({ role: 'user', content: message.trim() });

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  let assistantText = '';

  try {
    const stream = await client.messages.stream({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: history,
    });

    for await (const chunk of stream) {
      if (chunk.type === 'content_block_delta' && chunk.delta?.type === 'text_delta') {
        assistantText += chunk.delta.text;
        res.write(`data: ${JSON.stringify({ text: chunk.delta.text })}\n\n`);
      }
    }

    history.push({ role: 'assistant', content: assistantText });
    saveHistory(history);

    res.write('data: [DONE]\n\n');
    res.end();
  } catch (err) {
    console.error('Anthropic API error:', err.message);
    if (!res.headersSent) {
      res.status(500).json({ error: err.message });
    } else {
      res.write(`data: ${JSON.stringify({ error: err.message })}\n\n`);
      res.end();
    }
  }
});

// DELETE /api/history — clear all memory
app.delete('/api/history', (req, res) => {
  fs.writeFileSync(HISTORY_FILE, JSON.stringify([]));
  res.json({ ok: true });
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Memory chatbot running at http://localhost:${PORT}`));
