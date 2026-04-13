# -*- coding: utf-8 -*-
"""api/router_semantic_search.py — 추론 기반 의미 검색 API (v5.0)

엔드포인트:
  POST /rdf/search/query              자연어 또는 SPARQL 검색
  GET  /rdf/search/templates          쿼리 템플릿 목록
  POST /rdf/search/templates/save     사용자 정의 템플릿 저장
  POST /rdf/search/reason             OWL 추론 실행
  GET  /rdf/search/reason/status      추론 상태 조회
"""

from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from core.nl_to_sparql import NLToSPARQL
from core.owl_reasoner import OWLReasoner

router = APIRouter(prefix="/rdf/search", tags=["추론 검색"])

# 싱글톤 (모듈 임포트 시 인스턴스 생성)
_nl2sp:    Optional[NLToSPARQL]  = None
_reasoner: Optional[OWLReasoner] = None


def _get_nl2sp() -> NLToSPARQL:
    global _nl2sp
    if _nl2sp is None:
        _nl2sp = NLToSPARQL()
    return _nl2sp


def _get_reasoner() -> OWLReasoner:
    global _reasoner
    if _reasoner is None:
        _reasoner = OWLReasoner()
    return _reasoner


# ── 요청 스키마 ────────────────────────────────────────────────────────────────

class SearchRequest(BaseModel):
    query: str = Field(..., description="자연어 질의 또는 SPARQL 쿼리 문자열")
    mode:  str = Field(
        default="natural",
        description="검색 모드: 'natural'(자연어→SPARQL) 또는 'sparql'(직접 실행)",
    )
    limit: int = Field(default=20, ge=1, le=200, description="최대 결과 수")


class TemplateSaveRequest(BaseModel):
    name:        str = Field(..., description="템플릿 이름 (영문 권장)")
    description: str = Field(default="", description="템플릿 설명")
    sparql:      str = Field(..., description="저장할 SPARQL 쿼리")


# ── 검색 엔드포인트 ────────────────────────────────────────────────────────────

@router.post("/query", summary="자연어 / SPARQL 검색")
def search_query(req: SearchRequest):
    """두 가지 검색 모드를 지원합니다.

    - **natural**: 자연어 질의를 Claude API가 SPARQL로 변환 후 실행
    - **sparql**: SPARQL 쿼리를 RDF 그래프에서 직접 실행

    ANTHROPIC_API_KEY 미설정 시 natural 모드는 빈 결과와 안내 메시지를 반환합니다.
    """
    nl2sp = _get_nl2sp()
    if req.mode == "natural":
        return nl2sp.search(req.query, req.limit)
    elif req.mode == "sparql":
        return nl2sp.execute_sparql(req.query, req.limit)
    else:
        raise HTTPException(
            status_code=422,
            detail=f"지원하지 않는 모드: '{req.mode}'. 'natural' 또는 'sparql'을 사용하세요.",
        )


# ── 템플릿 엔드포인트 ──────────────────────────────────────────────────────────

@router.get("/templates", summary="쿼리 템플릿 목록")
def get_templates():
    """내장 템플릿(5개) + 사용자 정의 템플릿을 반환합니다."""
    return _get_nl2sp().get_templates()


@router.post("/templates/save", summary="사용자 정의 템플릿 저장")
def save_template(req: TemplateSaveRequest):
    """자주 사용하는 SPARQL 쿼리를 템플릿으로 저장합니다.
    저장 위치: data/sparql_templates.json"""
    return _get_nl2sp().save_template(req.name, req.description, req.sparql)


# ── 추론 엔드포인트 ────────────────────────────────────────────────────────────

@router.post("/reason", summary="OWL 추론 실행")
def run_reasoner():
    """owlready2 HermiT/Pellet 추론기를 실행합니다.
    추론 결과(암묵적 트리플)는 data/rdf/oral-history-inferred.ttl 에 저장됩니다.

    owlready2 또는 Java 미설치 시 status: 'unavailable'을 반환합니다."""
    return _get_reasoner().run_reasoning()


@router.get("/reason/status", summary="추론 상태 조회")
def reason_status():
    """추론 엔진 가용 여부와 마지막 실행 결과를 반환합니다."""
    return _get_reasoner().get_status()
