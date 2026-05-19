#!/usr/bin/env python3
"""QDRANT RAG Server with Admin UI"""

from fastapi import FastAPI, UploadFile, HTTPException, File, Query
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path
from pydantic import BaseModel
from qdrant_client import QdrantClient
from qdrant_client.models import (
    Distance, VectorParams, PointStruct,
    Filter, FieldCondition, MatchValue, FilterSelector
)
from sentence_transformers import SentenceTransformer
from collections import defaultdict
import uvicorn
import uuid
import io
import re
import datetime
import unicodedata

try:
    import fitz  # PyMuPDF
    HAS_PDF = True
except ImportError:
    HAS_PDF = False

try:
    from docx import Document as DocxDocument
    HAS_DOCX = True
except ImportError:
    HAS_DOCX = False

try:
    import pytesseract
    from PIL import Image, ImageFilter, ImageEnhance
    HAS_OCR = True
except ImportError:
    HAS_OCR = False

app = FastAPI(title="LLM Cluster RAG API")
qdrant = QdrantClient(url="http://localhost:6333")
embedder = SentenceTransformer('BAAI/bge-m3')

FONTS_DIR = Path(__file__).parent / "fonts"
FONTS_DIR.mkdir(exist_ok=True)
app.mount("/fonts", StaticFiles(directory=FONTS_DIR), name="fonts")

COLLECTION = "documents"
CHUNK_SIZE = 800
CHUNK_OVERLAP = 100

VECTOR_SIZE = len(embedder.encode("test").tolist())

try:
    info = qdrant.get_collection(COLLECTION)
    existing_size = info.config.params.vectors.size
    if existing_size != VECTOR_SIZE:
        qdrant.delete_collection(COLLECTION)
        raise Exception("dimension mismatch — recreating")
except Exception:
    qdrant.create_collection(
        collection_name=COLLECTION,
        vectors_config=VectorParams(size=VECTOR_SIZE, distance=Distance.COSINE)
    )


def normalize(text: str) -> str:
    text = unicodedata.normalize('NFC', text)
    # PyMuPDF splits Thai sara am (ำ U+0E33) into thanthakhat + sara aa
    text = text.replace('ํา', 'ำ')
    # Remove stray spaces between Thai characters caused by glyph-level extraction
    text = re.sub(r'(?<=[฀-๿]) (?=[฀-๿])', '', text)
    # Fix Thai digits misread as Arabic digits by Tesseract OCR
    thai_digits = {'๐':'0','๑':'1','๒':'2','๓':'3','๔':'4',
                   '๕':'5','๖':'6','๗':'7','๘':'8','๙':'9'}
    # Keep Thai digits as-is (don't convert) — fix Arabic→Thai only if surrounded by Thai text
    # Fix common Latin lookalike substitutions from bad PDF font encoding
    lookalikes = {
        'า': 'า', 'ำ': 'ำ',  # catch copy-paste corruption
        '': 'ก', '': 'ข', '': 'ค', '': 'ง',
        '': 'จ', '': 'ช', '': 'ซ', '': 'ญ',
        '': 'ด', '': 'ต', '': 'ถ', '': 'ท',
        '': 'น', '': 'บ', '': 'ป', '': 'ผ',
        '': 'พ', '': 'ฟ', '': 'ม', '': 'ย',
        '': 'ร', '': 'ล', '': 'ว', '': 'ส',
        '': 'ห', '': 'อ', '': 'า', '': 'ิ',
        '': 'ี', '': 'ึ', '': 'ื', '': 'ุ',
        '': 'ู', '': 'เ', '': 'แ', '': 'โ',
        '': 'ใ', '': 'ไ', '': '็', '': '่',
        '': '้', '': '๊', '': '๋', '': 'ั',
        '': 'ำ', '': 'ํ', '': '์',
    }
    for wrong, correct in lookalikes.items():
        text = text.replace(wrong, correct)
    return text


def thai_ratio(text: str) -> float:
    if not text:
        return 0.0
    return sum(1 for c in text if '\u0e00' <= c <= '\u0e7f') / len(text)


def preprocess_for_ocr(img):
    img = img.convert('L')
    img = ImageEnhance.Contrast(img).enhance(2.0)
    img = img.filter(ImageFilter.SHARPEN)
    return img


