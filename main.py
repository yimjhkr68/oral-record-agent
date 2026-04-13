"""main.py — Oral Record Agent v5.0 API 서버"""

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
from api.router_settings           import router as settings_router
from api.router_graph_layout       import router as graph_layout_router
from api.router_cluster            import router as cluster_router
from api.router_rdf_migration      import router as rdf_migration_router
from api.router_rdf_ontology       import router as rdf_ontology_router
from api.router_rdf_validate       import router as rdf_validate_router
from api.router_semantic_search    import router as semantic_search_router
from api.router_rdf_publish        import router as rdf_publish_router
from api.router_rdf_export         import router as rdf_export_router

STATIC_DIR = Path(__file__).parent / "static"

app = FastAPI(
    title="Oral Record Agent v5.0",
    description="구술기록 지식그래프 + RDF 온톨로지 공표 API",
    version="5.0.0",
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
app.include_router(settings_router)
app.include_router(graph_layout_router)
app.include_router(cluster_router)

# v5.0 RDF 관련 라우터
app.include_router(rdf_migration_router)
app.include_router(rdf_ontology_router)
app.include_router(rdf_validate_router)
app.include_router(semantic_search_router)
app.include_router(rdf_publish_router)
app.include_router(rdf_export_router)


@app.get("/health", tags=["서버"])
def health():
    return {"status": "ok", "version": "5.0.0"}


@app.get("/", include_in_schema=False)
def ui_root():
    return FileResponse(STATIC_DIR / "index.html")


app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 9000))
    uvicorn.run("main:app", host="127.0.0.1", port=port, reload=False)
