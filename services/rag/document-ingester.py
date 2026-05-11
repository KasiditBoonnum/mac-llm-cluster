#!/usr/bin/env python3
"""Bulk document ingester for QDRANT RAG"""

import requests
import os
import argparse
from pathlib import Path

RAG_URL = "http://localhost:8081"

SUPPORTED = {'.txt', '.md', '.py', '.js', '.ts', '.json', '.yaml', '.yml', '.sh'}


def ingest_file(path: Path):
    if path.suffix not in SUPPORTED:
        print(f"Skipping {path} (unsupported type)")
        return
    with open(path, 'rb') as f:
        resp = requests.post(f"{RAG_URL}/upload", files={"file": (path.name, f)})
    if resp.status_code == 200:
        data = resp.json()
        print(f"✅ {path.name} - {data['chunks']} chunks")
    else:
        print(f"❌ {path.name} - error {resp.status_code}")


def ingest_directory(directory: str):
    for path in Path(directory).rglob('*'):
        if path.is_file():
            ingest_file(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Ingest documents into QDRANT RAG")
    parser.add_argument("path", help="File or directory to ingest")
    args = parser.parse_args()

    target = Path(args.path)
    if target.is_dir():
        ingest_directory(args.path)
    else:
        ingest_file(target)
