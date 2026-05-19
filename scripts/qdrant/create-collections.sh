#!/bin/bash
# Initialize QDRANT collections

QDRANT_URL="http://localhost:6333"

echo "Creating QDRANT collections..."

# Documents collection (1024-dim for BAAI/bge-m3)
curl -s -X PUT "$QDRANT_URL/collections/documents" \
    -H "Content-Type: application/json" \
    -d '{
        "vectors": {
            "size": 1024,
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