def extract_text(content: bytes, filename: str) -> str:
    ext = filename.lower().rsplit('.', 1)[-1] if '.' in filename else ''
    if ext == 'pdf' and HAS_PDF:
        doc = fitz.open(stream=content, filetype="pdf")
        text = normalize("\n".join(page.get_text() for page in doc))
        # Fall back to OCR if: no text, or Thai doc with suspiciously low Thai chars (bad font encoding)
        needs_ocr = not text.strip() or (len(text) > 50 and thai_ratio(text) < 0.05)
        if not needs_ocr:
            return text
        if HAS_OCR:
            pages = []
            for page in doc:
                pix = page.get_pixmap(dpi=300)
                img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
                pages.append(pytesseract.image_to_string(
                    img, lang="tha+eng",
                    config="--psm 3 --oem 1"
                ))
            return normalize("\n".join(pages))
        return text
    if ext == 'docx' and HAS_DOCX:
        doc = DocxDocument(io.BytesIO(content))
        return normalize("\n".join(p.text for p in doc.paragraphs if p.text.strip()))
    return normalize(content.decode('utf-8', errors='ignore'))


def chunk_text(text: str) -> list[str]:
    chunks = []
    start = 0
    while start < len(text):
        chunks.append(text[start:start + CHUNK_SIZE])
        start += CHUNK_SIZE - CHUNK_OVERLAP
    return [c for c in chunks if c.strip()]


class SearchRequest(BaseModel):
    query: str
    limit: int = 5


@app.get("/admin", response_class=HTMLResponse)
async def admin_ui():
    return ADMIN_HTML


@app.post("/upload")
async def upload_document(file: UploadFile = File(...)):
    content = await file.read()
    text = extract_text(content, file.filename)
    chunks = chunk_text(text)
    if not chunks:
        raise HTTPException(400, "No text could be extracted from this file")
    vectors = embedder.encode(chunks).tolist()
    now = datetime.datetime.utcnow().isoformat()
    points = [
        PointStruct(
            id=str(uuid.uuid4()),
            vector=v,
            payload={"text": c, "filename": file.filename, "chunk": i, "uploaded_at": now, "file_size": len(content)}
        )
        for i, (c, v) in enumerate(zip(chunks, vectors))
    ]
    qdrant.upsert(collection_name=COLLECTION, points=points)
    return {"status": "uploaded", "chunks": len(chunks), "filename": file.filename}


@app.get("/documents")
async def list_documents():
    stats: dict = defaultdict(lambda: {"chunks": 0, "uploaded_at": "", "file_size": 0})
    offset = None
    while True:
        records, next_offset = qdrant.scroll(
            collection_name=COLLECTION,
            offset=offset,
            limit=1000,
            with_payload=True,
            with_vectors=False,
        )
        for r in records:
            fname = r.payload.get("filename", "unknown")
            stats[fname]["chunks"] += 1
            ts = r.payload.get("uploaded_at", "")
            if ts > stats[fname]["uploaded_at"]:
                stats[fname]["uploaded_at"] = ts
            if not stats[fname]["file_size"]:
                stats[fname]["file_size"] = r.payload.get("file_size", 0)
        if next_offset is None:
            break
        offset = next_offset
    return {"documents": [
        {"filename": k, "chunks": v["chunks"], "uploaded_at": v["uploaded_at"], "file_size": v["file_size"]}
        for k, v in sorted(stats.items())
    ]}


@app.delete("/documents/by-filename")
async def delete_by_filename(filename: str = Query(...)):
    qdrant.delete(
        collection_name=COLLECTION,
        points_selector=FilterSelector(
            filter=Filter(must=[FieldCondition(key="filename", match=MatchValue(value=filename))])
        ),
    )
    return {"status": "deleted", "filename": filename}


@app.get("/stats")
async def get_stats():
    try:
        info = qdrant.get_collection(COLLECTION)
        return {
            "collection": COLLECTION,
            "total_points": info.points_count,
            "pdf_support": HAS_PDF,
            "docx_support": HAS_DOCX,
            "ocr_support": HAS_OCR,
        }
    except Exception as e:
        return {"error": str(e)}


@app.post("/search")
async def search(req: SearchRequest):
    vector = embedder.encode(req.query).tolist()
    results = qdrant.query_points(collection_name=COLLECTION, query=vector, limit=req.limit).points
    return {"results": [
        {"text": r.payload.get("text"), "score": r.score, "filename": r.payload.get("filename")}
        for r in results
    ]}


@app.get("/health")
async def health():
    return {"status": "healthy"}


