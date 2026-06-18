"""
Resume ATS Analyzer — parses a PDF resume, compares it against a job description,
and returns a structured JSON score with improvement suggestions.
"""

import argparse
import json
import sys
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()

import pdfplumber
import anthropic
from pydantic import BaseModel


# ── Pydantic output schema ──────────────────────────────────────────────────

class KeywordMatch(BaseModel):
    keyword: str
    found_in_resume: bool
    context: str  # where it appears in the JD or resume


class SectionFeedback(BaseModel):
    section: str          # e.g. "Work Experience", "Skills", "Education"
    score: int            # 0–100
    feedback: str
    suggestions: list[str]


class ATSResult(BaseModel):
    overall_score: int                    # 0–100
    keyword_match_rate: float             # 0.0–1.0
    keywords: list[KeywordMatch]
    section_feedback: list[SectionFeedback]
    top_missing_keywords: list[str]
    formatting_issues: list[str]
    strengths: list[str]
    summary: str


# ── PDF extraction ──────────────────────────────────────────────────────────

def extract_text_from_pdf(path: str) -> str:
    text_parts = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            page_text = page.extract_text()
            if page_text:
                text_parts.append(page_text)
    return "\n".join(text_parts)


def extract_text_from_file(path: str) -> str:
    p = Path(path)
    if p.suffix.lower() == ".pdf":
        return extract_text_from_pdf(path)
    return p.read_text(encoding="utf-8")


# ── Claude analysis ─────────────────────────────────────────────────────────

SYSTEM_PROMPT = """You are an expert ATS (Applicant Tracking System) analyst and career coach.
Your job is to evaluate a resume against a job description and provide detailed, actionable feedback.

You must respond with valid JSON that exactly matches the requested schema.
Be precise with scores (0–100 integers) and ensure keyword_match_rate is a float between 0.0 and 1.0.
"""

USER_TEMPLATE = """Analyze the following resume against the job description and return a JSON object
matching the ATSResult schema exactly.

=== JOB DESCRIPTION ===
{job_description}

=== RESUME ===
{resume_text}

=== ATSResult JSON Schema ===
{{
  "overall_score": <int 0-100>,
  "keyword_match_rate": <float 0.0-1.0>,
  "keywords": [
    {{
      "keyword": "<string>",
      "found_in_resume": <bool>,
      "context": "<where it appears or why it matters>"
    }}
  ],
  "section_feedback": [
    {{
      "section": "<section name>",
      "score": <int 0-100>,
      "feedback": "<assessment>",
      "suggestions": ["<action item>", ...]
    }}
  ],
  "top_missing_keywords": ["<keyword>", ...],
  "formatting_issues": ["<issue>", ...],
  "strengths": ["<strength>", ...],
  "summary": "<2-3 sentence overall assessment>"
}}

Extract all important keywords from the JD (skills, tools, job titles, certifications, action verbs).
Check each keyword against the resume. Be thorough — include at least 15 keywords.
"""


def analyze(resume_text: str, job_description: str, model: str = "claude-opus-4-7") -> ATSResult:
    client = anthropic.Anthropic()

    response = client.messages.create(
        model=model,
        max_tokens=4096,
        thinking={"type": "adaptive"},
        system=SYSTEM_PROMPT,
        output_config={"format": {"type": "json_schema", "schema": ATSResult.model_json_schema()}},
        messages=[
            {
                "role": "user",
                "content": USER_TEMPLATE.format(
                    job_description=job_description,
                    resume_text=resume_text,
                ),
            }
        ],
    )

    text_block = next(b for b in response.content if b.type == "text")
    data = json.loads(text_block.text)
    return ATSResult(**data)


# ── CLI ─────────────────────────────────────────────────────────────────────

def print_report(result: ATSResult) -> None:
    bar = lambda score: "█" * (score // 10) + "░" * (10 - score // 10)

    print("\n" + "=" * 60)
    print("  RESUME ATS ANALYSIS REPORT")
    print("=" * 60)
    print(f"\n  Overall ATS Score:  {result.overall_score}/100  {bar(result.overall_score)}")
    print(f"  Keyword Match Rate: {result.keyword_match_rate:.0%}")
    print(f"\n  Summary:\n  {result.summary}")

    print("\n── Section Scores ──────────────────────────────────────────")
    for s in result.section_feedback:
        print(f"\n  {s.section}  [{s.score}/100]  {bar(s.score)}")
        print(f"  {s.feedback}")
        for tip in s.suggestions:
            print(f"    • {tip}")

    print("\n── Keywords ────────────────────────────────────────────────")
    found = [k for k in result.keywords if k.found_in_resume]
    missing = [k for k in result.keywords if not k.found_in_resume]
    print(f"  ✓ Found ({len(found)}): {', '.join(k.keyword for k in found)}")
    print(f"\n  ✗ Missing ({len(missing)}): {', '.join(k.keyword for k in missing)}")

    if result.top_missing_keywords:
        print(f"\n  ⚠ Top Missing (priority): {', '.join(result.top_missing_keywords)}")

    if result.formatting_issues:
        print("\n── Formatting Issues ───────────────────────────────────────")
        for issue in result.formatting_issues:
            print(f"  ! {issue}")

    if result.strengths:
        print("\n── Strengths ───────────────────────────────────────────────")
        for strength in result.strengths:
            print(f"  ✓ {strength}")

    print("\n" + "=" * 60 + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="ATS Resume Analyzer — score a resume against a job description"
    )
    parser.add_argument("resume", help="Path to resume file (.pdf or .txt)")
    parser.add_argument("job_description", help="Path to job description file (.txt) or inline text")
    parser.add_argument("--json", action="store_true", help="Output raw JSON instead of formatted report")
    parser.add_argument("--model", default="claude-opus-4-7", help="Claude model to use")
    parser.add_argument("--output", help="Save JSON result to this file path")
    args = parser.parse_args()

    # Load resume
    print(f"Loading resume: {args.resume}", file=sys.stderr)
    resume_text = extract_text_from_file(args.resume)
    if not resume_text.strip():
        print("Error: could not extract text from resume", file=sys.stderr)
        sys.exit(1)

    # Load job description (file path or inline text)
    jd_path = Path(args.job_description)
    if jd_path.exists():
        print(f"Loading job description: {args.job_description}", file=sys.stderr)
        job_description = jd_path.read_text(encoding="utf-8")
    else:
        job_description = args.job_description

    if not job_description.strip():
        print("Error: job description is empty", file=sys.stderr)
        sys.exit(1)

    print("Analyzing with Claude...", file=sys.stderr)
    result = analyze(resume_text, job_description, model=args.model)

    if args.json:
        output = result.model_dump_json(indent=2)
        print(output)
    else:
        print_report(result)
        output = result.model_dump_json(indent=2)

    if args.output:
        Path(args.output).write_text(output, encoding="utf-8")
        print(f"JSON saved to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
