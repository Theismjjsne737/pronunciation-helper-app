require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const path = require('path');
const express = require('express');
const Anthropic = require('@anthropic-ai/sdk');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const client = new Anthropic.default({ apiKey: process.env.ANTHROPIC_API_KEY });

const TONE_PROMPTS = {
  formal: 'You write with a formal, professional tone. Use precise language, complete sentences, proper grammar, and avoid contractions or colloquialisms.',
  casual: 'You write with a casual, conversational tone. Use everyday language, contractions, and a friendly, approachable style — like you\'re talking to a friend.',
  persuasive: 'You write with a persuasive, compelling tone. Use rhetorical techniques, strong calls to action, emotional appeals, and evidence-based arguments to convince the reader.',
  humorous: 'You write with a witty, lighthearted, humorous tone. Use clever wordplay, friendly jokes, and a fun style — while still delivering the core message clearly.',
  empathetic: 'You write with an empathetic, warm, supportive tone. Acknowledge emotions, use inclusive language, and make the reader feel understood and valued.',
};

const FORMAT_PROMPTS = {
  paragraph: 'Structure your response as flowing prose paragraphs.',
  bullets: 'Structure your response as clear bullet points.',
  email: 'Structure your response as a professional email with Subject, greeting, body, and sign-off.',
  'social-post': 'Structure your response as a concise, engaging social media post (suitable for LinkedIn or Twitter/X). Include relevant hashtags at the end.',
  outline: 'Structure your response as a numbered outline with main points and sub-points.',
};

const LENGTH_PROMPTS = {
  short: 'Keep the response concise — around 50–100 words.',
  medium: 'Aim for a moderate length — around 150–250 words.',
  long: 'Write a comprehensive response — around 350–500 words.',
};

const AUDIENCE_PROMPTS = {
  general: 'Write for a general audience with no assumed domain expertise.',
  professional: 'Write for a professional audience with industry knowledge. Use appropriate jargon where helpful.',
  academic: 'Write for an academic audience. Maintain scholarly rigor, cite reasoning clearly, and use precise terminology.',
  beginner: 'Write for beginners or novices. Avoid jargon, explain concepts simply, and use relatable analogies.',
  executive: 'Write for busy executives. Lead with the key takeaway, be direct, and focus on strategic implications.',
};

app.post('/api/generate', async (req, res) => {
  const { prompt, tone, format, length, audience } = req.body;

  if (!prompt?.trim()) {
    return res.status(400).json({ error: 'Prompt is required.' });
  }

  const toneInstruction = TONE_PROMPTS[tone] || TONE_PROMPTS.formal;
  const formatInstruction = FORMAT_PROMPTS[format] || FORMAT_PROMPTS.paragraph;
  const lengthInstruction = LENGTH_PROMPTS[length] || LENGTH_PROMPTS.medium;
  const audienceInstruction = AUDIENCE_PROMPTS[audience] || AUDIENCE_PROMPTS.general;

  const systemPrompt = `You are an expert writing assistant. ${toneInstruction}

${formatInstruction} ${lengthInstruction}

Audience: ${audienceInstruction}

Respond only with the generated content — no preamble, no meta-commentary, no "Here is your response:" or similar phrases.`;

  try {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');

    const stream = await client.messages.stream({
      model: 'claude-sonnet-4-6',
      max_tokens: 1024,
      system: systemPrompt,
      messages: [{ role: 'user', content: prompt }],
    });

    for await (const chunk of stream) {
      if (chunk.type === 'content_block_delta' && chunk.delta?.type === 'text_delta') {
        res.write(`data: ${JSON.stringify({ text: chunk.delta.text })}\n\n`);
      }
    }

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

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Writing assistant running at http://localhost:${PORT}`));