ADMIN_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>RAG Admin — LLM Cluster</title>
<style>
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20UlLi%20v3.2.ttf') format('truetype'); font-weight: 200; font-style: normal;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20UlLi%20It%20v3.2.ttf') format('truetype'); font-weight: 200; font-style: italic;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20Li%20v3.2.ttf') format('truetype'); font-weight: 300; font-style: normal;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20Li%20It%20v3.2.ttf') format('truetype'); font-weight: 300; font-style: italic;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20v3.2.ttf') format('truetype'); font-weight: 400; font-style: normal;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20It%20v3.2.ttf') format('truetype'); font-weight: 400; font-style: italic;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20Med%20v3.2.ttf') format('truetype'); font-weight: 500; font-style: normal;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20Med%20It%20v3.2.ttf') format('truetype'); font-weight: 500; font-style: italic;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20Bd%20v3.2.ttf') format('truetype'); font-weight: 700; font-style: normal;  font-display: swap; }
  @font-face { font-family: 'DB Ozone X'; src: url('/fonts/DB%20Ozone%20X%20Bd%20It%20v3.2.ttf') format('truetype'); font-weight: 700; font-style: italic;  font-display: swap; }
</style>
<style>
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

:root {
  --bg:           #252a2e;
  --panel:        #2f3337;
  --panel-light:  #363c41;
  --border:       #3a4045;
  --border-dark:  #2a2f33;
  --green:        #03a96b;
  --green-dark:   #028a58;
  --green-mid:    #04c97e;
  --green-dim:    rgba(3,169,107,0.12);
  --green-faint:  rgba(3,169,107,0.05);
  --text:         #dce8e4;
  --text-muted:   #7a8a82;
  --text-dim:     #4e5e58;
  --red:          #ef4444;
  --red-dim:      rgba(239,68,68,0.10);
}

body {
  font-family: 'DB Ozone X', system-ui, sans-serif;
  background: var(--bg);
  color: var(--text);
  min-height: 100vh;
  font-size: 18px;
  line-height: 1.5;
}

/* ── Header ── */
.header {
  background: var(--panel);
  border-bottom: 3px solid var(--green);
  padding: 0 32px;
  height: 74px;
  display: flex;
  align-items: center;
  gap: 16px;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 2px 16px rgba(0,0,0,0.4);
}
.logo-box {
  width: 34px; height: 34px;
  background: var(--green-dim);
  border: 1px solid rgba(3,169,107,0.35);
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: 22px; flex-shrink: 0;
}
.header-title { font-size: 20px; font-weight: 700; color: var(--text); letter-spacing: -0.01em; }
.header-sub   { font-size: 18px; color: var(--text-muted); margin-top: 1px; }
.hdivider { width: 1px; height: 26px; background: var(--border); }

.status-pill {
  display: flex; align-items: center; gap: 7px;
  background: var(--green-dim);
  border: 1px solid rgba(3,169,107,0.3);
  padding: 5px 13px; border-radius: 20px;
  font-size: 15px; color: var(--green); font-weight: 500;
}
.status-pill .dot {
  width: 7px; height: 7px; border-radius: 50%;
  background: var(--green); box-shadow: 0 0 6px var(--green);
}
.status-pill.offline {
  background: rgba(239,68,68,0.08);
  border-color: rgba(239,68,68,0.3);
  color: var(--red);
}
.status-pill.offline .dot { background: var(--red); box-shadow: 0 0 6px var(--red); }

.header-space { flex: 1; }
.support-chips { display: flex; gap: 8px; }
.chip {
  padding: 3px 10px; border-radius: 20px;
  font-size: 18px; font-weight: 600;
}
.chip.on {
  background: var(--green-dim);
  border: 1px solid rgba(3,169,107,0.3);
  color: var(--green);
}
.chip.off {
  background: rgba(239,68,68,0.08);
  border: 1px solid rgba(239,68,68,0.25);
  color: var(--red);
}

/* ── Stats bar ── */
.stats-bar {
  background: var(--panel);
  border-bottom: 1px solid var(--border);
  padding: 0 32px;
  display: flex;
  align-items: stretch;
  height: 64px;
}
.stat-item {
  display: flex; align-items: center; gap: 10px;
  padding-right: 24px; margin-right: 24px;
  border-right: 1px solid var(--border);
}
.stat-item:last-child { border-right: none; margin-right: 0; }
.stat-icon-box {
  width: 28px; height: 28px;
  background: var(--green-dim);
  border-radius: 7px;
  display: flex; align-items: center; justify-content: center;
  font-size: 16px; flex-shrink: 0;
}
.stat-val  { font-size: 24px; font-weight: 700; color: var(--green); line-height: 1; }
.stat-lbl  { font-size: 16px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; margin-top: 2px; }

/* ── Main ── */
.main {
  max-width: 1080px;
  margin: 0 auto;
  padding: 32px 24px;
  display: grid;
  gap: 24px;
}

