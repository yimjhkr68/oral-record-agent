"""api/router_triple.py — 트리플 API 엔드포인트 (F5)"""

from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from graph.graph_db import GraphDB, TripleStatus
from graph.triple_manager import TripleManager
from pipeline.triple_extractor import TripleExtractor
from api.router_ontology import get_manager as get_ontology_manager

router = APIRouter(prefix="/api/triples", tags=["트리플"])

# 싱글톤
_db: Optional[GraphDB] = None
_tm: Optional[TripleManager] = None
_extractor: Optional[TripleExtractor] = None


def get_triple_manager() -> TripleManager:
    global _db, _tm
    if _tm is None:
        _db = GraphDB()
        _tm = TripleManager(_db)
    return _tm


def get_extractor() -> TripleExtractor:
    global _extractor
    if _extractor is None:
        _extractor = TripleExtractor(
            ontology_manager=get_ontology_manager(),
            triple_manager=get_triple_manager(),
        )
    return _extractor


# ── 요청 스키마 ────────────────────────────────────────────────────────────────

class CreateRequest(BaseModel):
    subject:          str
    subject_type:     str
    predicate:        str
    object:           str
    object_type:      str
    ontology_version: str
    source_record_id: Optional[str]  = None
    confidence:       float          = 1.0
    note:             str            = ""


class UpdateRequest(BaseModel):
    predicate:   Optional[str]   = None
    object:      Optional[str]   = None
    object_type: Optional[str]   = None
    confidence:  Optional[float] = None
    note:        Optional[str]   = None


class ArchiveRequest(BaseModel):
    reason: str = ""


class ExtractRequest(BaseModel):
    content:             str
    ontology_version_id: str
    source_record_id:    Optional[str] = None


# ── 엔드포인트 ─────────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
def create_triple(body: CreateRequest):
    """트리플 생성 (동일 S+P+O 존재 시 기존 반환)."""
    return get_triple_manager().create(
        subject=body.subject,
        subject_type=body.subject_type,
        predicate=body.predicate,
        object_=body.object,
        object_type=body.object_type,
        ontology_version=body.ontology_version,
        source_record_id=body.source_record_id,
        confidence=body.confidence,
        note=body.note,
    )


@router.get("/")
def search_triples(
    q:       str            = Query("",       description="검색어"),
    version: Optional[str]  = Query(None,     description="온톨로지 버전"),
    status:  str            = Query("active", description="active | archived"),
):
    """검색어 기반 트리플 서브그래프 조회."""
    try:
        triple_status = TripleStatus(status)
    except ValueError:
        raise HTTPException(status_code=400,
                            detail=f"유효하지 않은 status: {status!r}")
    return get_triple_manager().search(
        query=q, ontology_version=version, status=triple_status
    )


@router.get("/stats")
def triple_stats():
    """트리플 통계."""
    return get_triple_manager().stats()


@router.get("/{triple_id}")
def get_triple(triple_id: str):
    """트리플 단건 조회."""
    try:
        return get_triple_manager().get(triple_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/{triple_id}")
def update_triple(triple_id: str, body: UpdateRequest):
    """트리플 수정."""
    try:
        return get_triple_manager().update(
            triple_id,
            predicate=body.predicate,
            object_=body.object,
            object_type=body.object_type,
            confidence=body.confidence,
            note=body.note,
        )
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{triple_id}", status_code=204)
def delete_triple(triple_id: str):
    """트리플 영구 삭제."""
    try:
        get_triple_manager().delete(triple_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{triple_id}/archive")
def archive_triple(triple_id: str, body: ArchiveRequest):
    """트리플 아카이브."""
    try:
        return get_triple_manager().archive(triple_id, reason=body.reason)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/extract", status_code=201)
def extract_triples(body: ExtractRequest):
    """구술자료 → 확정 온톨로지 기반 트리플 자동 추출."""
    try:
        return get_extractor().extract(
            content=body.content,
            ontology_version_id=body.ontology_version_id,
            source_record_id=body.source_record_id,
        )
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
