# -*- coding: utf-8 -*-
"""api/router_rdf_ontology.py — RDF 레벨 온톨로지 편집 API (v5.0)

엔드포인트 목록:
  GET    /rdf/ontology/classes               클래스 전체 목록
  POST   /rdf/ontology/classes               클래스 추가 (→ MINOR 버전 증가)
  GET    /rdf/ontology/classes/{local}       클래스 상세 조회
  PUT    /rdf/ontology/classes/{local}       클래스 수정 (→ PATCH 버전 증가)
  DELETE /rdf/ontology/classes/{local}       클래스 Deprecated 처리 (→ MAJOR 버전 증가)

  GET    /rdf/ontology/properties            속성 전체 목록

  GET    /rdf/ontology/turtle                전체 Turtle 텍스트
  POST   /rdf/ontology/turtle/validate       Turtle 문법 검증
  PUT    /rdf/ontology/turtle                Turtle 직접 적용
  GET    /rdf/ontology/turtle/reload         파일에서 그래프 재로드

  GET    /rdf/ontology/version               버전 정보
  POST   /rdf/ontology/version/bump          버전 증가 (patch|minor|major)

  GET    /rdf/ontology/changelog             변경 이력
"""

from datetime import datetime
from typing import Literal as TypingLiteral, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from rdflib import OWL, RDF, RDFS, Graph, Literal, Namespace, URIRef

from core.rdf_store import get_rdf_store

router = APIRouter(prefix="/rdf/ontology", tags=["RDF 온톨로지 편집"])

_ORA_BASE = "https://yimjhkr68.github.io/oral-history-ontology/core#"
ORA = Namespace(_ORA_BASE)


# ── 요청 스키마 ────────────────────────────────────────────────────────────────

class ClassIn(BaseModel):
    """클래스 추가·수정 요청 본문."""
    label_ko:     str   = Field(..., min_length=1, description="한국어 레이블 (필수)")
    label_en:     str   = Field(default="",        description="영문 레이블")
    parent_uris:  list[str] = Field(default=[],    description="상위 클래스 URI 목록")
    equiv_uris:   list[str] = Field(default=[],    description="동치 클래스 URI 목록")
    description:  str   = Field(default="",        description="클래스 설명(ko)")


class TurtleIn(BaseModel):
    turtle: str = Field(..., description="검증·적용할 Turtle 텍스트")


class BumpIn(BaseModel):
    bump_type: TypingLiteral["patch", "minor", "major"] = Field(
        default="patch",
        description="patch=수정, minor=추가, major=삭제·구조변경",
    )


# ── 내부 유틸 ─────────────────────────────────────────────────────────────────

def _local_to_uri(local: str) -> str:
    """로컬 이름 → 전체 URI (이미 http로 시작하면 그대로 사용)."""
    if local.startswith("http"):
        return local
    return _ORA_BASE + local


def _require_class(local: str) -> URIRef:
    """클래스 URI를 확인하고, 존재하지 않으면 404."""
    store = get_rdf_store()
    uri   = URIRef(_local_to_uri(local))
    if (uri, RDF.type, OWL.Class) not in store.graph:
        raise HTTPException(status_code=404, detail=f"클래스를 찾을 수 없습니다: {local}")
    return uri


def _is_deprecated(uri: URIRef) -> bool:
    store = get_rdf_store()
    return (uri, OWL.deprecated, Literal(True)) in store.graph


# ── 클래스 엔드포인트 ──────────────────────────────────────────────────────────

@router.get("/classes", summary="클래스 목록 조회")
def list_classes():
    """RDF 그래프에 존재하는 모든 OWL 클래스를 반환합니다."""
    return get_rdf_store().list_classes()


