"""main.py — Oral Record Agent v4.0 API 서버"""

from pathlib import Path

import os
from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from core.database import init_db
from api.router_ontology           import router as ontology_router
from api.router_triple             import router as triple_router
from api.router_search             import router as search_router
from api.router_records            import router as records_router
from api.router_history            import router as history_router
from api.router_published_ontology import router as published_ontology_router

STATIC_DIR = Path(__file__).parent / "static"

app = FastAPI(
    title="Oral Record Agent v4.0",
    description="구술기록 지식그래프 API",
    version="4.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# DB 초기화 (테이블 없으면 생성)
init_db()

app.include_router(ontology_router)
app.include_router(triple_router)
app.include_router(search_router)
app.include_router(records_router)
app.include_router(history_router)
app.include_router(published_ontology_router)


@app.get("/health", tags=["서버"])
def health():
    return {"status": "ok", "version": "4.0.0"}


@app.get("/", include_in_schema=False)
def ui_root():
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 9000))
    uvicorn.run("main:app", host="127.0.0.1", port=port, reload=False)
