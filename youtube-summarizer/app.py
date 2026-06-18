import os
import tempfile
import textwrap
import gradio as gr
import yt_dlp
import whisper
import anthropic

# Load Whisper model once at startup (base is fast; swap for "small" or "medium" for accuracy)
_whisper_model = None


def get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        _whisper_model = whisper.load_model("base")
    return _whisper_model


def download_audio(url: str, out_dir: str) -> str:
    """Download YouTube audio as mp3, return file path."""
    opts = {
        "format": "bestaudio/best",
        "outtmpl": os.path.join(out_dir, "audio.%(ext)s"),
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "128",
            }
        ],
        "quiet": True,
        "no_warnings": True,
    }
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=True)
        title = info.get("title", "Unknown")

    audio_path = os.path.join(out_dir, "audio.mp3")
    return audio_path, title


def transcribe(audio_path: str) -> str:
    model = get_whisper_model()
    result = model.transcribe(audio_path, fp16=False)
    return result["text"].strip()


def summarize(transcript: str, title: str) -> str:
    client = anthropic.Anthropic()
    prompt = textwrap.dedent(f"""
        You are a concise summarization assistant. Below is the transcript of a YouTube video titled "{title}".

        Your task:
        1. Write a 2-3 sentence TL;DR at the top.
        2. List the 5 key takeaways as bullet points.
        3. If the video covers steps or a process, add a "Steps" section.
        4. Keep the whole summary under 400 words.

        Transcript:
        {transcript[:12000]}
    """).strip()

    message = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


def process(url: str):
    if not url.strip():
        return "Please enter a YouTube URL.", "", ""

    yield "Downloading audio...", "", ""

    try:
        with tempfile.TemporaryDirectory() as tmpdir:
            audio_path, title = download_audio(url.strip(), tmpdir)

            yield f"Transcribing '{title}'... (this may take a minute)", "", ""

            transcript = transcribe(audio_path)

            yield "Generating summary...", transcript, ""

            summary = summarize(transcript, title)

            yield f"Done — '{title}'", transcript, summary

    except Exception as e:
        yield f"Error: {e}", "", ""


# ── Gradio UI ────────────────────────────────────────────────────────────────

with gr.Blocks(title="YouTube Summarizer") as demo:
    gr.Markdown("# YouTube Video Summarizer")
    gr.Markdown(
        "Paste a YouTube URL → get a full transcript + AI summary. "
        "Transcription via **OpenAI Whisper**, summarization via **Claude**."
    )

    with gr.Row():
        url_input = gr.Textbox(
            label="YouTube URL",
            placeholder="https://www.youtube.com/watch?v=...",
            scale=4,
        )
        run_btn = gr.Button("Summarize", variant="primary", scale=1)

    status = gr.Textbox(label="Status", interactive=False)

    with gr.Tabs():
        with gr.Tab("Summary"):
            summary_out = gr.Markdown(label="Summary")
        with gr.Tab("Full Transcript"):
            transcript_out = gr.Textbox(
                label="Transcript", lines=20, interactive=False
            )

    run_btn.click(
        fn=process,
        inputs=url_input,
        outputs=[status, transcript_out, summary_out],
    )
    url_input.submit(
        fn=process,
        inputs=url_input,
        outputs=[status, transcript_out, summary_out],
    )

if __name__ == "__main__":
    demo.launch(theme=gr.themes.Soft())