/* ── Section card ── */
.card {
  background: var(--panel);
  border: 1px solid var(--border);
  border-radius: 12px;
  overflow: hidden;
}
.card-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 14px 20px;
  border-bottom: 1px solid var(--border);
  background: var(--green-faint);
}
.card-title {
  font-size: 20px; font-weight: 700;
  color: var(--text-muted);
  text-transform: uppercase; letter-spacing: 0.08em;
  display: flex; align-items: center; gap: 10px;
}
.card-title::before {
  content: '';
  display: block;
  width: 3px; height: 14px;
  background: var(--green);
  border-radius: 2px;
}
.card-body { padding: 20px; }

/* ── Drop zone ── */
.drop-zone {
  border: 2px dashed var(--border);
  border-radius: 10px;
  padding: 52px 24px;
  text-align: center;
  cursor: pointer;
  transition: border-color 0.2s, background 0.2s;
  user-select: none;
}
.drop-zone:hover,
.drop-zone.drag-over {
  border-color: var(--green);
  background: var(--green-faint);
}
.dz-icon  { font-size: 56px; display: block; margin-bottom: 14px; }
.dz-title { font-size: 20px; font-weight: 600; color: var(--text); margin-bottom: 6px; }
.dz-title span { color: var(--green); }
.dz-sub   { font-size: 15px; color: var(--text-muted); }
input[type=file] { display: none; }

/* Progress bar — green horizontal bar */
.prog-wrap { display: none; margin-top: 18px; }
.prog-labels {
  display: flex; justify-content: space-between;
  font-size: 15px; color: var(--text-muted); margin-bottom: 7px;
}
.prog-track {
  background: var(--bg);
  border-radius: 4px; height: 6px; overflow: hidden;
}
.prog-fill {
  height: 100%;
  background: var(--green);
  width: 0%;
  border-radius: 4px;
  transition: width 0.3s;
}

/* ── Filter ── */
.filter-row { display: flex; gap: 10px; margin-bottom: 14px; }
.filter-input {
  flex: 1;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 9px 14px;
  color: var(--text); font-size: 16px; outline: none;
  transition: border-color 0.2s;
}
.filter-input:focus { border-color: var(--green); }
.filter-input::placeholder { color: var(--text-dim); }

/* ── Table ── */
table { width: 100%; border-collapse: collapse; }
thead th {
  text-align: left;
  font-size: 18px; font-weight: 700;
  color: var(--text-dim);
  text-transform: uppercase; letter-spacing: 0.07em;
  padding: 9px 12px;
  border-bottom: 2px solid var(--green);
}
tbody tr { transition: background 0.1s; }
tbody tr:hover td { background: var(--panel-light); }
tbody td {
  padding: 11px 12px;
  border-bottom: 1px solid var(--border-dark);
  vertical-align: middle;
}
tbody tr:last-child td { border-bottom: none; }
.td-name { font-weight: 500; color: var(--text); word-break: break-all; }
.ext-tag {
  display: inline-block;
  background: var(--green-dim);
  color: var(--green);
  border: 1px solid rgba(3,169,107,0.25);
  padding: 1px 7px; border-radius: 4px;
  font-size: 20px; font-weight: 700;
  text-transform: uppercase;
  margin-right: 8px;
}
.td-chunks { font-weight: 700; color: var(--green); font-size: 20px; }
.td-date   { color: var(--text-muted); font-size: 15px; white-space: nowrap; }
.empty-state td {
  text-align: center; padding: 48px;
  color: var(--text-dim); border-bottom: none;
}

/* ── Buttons ── */
.btn {
  display: inline-flex; align-items: center; gap: 6px;
  padding: 8px 18px; border-radius: 8px;
  font-size: 16px; font-weight: 500;
  cursor: pointer; border: none;
  transition: background 0.2s, opacity 0.2s;
  white-space: nowrap;
}
.btn:disabled { opacity: 0.45; cursor: not-allowed; }
.btn-green {
  background: var(--green); color: #fff;
}
.btn-green:hover:not(:disabled) { background: var(--green-dark); }
.btn-outline {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-muted);
}
.btn-outline:hover:not(:disabled) { background: var(--panel-light); color: var(--text); }
.btn-del {
  background: transparent;
  border: 1px solid rgba(239,68,68,0.35);
  color: var(--red);
  padding: 5px 13px; font-size: 15px;
}
.btn-del:hover:not(:disabled) { background: var(--red-dim); border-color: var(--red); }

/* ── Search ── */
.search-row { display: flex; gap: 10px; margin-bottom: 18px; }
.search-input {
  flex: 1;
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px 16px;
  color: var(--text); font-size: 16px; outline: none;
  transition: border-color 0.2s;
}
.search-input:focus { border-color: var(--green); }
.search-input::placeholder { color: var(--text-dim); }
.limit-sel {
  background: var(--bg);
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 10px 12px;
  color: var(--text); font-size: 18px; outline: none;
  width: 76px;
}