@router.post("/classes", summary="클래스 추가", status_code=201)
def add_class(local: str, body: ClassIn):
    """새 클래스를 추가합니다. local: URI 로컬 이름 (예: Narrator).

    - 이미 존재하는 local 이름이면 409 반환
    - 저장 후 MINOR 버전 자동 증가
    """
    store = get_rdf_store()
    uri   = URIRef(_ORA_BASE + local)

    if (uri, RDF.type, OWL.Class) in store.graph:
        raise HTTPException(status_code=409, detail=f"이미 존재하는 클래스입니다: {local}")

    store.graph.add((uri, RDF.type,   OWL.Class))
    store.graph.add((uri, RDFS.label, Literal(body.label_ko, lang="ko")))
    if body.label_en:
        store.graph.add((uri, RDFS.label, Literal(body.label_en, lang="en")))
    if body.description:
        store.graph.add((uri, RDFS.comment, Literal(body.description, lang="ko")))
    for p_uri in body.parent_uris:
        store.graph.add((uri, RDFS.subClassOf, URIRef(p_uri)))
    for e_uri in body.equiv_uris:
        store.graph.add((uri, OWL.equivalentClass, URIRef(e_uri)))

    store.save(log_entry={
        "action":    "class_add",
        "uri":       str(uri),
        "label_ko":  body.label_ko,
        "timestamp": datetime.now().isoformat(),
    })
    store.bump_version("minor")
    return {"status": "created", "uri": str(uri)}


@router.get("/classes/{local}", summary="클래스 상세 조회")
def get_class(local: str):
    """특정 클래스의 상세 정보(레이블, 상위 클래스, 동치 클래스, 속성 등)를 반환합니다."""
    store = get_rdf_store()
    uri   = _local_to_uri(local)
    data  = store.get_class(uri)
    if data is None:
        raise HTTPException(status_code=404, detail=f"클래스를 찾을 수 없습니다: {local}")
    return data


@router.put("/classes/{local}", summary="클래스 수정")
def update_class(local: str, body: ClassIn):
    """클래스의 레이블·설명·상위 클래스를 수정합니다.

    - label_ko 가 비어 있으면 400 반환
    - URI 변경은 지원하지 않습니다 (새 클래스 추가 후 기존 Deprecated 권장)
    - 저장 후 PATCH 버전 자동 증가
    """
    if not body.label_ko.strip():
        raise HTTPException(status_code=400, detail="label_ko(한국어 레이블)는 필수입니다")

    uri   = _require_class(local)
    store = get_rdf_store()

    # 기존 레이블·설명·상위클래스 제거 후 재추가
    store.graph.remove((uri, RDFS.label,      None))
    store.graph.remove((uri, RDFS.comment,    None))
    store.graph.remove((uri, RDFS.subClassOf, None))
    store.graph.remove((uri, OWL.equivalentClass, None))

    store.graph.add((uri, RDFS.label, Literal(body.label_ko, lang="ko")))
    if body.label_en:
        store.graph.add((uri, RDFS.label, Literal(body.label_en, lang="en")))
    if body.description:
        store.graph.add((uri, RDFS.comment, Literal(body.description, lang="ko")))
    for p_uri in body.parent_uris:
        store.graph.add((uri, RDFS.subClassOf, URIRef(p_uri)))
    for e_uri in body.equiv_uris:
        store.graph.add((uri, OWL.equivalentClass, URIRef(e_uri)))

    store.save(log_entry={
        "action":    "class_update",
        "uri":       str(uri),
        "label_ko":  body.label_ko,
        "timestamp": datetime.now().isoformat(),
    })
    store.bump_version("patch")
    return {"status": "updated", "uri": str(uri)}


@router.delete("/classes/{local}", summary="클래스 Deprecated 처리")
def deprecate_class(local: str):
    """클래스를 즉시 삭제하지 않고 owl:deprecated true 로 마킹합니다.

    - 이미 Deprecated 된 클래스면 400 반환
    - 저장 후 MAJOR 버전 자동 증가
    """
    uri   = _require_class(local)
    store = get_rdf_store()

    if _is_deprecated(uri):
        raise HTTPException(status_code=400, detail=f"이미 Deprecated 처리된 클래스입니다: {local}")

    store.graph.add((uri, OWL.deprecated, Literal(True)))
    store.save(log_entry={
        "action":    "class_deprecated",
        "uri":       str(uri),
        "timestamp": datetime.now().isoformat(),
    })
    store.bump_version("major")
    return {"status": "deprecated", "uri": str(uri),
            "note": "클래스는 삭제되지 않았습니다. owl:deprecated=true 가 추가되었습니다."}


