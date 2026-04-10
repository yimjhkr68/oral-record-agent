"""api/router_published_ontology.py — 공표 온톨로지 CRUD API"""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from ontology.published_ontology import PublishedClass, PublishedOntology
from ontology.published_ontology_store import PublishedOntologyStore

router = APIRouter(prefix="/api/published-ontologies", tags=["공표 온톨로지"])

_store: Optional[PublishedOntologyStore] = None


def get_store() -> PublishedOntologyStore:
    global _store
    if _store is None:
        _store = PublishedOntologyStore()
    return _store


# ── 요청 스키마 ─────────────────────────────────────────────────────────────────

class OntologyCreateRequest(BaseModel):
    id: str
    name: str
    prefix: str
    namespace_uri: str
    description: str = ""
    version: str = ""


class OntologyUpdateRequest(BaseModel):
    name: Optional[str] = None
    prefix: Optional[str] = None
    namespace_uri: Optional[str] = None
    description: Optional[str] = None
    version: Optional[str] = None


class ClassCreateRequest(BaseModel):
    curie: str
    uri: str
    label: str
    label_ko: str = ""
    description: str = ""


class ClassUpdateRequest(BaseModel):
    curie: Optional[str] = None
    uri: Optional[str] = None
    label: Optional[str] = None
    label_ko: Optional[str] = None
    description: Optional[str] = None


# ── 온톨로지 CRUD ───────────────────────────────────────────────────────────────

@router.get("/", summary="공표 온톨로지 목록 조회")
def list_ontologies():
    return [o.to_dict() for o in get_store().list_all()]


@router.post("/", status_code=201, summary="공표 온톨로지 생성")
def create_ontology(body: OntologyCreateRequest):
    onto = PublishedOntology(
        id=body.id,
        name=body.name,
        prefix=body.prefix,
        namespace_uri=body.namespace_uri,
        description=body.description,
        version=body.version,
    )
    try:
        result = get_store().create(onto)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return result.to_dict()


@router.get("/classes", summary="모든 공표 클래스 평탄화 조회 (ontology_id 포함)")
def list_all_classes():
    """자동 매핑 UI에서 드롭다운 선택용으로 사용."""
    return get_store().list_classes_flat()


@router.get("/{ontology_id}", summary="공표 온톨로지 단건 조회")
def get_ontology(ontology_id: str):
    try:
        return get_store().get(ontology_id).to_dict()
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/{ontology_id}", summary="공표 온톨로지 메타데이터 수정")
def update_ontology(ontology_id: str, body: OntologyUpdateRequest):
    kwargs = {k: v for k, v in body.model_dump().items() if v is not None}
    try:
        return get_store().update(ontology_id, **kwargs).to_dict()
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{ontology_id}", status_code=204, summary="공표 온톨로지 삭제")
def delete_ontology(ontology_id: str):
    try:
        get_store().delete(ontology_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ── 클래스 CRUD ─────────────────────────────────────────────────────────────────

@router.post("/{ontology_id}/classes", status_code=201, summary="클래스 추가")
def add_class(ontology_id: str, body: ClassCreateRequest):
    cls = PublishedClass(
        curie=body.curie,
        uri=body.uri,
        label=body.label,
        label_ko=body.label_ko,
        description=body.description,
    )
    try:
        result = get_store().add_class(ontology_id, cls)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    return result.to_dict()


@router.patch(
    "/{ontology_id}/classes/{class_id}", summary="클래스 수정"
)
def update_class(ontology_id: str, class_id: str, body: ClassUpdateRequest):
    kwargs = {k: v for k, v in body.model_dump().items() if v is not None}
    try:
        return get_store().update_class(ontology_id, class_id, **kwargs).to_dict()
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete(
    "/{ontology_id}/classes/{class_id}", status_code=204, summary="클래스 삭제"
)
def delete_class(ontology_id: str, class_id: str):
    try:
        get_store().delete_class(ontology_id, class_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))