.results-list { display: grid; gap: 10px; }
.result-card {
  background: var(--bg);
  border: 1px solid var(--border);
  border-left: 3px solid var(--green);
  border-radius: 8px;
  padding: 14px 16px;
}
.result-top {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 10px;
}
.result-file { font-size: 15px; color: var(--green); font-weight: 600; }
.score-wrap  { display: flex; align-items: center; gap: 9px; }
.score-track {
  width: 80px; height: 5px;
  background: var(--border);
  border-radius: 3px; overflow: hidden;
}
.score-fill {
  height: 100%;
  background: var(--green);
  border-radius: 3px;
}
.score-num  { font-size: 15px; color: var(--green); font-weight: 700; min-width: 38px; text-align: right; }
.result-text { font-size: 20px; color: var(--text-muted); line-height: 1.75; white-space: pre-wrap; word-break: break-word; }
.no-results { text-align: center; padding: 32px; color: var(--text-dim); font-size: 20px; }

/* ── Toast ── */
.toast {
  position: fixed; bottom: 24px; right: 24px;
  padding: 12px 18px; border-radius: 10px;
  font-size: 20px; font-weight: 500;
  z-index: 200; opacity: 0;
  transform: translateY(10px);
  transition: all 0.25s; pointer-events: none;
  max-width: 320px;
  background: var(--panel);
  border: 1px solid var(--border);
  border-left: 3px solid var(--green);
  color: var(--text);
}
.toast.show { opacity: 1; transform: translateY(0); }
.toast.error { border-left-color: var(--red); color: var(--red); }
</style>
</head>
<body>

<header class="header">
  <div class="logo-box">&#128196;</div>
  <div>
    <div class="header-title">RAG Admin</div>
    <div class="header-sub">LLM Cluster &nbsp;&#183;&nbsp; Knowledge Base</div>
  </div>
  <div class="hdivider"></div>
  <div class="status-pill offline" id="status-pill">
    <div class="dot"></div>
    <span id="status-text">connecting</span>
  </div>
  <div class="header-space"></div>
  <div class="support-chips" id="support-chips"></div>
</header>

<div class="stats-bar">
  <div class="stat-item">
    <div class="stat-icon-box">&#128193;</div>
    <div>
      <div class="stat-val" id="stat-files">—</div>
      <div class="stat-lbl">Documents</div>
    </div>
  </div>
  <div class="stat-item">
    <div class="stat-icon-box">&#9881;</div>
    <div>
      <div class="stat-val" id="stat-chunks">—</div>
      <div class="stat-lbl">Total Chunks</div>
    </div>
  </div>
  <div class="stat-item">
    <div class="stat-icon-box">&#128200;</div>
    <div>
      <div class="stat-val" id="stat-col" style="font-size:16px;padding-top:3px">—</div>
      <div class="stat-lbl">Collection</div>
    </div>
  </div>
</div>

<div class="main">

  <!-- Upload -->
  <div class="card">
    <div class="card-head">
      <span class="card-title">Upload Documents</span>
    </div>
    <div class="card-body">
      <div class="drop-zone" id="drop-zone">
        <span class="dz-icon">&#128196;</span>
        <div class="dz-title"><span>Click to choose files</span> or drag &amp; drop here</div>
        <div class="dz-sub">PDF &nbsp;&#183;&nbsp; DOCX &nbsp;&#183;&nbsp; TXT &nbsp;&#183;&nbsp; MD &nbsp;&#183;&nbsp; CSV &nbsp;&#183;&nbsp; JSON &nbsp;&#183;&nbsp; YAML &nbsp;&#183;&nbsp; PY &nbsp;&#183;&nbsp; JS &nbsp;&#183;&nbsp; TS &nbsp;&#183;&nbsp; SH</div>
      </div>
      <input type="file" id="file-input" multiple
        accept=".pdf,.docx,.txt,.md,.csv,.py,.js,.ts,.json,.yaml,.yml,.sh,.log,.xml,.html"
        style="display:none">
      <div class="prog-wrap" id="prog-wrap">
        <div class="prog-labels">
          <span id="prog-label">Uploading...</span>
          <span id="prog-pct">0%</span>
        </div>
        <div class="prog-track">
          <div class="prog-fill" id="prog-fill"></div>
        </div>
      </div>
    </div>
  </div>

  <!-- Library -->
  <div class="card">
    <div class="card-head">
      <span class="card-title">Document Library</span>
      <button class="btn btn-outline" id="refresh-btn">&#8635;&nbsp; Refresh</button>
    </div>
    <div class="card-body">
      <div class="filter-row">
        <input class="filter-input" id="filter-input" type="text" placeholder="Filter by filename...">
      </div>
      <table>
        <thead>
          <tr>
            <th>Filename</th>
            <th>Size</th>
            <th>Chunks</th>
            <th>Uploaded</th>
            <th></th>
          </tr>
        </thead>
        <tbody id="doc-tbody">
          <tr class="empty-state"><td colspan="4">Loading documents...</td></tr>
        </tbody>
      </table>
      <div id="pagination" style="display:none;align-items:center;justify-content:space-between;padding:12px 4px 0;">
        <span id="page-info" style="font-size:14px;color:var(--text-dim);"></span>
        <div style="display:flex;gap:8px;">
          <button class="btn btn-outline" id="page-first">&laquo;</button>
          <button class="btn btn-outline" id="page-prev">&#8592; Prev</button>
          <button class="btn btn-outline" id="page-next">Next &#8594;</button>
          <button class="btn btn-outline" id="page-last">&raquo;</button>
        </div>
      </div>
    </div>
  </div>

  <!-- Search -->
  <div class="card">
    <div class="card-head">
      <span class="card-title">Test Search</span>
    </div>
    <div class="card-body">
      <div class="search-row">
        <input class="search-input" id="search-input" type="text"
          placeholder="Enter a query to test semantic search...">
        <select class="limit-sel" id="search-limit">
          <option value="3">3</option>
          <option value="5" selected>5</option>
          <option value="10">10</option>
        </select>
        <button class="btn btn-green" id="search-btn">Search</button>
      </div>
      <div id="search-out"></div>
    </div>
  </div>

