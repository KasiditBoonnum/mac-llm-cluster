#!/usr/bin/env python3
"""QDRANT RAG Server"""

from fastapi import FastAPI, UploadFile, HTTPException
from pydantic import BaseModel
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, VectorParams, PointStruct
from sentence_transformers import SentenceTransformer
import uvicorn
import uuid

app = FastAPI(title="LLM Cluster RAG API")
qdrant = QdrantClient(url="http://localhost:6333")
embedder = SentenceTransformer('all-MiniLM-L6-v2')

COLLECTION = "documents"

# Ensure collection exists
try:
    qdrant.create_collection(
        collection_name=COLLECTION,
        vectors_config=VectorParams(size=384, distance=Distance.COSINE)
    )
except Exception:
    pass


class SearchRequest(BaseModel):
    query: str
    limit: int = 5


@app.post("/upload")
async def upload_document(file: UploadFile):
    content = (await file.read()).decode('utf-8', errors='ignore')
    chunks = [content[i:i+500] for i in range(0, len(content), 500)]
    vectors = embedder.encode(chunks).tolist()
    points = [
        PointStruct(id=str(uuid.uuid4()), vector=v,
                    payload={"text": c, "filename": file.filename, "chunk": i})
        for i, (c, v) in enumerate(zip(chunks, vectors))
    ]
    qdrant.upsert(collection_name=COLLECTION, points=points)
    return {"status": "uploaded", "chunks": len(chunks), "filename": file.filename}


@app.post("/search")
async def search(req: SearchRequest):
    vector = embedder.encode(req.query).tolist()
    results = qdrant.search(collection_name=COLLECTION, query_vector=vector, limit=req.limit)
    return {"results": [{"text": r.payload.get("text"), "score": r.score} for r in results]}


@app.get("/health")
async def health():
    return {"status": "healthy"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8081)
