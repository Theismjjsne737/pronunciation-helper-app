"""
ingest.py — chunk documents, embed with SentenceTransformers, store in ChromaDB
Usage: python ingest.py [--docs-dir docs/] [--chunk-size 400] [--overlap 80]
"""

import argparse
import re
import os
from pathlib import Path
from sentence_transformers import SentenceTransformer
import chromadb

CHROMA_PATH = "./chroma_db"
COLLECTION_NAME = "rag_docs"


def chunk_text(text: str, chunk_size: int, overlap: int) -> list[str]:
    """Split text into overlapping chunks on sentence boundaries."""
    # Split into sentences
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    chunks, current, current_len = [], [], 0

    for sentence in sentences:
        words = sentence.split()
        word_count = len(words)

        if current_len + word_count > chunk_size and current:
            chunks.append(" ".join(current))
            # Keep overlap words from the end
            overlap_words = current[-overlap:] if overlap < len(current) else current
            current = overlap_words.copy()
            current_len = len(current)

        current.extend(words)
        current_len += word_count

    if current:
        chunks.append(" ".join(current))

    return [c for c in chunks if len(c.split()) >= 10]  # drop tiny fragments


def load_documents(docs_dir: str) -> list[dict]:
    """Load .txt files; use '--- Document: <name> ---' headers as doc boundaries."""
    docs = []
    for path in sorted(Path(docs_dir).glob("**/*.txt")):
        raw = path.read_text(encoding="utf-8")
        # Split on section headers if present
        sections = re.split(r"---\s*Document:\s*(.+?)\s*---", raw)
        if len(sections) > 1:
            # sections: [pre, title1, body1, title2, body2, ...]
            for i in range(1, len(sections), 2):
                title = sections[i].strip()
                body = sections[i + 1].strip() if i + 1 < len(sections) else ""
                if body:
                    docs.append({"source": title, "file": path.name, "text": body})
        else:
            docs.append({"source": path.stem, "file": path.name, "text": raw.strip()})
    return docs


def ingest(docs_dir: str = "docs/", chunk_size: int = 400, overlap: int = 80):
    print(f"Loading documents from '{docs_dir}'...")
    documents = load_documents(docs_dir)
    print(f"  Found {len(documents)} document(s).")

    print("Loading embedding model (all-MiniLM-L6-v2)...")
    model = SentenceTransformer("all-MiniLM-L6-v2")

    print(f"Chunking (size={chunk_size} words, overlap={overlap} words)...")
    all_chunks, all_ids, all_meta = [], [], []
    for doc in documents:
        chunks = chunk_text(doc["text"], chunk_size, overlap)
        for idx, chunk in enumerate(chunks):
            chunk_id = f"{doc['source']}::chunk_{idx}"
            all_chunks.append(chunk)
            all_ids.append(chunk_id)
            all_meta.append({"source": doc["source"], "file": doc["file"], "chunk_idx": idx})

    print(f"  Total chunks: {len(all_chunks)}")

    print("Embedding chunks...")
    embeddings = model.encode(all_chunks, show_progress_bar=True).tolist()

    print(f"Storing in ChromaDB at '{CHROMA_PATH}'...")
    client = chromadb.PersistentClient(path=CHROMA_PATH)
    # Reset collection if it already exists
    try:
        client.delete_collection(COLLECTION_NAME)
    except Exception:
        pass
    collection = client.create_collection(COLLECTION_NAME)

    # ChromaDB upsert in batches of 500
    batch = 500
    for start in range(0, len(all_chunks), batch):
        collection.add(
            ids=all_ids[start : start + batch],
            documents=all_chunks[start : start + batch],
            embeddings=embeddings[start : start + batch],
            metadatas=all_meta[start : start + batch],
        )

    print(f"Ingestion complete. {len(all_chunks)} chunks stored.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--docs-dir", default="docs/")
    parser.add_argument("--chunk-size", type=int, default=400)
    parser.add_argument("--overlap", type=int, default=80)
    args = parser.parse_args()
    ingest(args.docs_dir, args.chunk_size, args.overlap)