</div>

<div class="toast" id="toast"></div>

<!-- Replace confirm modal -->
<div id="replace-overlay" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.55);z-index:200;align-items:center;justify-content:center;backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px);">
  <div style="background:#1e2124;border:1px solid #3a3f45;border-radius:12px;padding:32px 28px;max-width:420px;width:90%;box-shadow:0 8px 32px rgba(0,0,0,0.5);">
    <div style="font-size:18px;font-weight:700;color:#f0f2f4;margin-bottom:12px;">File already exists</div>
    <div style="font-size:14px;color:#aab0b6;margin-bottom:8px;">This file is already in the RAG:</div>
    <div id="replace-filename" style="font-size:15px;font-weight:600;color:#03a96b;background:#2f3337;border-radius:6px;padding:10px 14px;margin-bottom:20px;word-break:break-all;"></div>
    <div style="font-size:14px;color:#aab0b6;margin-bottom:24px;">Do you want to replace it with the new version?</div>
    <div style="display:flex;gap:12px;justify-content:flex-end;">
      <button id="replace-cancel" class="btn" style="background:#3a3f45;color:#f0f2f4;">Keep existing</button>
      <button id="replace-confirm" class="btn btn-green">Replace</button>
    </div>
  </div>
</div>

<script>
function fmtSize(bytes) {
  if (!bytes) return '—';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}
function esc(s) {
  return String(s)
    .replace(/&/g,'&amp;').replace(/</g,'&lt;')
    .replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}
function toast(msg, type) {
  var t = document.getElementById('toast');
  t.textContent = msg;
  t.className = 'toast ' + (type || 'success') + ' show';
  clearTimeout(t._t);
  t._t = setTimeout(function() { t.classList.remove('show'); }, 3500);
}

// ── Health ──
function checkHealth() {
  fetch('/health').then(function(r) {
    var ok = r.ok;
    document.getElementById('status-pill').className = 'status-pill' + (ok ? '' : ' offline');
    document.getElementById('status-text').textContent = ok ? 'online' : 'offline';
  }).catch(function() {
    document.getElementById('status-pill').className = 'status-pill offline';
    document.getElementById('status-text').textContent = 'offline';
  });
}

// ── Stats ──
function loadStats() {
  fetch('/stats').then(function(r) { return r.json(); }).then(function(d) {
    if (d.total_points !== undefined)
      document.getElementById('stat-chunks').textContent = d.total_points.toLocaleString();
    if (d.collection)
      document.getElementById('stat-col').textContent = d.collection;
    document.getElementById('support-chips').innerHTML =
      '<span class="chip ' + (d.pdf_support  ? 'on' : 'off') + '">PDF '  + (d.pdf_support  ? '&#10003;' : '&#10007;') + '</span>' +
      '<span class="chip ' + (d.docx_support ? 'on' : 'off') + '">DOCX ' + (d.docx_support ? '&#10003;' : '&#10007;') + '</span>' +
      '<span class="chip ' + (d.ocr_support  ? 'on' : 'off') + '">OCR (TH/EN) '  + (d.ocr_support  ? '&#10003;' : '&#10007;') + '</span>';
  }).catch(function(){});
}

