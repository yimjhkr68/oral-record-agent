from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

from ingest import router as ingest_router
from query import router as query_router

load_dotenv("../.env")

app = FastAPI(title="Oral Record RAG API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(ingest_router, prefix="/ingest", tags=["수집"])
app.include_router(query_router, prefix="/query",  tags=["질의"])


@app.get("/health")
def health():
    return {"status": "ok"}