# ── 속성 엔드포인트 ────────────────────────────────────────────────────────────

@router.get("/properties", summary="속성 목록 조회")
def list_properties():
    """RDF 그래프에 존재하는 모든 OWL ObjectProperty / DatatypeProperty를 반환합니다."""
    return get_rdf_store().list_properties()


# ── Turtle 엔드포인트 ──────────────────────────────────────────────────────────

@router.get("/turtle", summary="전체 Turtle 텍스트 조회")
def get_turtle():
    """현재 RDF 그래프 전체를 Turtle 형식 문자열로 반환합니다."""
    store = get_rdf_store()
    if len(store.graph) == 0:
        raise HTTPException(
            status_code=404,
            detail="RDF 그래프가 비어 있습니다. 마이그레이션을 먼저 실행하세요."
        )
    return {
        "turtle":       store.serialize(format="turtle"),
        "triple_count": len(store.graph),
    }


@router.post("/turtle/validate", summary="Turtle 문법 검증")
def validate_turtle(body: TurtleIn):
    """입력한 Turtle 텍스트의 문법을 검증합니다.
    파일을 변경하지 않으며, 검증 결과만 반환합니다."""
    g = Graph()
    try:
        g.parse(data=body.turtle, format="turtle")
        return {"valid": True, "triple_count": len(g)}
    except Exception as e:
        return {"valid": False, "error": str(e)}


@router.put("/turtle", summary="Turtle 직접 적용")
def apply_turtle(body: TurtleIn):
    """검증된 Turtle 텍스트를 그래프에 반영하고 파일로 저장합니다.

    - 문법 오류가 있으면 400 반환 (파일 변경 없음)
    - 성공 시 PATCH 버전 자동 증가
    """
    g = Graph()
    try:
        g.parse(data=body.turtle, format="turtle")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Turtle 문법 오류: {e}")

    store = get_rdf_store()
    store.graph = g
    store._bind_prefixes()
    store.save(log_entry={
        "action":       "turtle_apply",
        "triple_count": len(g),
        "timestamp":    datetime.now().isoformat(),
    })
    store.bump_version("patch")
    return {"status": "applied", "triple_count": len(g)}


@router.get("/turtle/reload", summary="파일에서 그래프 재로드")
def reload_from_file():
    """data/rdf/oral-history.ttl 파일에서 그래프를 다시 로드합니다."""
    store = get_rdf_store()
    store.reload()
    return {"status": "reloaded", "triple_count": len(store.graph)}


# ── 버전 엔드포인트 ────────────────────────────────────────────────────────────

@router.get("/version", summary="버전 정보 조회")
def get_version():
    """현재 온톨로지 버전 정보를 반환합니다."""
    return get_rdf_store().get_version()


@router.post("/version/bump", summary="버전 증가")
def bump_version(body: BumpIn):
    """버전을 수동으로 증가시킵니다.

    - patch: 1.0.0 → 1.0.1 (속성·레이블 수정 시)
    - minor: 1.0.0 → 1.1.0 (클래스 추가 시)
    - major: 1.0.0 → 2.0.0 (클래스 삭제·구조 변경 시)
    """
    return get_rdf_store().bump_version(body.bump_type)


# ── 변경 이력 엔드포인트 ──────────────────────────────────────────────────────

@router.get("/changelog", summary="변경 이력 조회")
def get_changelog(limit: int = 50):
    """최근 변경 이력을 반환합니다 (최신 순, 최대 200건)."""
    if limit < 1 or limit > 200:
        raise HTTPException(status_code=422, detail="limit는 1~200 사이여야 합니다")
    return get_rdf_store().get_changelog(limit)