// ── Documents ──
var allDocs = [];
var filteredDocs = [];
var currentPage = 1;
var PAGE_SIZE = 10;

function loadDocuments() {
  document.getElementById('doc-tbody').innerHTML =
    '<tr class="empty-state"><td colspan="4">Loading...</td></tr>';
  fetch('/documents').then(function(r) { return r.json(); }).then(function(d) {
    allDocs = d.documents || [];
    document.getElementById('stat-files').textContent = allDocs.length.toLocaleString();
    filteredDocs = allDocs;
    currentPage = 1;
    renderTable();
  }).catch(function() {
    document.getElementById('doc-tbody').innerHTML =
      '<tr class="empty-state"><td colspan="4" style="color:var(--red)">Failed to load documents.</td></tr>';
  });
}

function renderTable() {
  var tbody = document.getElementById('doc-tbody');
  var pagination = document.getElementById('pagination');
  if (!filteredDocs.length) {
    tbody.innerHTML = '<tr class="empty-state"><td colspan="4">No documents found.</td></tr>';
    pagination.style.display = 'none';
    return;
  }
  var totalPages = Math.ceil(filteredDocs.length / PAGE_SIZE);
  if (currentPage > totalPages) currentPage = totalPages;
  var start = (currentPage - 1) * PAGE_SIZE;
  var pageDocs = filteredDocs.slice(start, start + PAGE_SIZE);
  tbody.innerHTML = pageDocs.map(function(doc) {
    var ext  = doc.filename.includes('.') ? doc.filename.split('.').pop().toUpperCase() : 'FILE';
    var date = doc.uploaded_at ? new Date(doc.uploaded_at + 'Z').toLocaleString() : '—';
    return '<tr>' +
      '<td class="td-name"><span class="ext-tag">' + esc(ext) + '</span>' + esc(doc.filename) + '</td>' +
      '<td class="td-date">' + fmtSize(doc.file_size) + '</td>' +
      '<td class="td-chunks">' + doc.chunks.toLocaleString() + '</td>' +
      '<td class="td-date">' + date + '</td>' +
      '<td><button class="btn btn-del" data-filename="' + esc(doc.filename) + '">Delete</button></td>' +
      '</tr>';
  }).join('');
  pagination.style.display = totalPages > 1 ? 'flex' : 'none';
  document.getElementById('page-info').textContent =
    'Page ' + currentPage + ' of ' + totalPages + ' (' + filteredDocs.length + ' files)';
  document.getElementById('page-first').disabled = currentPage === 1;
  document.getElementById('page-prev').disabled  = currentPage === 1;
  document.getElementById('page-next').disabled  = currentPage === totalPages;
  document.getElementById('page-last').disabled  = currentPage === totalPages;
}

document.getElementById('page-first').addEventListener('click', function() {
  currentPage = 1; renderTable();
});
document.getElementById('page-prev').addEventListener('click', function() {
  if (currentPage > 1) { currentPage--; renderTable(); }
});
document.getElementById('page-next').addEventListener('click', function() {
  var totalPages = Math.ceil(filteredDocs.length / PAGE_SIZE);
  if (currentPage < totalPages) { currentPage++; renderTable(); }
});
document.getElementById('page-last').addEventListener('click', function() {
  currentPage = Math.ceil(filteredDocs.length / PAGE_SIZE); renderTable();
});

document.getElementById('filter-input').addEventListener('input', function() {
  var q = this.value.toLowerCase().trim();
  filteredDocs = q ? allDocs.filter(function(d) { return d.filename.toLowerCase().includes(q); }) : allDocs;
  currentPage = 1;
  renderTable();
});

document.getElementById('doc-tbody').addEventListener('click', function(e) {
  var btn = e.target.closest('[data-filename]');
  if (btn) deleteDoc(btn.dataset.filename);
});

function deleteDoc(filename) {
  if (!confirm('Delete all chunks for "' + filename + '"?\\nThis cannot be undone.')) return;
  fetch('/documents/by-filename?filename=' + encodeURIComponent(filename), { method: 'DELETE' })
    .then(function(r) {
      if (r.ok) {
        toast('Deleted: ' + filename);
        allDocs = allDocs.filter(function(d) { return d.filename !== filename; });
        filteredDocs = filteredDocs.filter(function(d) { return d.filename !== filename; });
        document.getElementById('stat-files').textContent = allDocs.length.toLocaleString();
        renderTable();
        loadStats();
      } else {
        toast('Delete failed', 'error');
      }
    }).catch(function() { toast('Delete failed', 'error'); });
}

