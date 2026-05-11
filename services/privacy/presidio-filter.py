#!/usr/bin/env python3
"""PII detection and removal using Microsoft Presidio"""

from presidio_analyzer import AnalyzerEngine
from presidio_anonymizer import AnonymizerEngine
from fastapi import FastAPI
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="PII Filter")
analyzer = AnalyzerEngine()
anonymizer = AnonymizerEngine()

PII_ENTITIES = ["PERSON", "EMAIL_ADDRESS", "PHONE_NUMBER", "CREDIT_CARD",
                "IP_ADDRESS", "LOCATION", "NRP", "IBAN_CODE"]


class FilterRequest(BaseModel):
    text: str
    language: str = "en"


@app.post("/filter")
def filter_pii(req: FilterRequest):
    results = analyzer.analyze(text=req.text, entities=PII_ENTITIES, language=req.language)
    anonymized = anonymizer.anonymize(text=req.text, analyzer_results=results)
    return {
        "filtered_text": anonymized.text,
        "pii_found": len(results),
        "entities": [{"type": r.entity_type, "score": r.score} for r in results]
    }


@app.post("/analyze")
def analyze_pii(req: FilterRequest):
    results = analyzer.analyze(text=req.text, entities=PII_ENTITIES, language=req.language)
    return {"entities": [{"type": r.entity_type, "score": r.score, "start": r.start, "end": r.end}
                         for r in results]}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8083)
