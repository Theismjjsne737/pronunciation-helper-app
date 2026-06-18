"""
rag_bot.py — interactive RAG Q&A bot
Usage: python rag_bot.py [--top-k 4]
Requires: ANTHROPIC_API_KEY env var, and 'python ingest.py' run first.
"""

import argparse
import os
import sys
import textwrap
from sentence_transformers import SentenceTransformer
import chromadb
import anthropic

CHROMA_PATH = "./chroma_db"
COLLECTION_NAME = "rag_docs"
EMBED_MODEL = "all-MiniLM-L6-v2"
CLAUDE_MODEL = "claude-sonnet-4-6"

SYSTEM_PROMPT = """You are a helpful Q&A assistant. Answer the user's question using ONLY the provided context chunks.

Rules:
- Cite every claim with [Source: <name>] inline.
- If the context does not contain enough information, say so honestly — do not guess.
- Be concise and factual.
- End with a "Sources used:" section listing each cited source once."""


def build_context(chunks: list[dict]) -> str:
    parts = []
    for i, chunk in enumerate(chunks, 1):
        source = chunk["metadata"]["source"]
        text = chunk["document"]
        parts.append(f"[{i}] Source: {source}\n{text}")
    return "\n\n".join(parts)


def format_answer(answer: str) -> str:
    """Wrap long lines for terminal display."""
    lines = []
    for line in answer.split("\n"):
        if len(line) > 100:
            lines.extend(textwrap.wrap(line, width=100))
        else:
            lines.append(line)
    return "\n".join(lines)


class RAGBot:
    def __init__(self, top_k: int = 4):
        self.top_k = top_k

        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            sys.exit("Error: ANTHROPIC_API_KEY environment variable not set.")

        print("Loading embedding model...")
        self.embed_model = SentenceTransformer(EMBED_MODEL)

        print("Connecting to ChromaDB...")
        client = chromadb.PersistentClient(path=CHROMA_PATH)
        try:
            self.collection = client.get_collection(COLLECTION_NAME)
        except Exception:
            sys.exit(
                f"Collection '{COLLECTION_NAME}' not found. Run 'python ingest.py' first."
            )

        self.client = anthropic.Anthropic(api_key=api_key)
        doc_count = self.collection.count()
        print(f"Ready. {doc_count} chunks indexed. Top-k = {self.top_k}\n")

    def retrieve(self, query: str) -> list[dict]:
        query_vec = self.embed_model.encode(query).tolist()
        results = self.collection.query(
            query_embeddings=[query_vec],
            n_results=self.top_k,
            include=["documents", "metadatas", "distances"],
        )
        chunks = []
        for doc, meta, dist in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["distances"][0],
        ):
            chunks.append({"document": doc, "metadata": meta, "distance": dist})
        return chunks

    def answer(self, question: str) -> str:
        chunks = self.retrieve(question)
        context = build_context(chunks)

        user_message = f"Context:\n{context}\n\nQuestion: {question}"

        response = self.client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=1024,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_message}],
        )
        return format_answer(response.content[0].text)

    def chat(self):
        print("RAG Q&A Bot — type 'quit' or 'exit' to stop.\n")
        print("=" * 60)
        while True:
            try:
                question = input("\nYou: ").strip()
            except (EOFError, KeyboardInterrupt):
                print("\nGoodbye.")
                break

            if not question:
                continue
            if question.lower() in {"quit", "exit", "q"}:
                print("Goodbye.")
                break

            print("\nSearching knowledge base...")
            answer = self.answer(question)
            print(f"\nBot:\n{answer}")
            print("\n" + "-" * 60)


def single_query(question: str, top_k: int = 4):
    """Programmatic use: returns answer string."""
    bot = RAGBot(top_k=top_k)
    return bot.answer(question)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="RAG Q&A Bot")
    parser.add_argument("--top-k", type=int, default=4, help="Number of chunks to retrieve")
    parser.add_argument("--query", type=str, default=None, help="Single query (non-interactive)")
    args = parser.parse_args()

    bot = RAGBot(top_k=args.top_k)
    if args.query:
        print(bot.answer(args.query))
    else:
        bot.chat()