// ── Upload ──
function uploadFiles(files) {
  var wrap  = document.getElementById('prog-wrap');
  var fill  = document.getElementById('prog-fill');
  var label = document.getElementById('prog-label');
  var pct   = document.getElementById('prog-pct');
  wrap.style.display = 'block';
  var done = 0;
  function next() {
    if (done >= files.length) {
      fill.style.width = '100%'; pct.textContent = '100%';
      label.textContent = done + ' file' + (done !== 1 ? 's' : '') + ' processed';
      setTimeout(function() { wrap.style.display = 'none'; fill.style.width = '0%'; }, 2500);
      loadDocuments(); loadStats();
      return;
    }
    var file = files[done];
    var p = Math.round((done / files.length) * 100);
    fill.style.width = p + '%'; pct.textContent = p + '%';
    label.textContent = 'Uploading ' + file.name + ' (' + (done + 1) + ' / ' + files.length + ')';
    var exists = allDocs.some(function(d) { return d.filename === file.name; });
    function doUpload() {
      var form = new FormData();
      form.append('file', file);
      fetch('/upload', { method: 'POST', body: form })
        .then(function(r) { return r.json().then(function(d) { return { ok: r.ok, d: d }; }); })
        .then(function(res) {
          if (res.ok) toast('&#10003; ' + res.d.filename + ' — ' + res.d.chunks + ' chunks');
          else toast('Failed: ' + (res.d.detail || file.name), 'error');
        })
        .catch(function() { toast('Error: ' + file.name, 'error'); })
        .finally(function() { done++; next(); });
    }
    if (exists) {
      var overlay = document.getElementById('replace-overlay');
      document.getElementById('replace-filename').textContent = file.name;
      overlay.style.display = 'flex';
      function closeModal() { overlay.style.display = 'none'; }
      document.getElementById('replace-confirm').onclick = function() {
        closeModal();
        fetch('/documents/by-filename?filename=' + encodeURIComponent(file.name), { method: 'DELETE' })
          .then(doUpload).catch(doUpload);
      };
      document.getElementById('replace-cancel').onclick = function() {
        closeModal(); done++; next();
      };
    } else {
      doUpload();
    }
  }
  next();
}

var dz = document.getElementById('drop-zone');
dz.addEventListener('click', function() { document.getElementById('file-input').click(); });
dz.addEventListener('dragover', function(e) { e.preventDefault(); dz.classList.add('drag-over'); });
dz.addEventListener('dragleave', function() { dz.classList.remove('drag-over'); });
dz.addEventListener('drop', function(e) {
  e.preventDefault(); dz.classList.remove('drag-over');
  var files = Array.from(e.dataTransfer.files);
  if (files.length) uploadFiles(files);
});
document.getElementById('file-input').addEventListener('change', function(e) {
  var files = Array.from(e.target.files);
  if (files.length) uploadFiles(files);
  e.target.value = '';
});

// ── Search ──
function doSearch() {
  var q     = document.getElementById('search-input').value.trim();
  var limit = parseInt(document.getElementById('search-limit').value);
  var out   = document.getElementById('search-out');
  if (!q) return;
  out.innerHTML = '<div class="no-results">Searching&#8230;</div>';
  fetch('/search', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query: q, limit: limit })
  }).then(function(r) { return r.json(); }).then(function(d) {
    var results = d.results || [];
    if (!results.length) { out.innerHTML = '<div class="no-results">No results found.</div>'; return; }
    out.innerHTML = '<div class="results-list">' + results.map(function(res) {
      var pct = Math.round(res.score * 100);
      return '<div class="result-card">' +
        '<div class="result-top">' +
        '<span class="result-file">&#128196; ' + esc(res.filename || 'unknown') + '</span>' +
        '<div class="score-wrap">' +
        '<div class="score-track"><div class="score-fill" style="width:' + pct + '%"></div></div>' +
        '<span class="score-num">' + pct + '%</span>' +
        '</div></div>' +
        '<div class="result-text">' + esc(res.text || '') + '</div>' +
        '</div>';
    }).join('') + '</div>';
  }).catch(function() {
    out.innerHTML = '<div class="no-results" style="color:var(--red)">Search failed.</div>';
  });
}

document.getElementById('search-btn').addEventListener('click', doSearch);
document.getElementById('search-input').addEventListener('keydown', function(e) { if (e.key === 'Enter') doSearch(); });
document.getElementById('refresh-btn').addEventListener('click', loadDocuments);

// ── Init ──
checkHealth(); loadStats(); loadDocuments();
setInterval(checkHealth, 30000);
</script>
</body>
</html>"""

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8081)
