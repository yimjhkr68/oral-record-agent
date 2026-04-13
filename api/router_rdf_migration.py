# -*- coding: utf-8 -*-
"""api/router_rdf_migration.py — RDF 마이그레이션 API 엔드포인트 (v5.0)

엔드포인트 목록:
  GET  /rdf/migration/status    현재 마이그레이션 상태
  POST /rdf/migration/analyze   DB·JSON 구조 분석
  POST /rdf/migration/backup    데이터 백업 (tar.gz)
  POST /rdf/migration/run       마이그레이션 실행
  GET  /rdf/migration/preview   변환 결과 미리보기
  POST /rdf/migration/confirm   확정 (tmp → v1.0)
  POST /rdf/migration/rollback  되돌리기 (백업 복원)
"""

from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from core.rdf_migration import RDFMigrationService

router = APIRouter(prefix="/rdf/migration", tags=["RDF 마이그레이션"])
_svc: Optional[RDFMigrationService] = None


def _get_svc() -> RDFMigrationService:
    global _svc
    if _svc is None:
        _svc = RDFMigrationService()
    return _svc


# ── 요청 스키마 ────────────────────────────────────────────────────────────────

class MigrationConfig(BaseModel):
    namespace_uri: str = Field(
        default="https://yimjhkr68.github.io/oral-history-ontology/core#",
        description="RDF 기본 네임스페이스 URI",
    )
    formats: list[str] = Field(
        default=["turtle", "json-ld", "xml"],
        description="출력 형식 목록 (turtle | json-ld | xml)",
    )


# ── 엔드포인트 ─────────────────────────────────────────────────────────────────

@router.get("/status", summary="마이그레이션 상태 조회")
def get_status():
    """현재 마이그레이션 상태(소스 데이터 수, 변환 여부, 백업 목록)를 반환합니다."""
    return _get_svc().get_status()


@router.post("/analyze", summary="소스 데이터 분석")
def analyze():
    """v4.0 데이터 저장소(온톨로지 JSON, 트리플 JSON, SQLite)를 분석하여 통계를 반환합니다."""
    return _get_svc().analyze_db()


@router.post("/backup", summary="데이터 백업")
def backup():
    """SQLite DB + 온톨로지/트리플 JSON 파일을 tar.gz 로 백업합니다.
    마이그레이션 전 반드시 실행하세요."""
    result = _get_svc().backup()
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])
    return result


@router.post("/run", summary="마이그레이션 실행")
def run(config: MigrationConfig):
    """v4.0 데이터를 RDF 그래프로 변환하여 data/rdf/tmp/ 에 저장합니다.
    확정 전이므로 원본 데이터에 영향을 주지 않습니다."""
    allowed_formats = {"turtle", "json-ld", "xml"}
    invalid = [f for f in config.formats if f not in allowed_formats]
    if invalid:
        raise HTTPException(
            status_code=422,
            detail=f"지원하지 않는 형식: {invalid}. 허용: {sorted(allowed_formats)}",
        )
    result = _get_svc().run(config.namespace_uri, config.formats)
    if "error" in result:
        raise HTTPException(status_code=500, detail=result["error"])
    return result


@router.get("/preview", summary="변환 결과 미리보기")
def preview(limit: int = 50):
    """마이그레이션 후 생성된 Turtle 파일에서 트리플 샘플을 반환합니다.
    limit: 반환할 트리플 수 (기본 50)"""
    if limit < 1 or limit > 500:
        raise HTTPException(status_code=422, detail="limit는 1~500 사이여야 합니다")
    result = _get_svc().preview(limit)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result


@router.post("/confirm", summary="확정 (tmp → v1.0)")
def confirm():
    """미리보기에서 확인한 RDF 파일을 data/rdf/v1.0/ 으로 복사하여 확정합니다.
    이 작업은 되돌리기(rollback)로 취소할 수 있습니다."""
    result = _get_svc().confirm()
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.post("/rollback", summary="되돌리기 (백업 복원)")
def rollback():
    """가장 최근 백업으로 데이터를 복원하고 RDF 임시 파일을 삭제합니다."""
    result = _get_svc().rollback()
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result
