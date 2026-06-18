/**
 * Vercel Edge Function — proxies streaming Claude API calls from the iOS app.
 * Deploy: `vercel deploy` from the /backend directory.
 *
 * Env vars required in Vercel dashboard:
 *   ANTHROPIC_API_KEY  — your sk-ant-… key
 *   APP_SECRET         — a random string shared with Config.swift as Config.appSecret
 */
export const config = { runtime: 'edge' };

const CLAUDE_ENDPOINT = 'https://api.anthropic.com/v1/messages';
const ALLOWED_MODELS  = ['claude-opus-4-5', 'claude-sonnet-4-5', 'claude-haiku-4-5'];

export default async function handler(req) {
    // ── Method check ──────────────────────────────────────────
    if (req.method !== 'POST') {
        return new Response('Method Not Allowed', { status: 405 });
    }

    // ── Auth ──────────────────────────────────────────────────
    const secret = req.headers.get('x-app-secret');
    if (!secret || secret !== process.env.APP_SECRET) {
        return new Response('Unauthorized', { status: 401 });
    }

    // ── Parse body ────────────────────────────────────────────
    let body;
    try {
        body = await req.json();
    } catch {
        return new Response('Invalid JSON', { status: 400 });
    }

    const { systemPrompt, messages, model = 'claude-opus-4-5', maxTokens = 512 } = body;

    if (!systemPrompt || !Array.isArray(messages)) {
        return new Response('Missing systemPrompt or messages', { status: 400 });
    }

    if (!ALLOWED_MODELS.includes(model)) {
        return new Response('Model not allowed', { status: 400 });
    }

    // ── Proxy to Claude ───────────────────────────────────────
    const claudeResponse = await fetch(CLAUDE_ENDPOINT, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': process.env.ANTHROPIC_API_KEY,
            'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
            model,
            max_tokens: maxTokens,
            system: systemPrompt,
            messages,
            stream: true,
        }),
    });

    if (!claudeResponse.ok) {
        const error = await claudeResponse.text();
        return new Response(error, { status: claudeResponse.status });
    }

    // ── Stream response back to iOS ───────────────────────────
    return new Response(claudeResponse.body, {
        status: 200,
        headers: {
            'Content-Type': 'text/event-stream',
            'Cache-Control': 'no-cache, no-transform',
            'X-Accel-Buffering': 'no',
        },
    });
}
