#!/bin/bash
# Initialize QDRANT collections

QDRANT_URL="http://localhost:6333"

echo "Creating QDRANT collections..."

# Documents collection (384-dim for all-MiniLM-L6-v2)
curl -s -X PUT "$QDRANT_URL/collections/documents" \
    -H "Content-Type: application/json" \
    -d '{
        "vectors": {
            "size": 384,
            "distance": "Cosine"
        }
    }' | python3 -m json.tool

# Code collection (768-dim for code embeddings)
curl -s -X PUT "$QDRANT_URL/collections/code" \
    -H "Content-Type: application/json" \
    -d '{
        "vectors": {
            "size": 768,
            "distance": "Cosine"
        }
    }' | python3 -m json.tool

echo "✅ Collections created"
curl -s "$QDRANT_URL/collections" | python3 -m json.tool
