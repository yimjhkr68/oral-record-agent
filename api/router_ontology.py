"""api/router_ontology.py — 온톨로지 API 엔드포인트 (F1·F2·F3)"""

from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ontology.ontology_manager import OntologyClass, OntologyManager, OntologyPredicate

router = APIRouter(prefix="/api/ontologies", tags=["온톨로지"])

# 싱글톤 매니저 (앱 시작 시 한 번 초기화)
_manager: Optional[OntologyManager] = None


def get_manager() -> OntologyManager:
    global _manager
    if _manager is None:
        _manager = OntologyManager()
    return _manager


# ── 요청/응답 스키마 ────────────────────────────────────────────────────────────

class CreateRequest(BaseModel):
    version_id:  str
    description: str = ""


class UpdateRequest(BaseModel):
    classes:     Optional[list[dict]] = None
    predicates:  Optional[list[dict]] = None
    description: Optional[str]        = None


class GenerateRequest(BaseModel):
    sample_text:     str
    base_version_id: Optional[str] = None


# ── 엔드포인트 ─────────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
def create_draft(body: CreateRequest):
    """Draft 온톨로지 버전 생성."""
    try:
        v = get_manager().create(body.version_id, body.description)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return v


@router.get("/")
def list_all():
    """전체 버전 목록 (최신순)."""
    return get_manager().list_all()


@router.get("/{version_id}")
def get_version(version_id: str):
    """버전 단건 조회."""
    try:
        return get_manager().get(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/{version_id}")
def update_draft(version_id: str, body: UpdateRequest):
    """Draft 버전 수정."""
    try:
        classes    = [OntologyClass(**c)    for c in body.classes]    if body.classes    else None
        predicates = [OntologyPredicate(**p) for p in body.predicates] if body.predicates else None
        return get_manager().update(version_id, classes=classes,
                                    predicates=predicates,
                                    description=body.description)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.delete("/{version_id}", status_code=204)
def delete_draft(version_id: str):
    """Draft 버전 삭제."""
    try:
        get_manager().delete(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.post("/{version_id}/confirm")
def confirm_version(version_id: str):
    """Draft → Confirmed 전환."""
    try:
        return get_manager().confirm(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.post("/{version_id}/archive")
def archive_version(version_id: str):
    """Confirmed → Archived 전환."""
    try:
        return get_manager().archive(version_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e))


@router.post("/generate", status_code=201)
def generate_from_sample(body: GenerateRequest):
    """구술 샘플 텍스트 → AI 온톨로지 Draft 자동 생성."""
    try:
        return get_manager().generate_from_sample(
            body.sample_text, body.base_version_id
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
