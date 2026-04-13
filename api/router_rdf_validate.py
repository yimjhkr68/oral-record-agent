# -*- coding: utf-8 -*-
"""api/router_rdf_validate.py — 온톨로지 품질 검증 API (v5.0)

엔드포인트:
  POST /rdf/validate/run          전체 검증 실행 (5개 항목)
  GET  /rdf/validate/results      최근 검증 결과 조회
  GET  /rdf/validate/readiness    공표 준비도 (0~100)
  POST /rdf/validate/consistency  OWL 일관성 검사만 단독 실행
"""

from fastapi import APIRouter, HTTPException
from core.rdf_validator import RDFValidator

router = APIRouter(prefix="/rdf/validate", tags=["품질 검증"])
_validator = RDFValidator()


@router.post("/run", summary="전체 검증 실행")
def run_validation():
    """5개 항목(구조·레이블·매핑·중복·일관성) 검증을 순서대로 실행합니다.
    결과는 data/validation_results.json 에 저장됩니다."""
    result = _validator.run_all()
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result


@router.get("/results", summary="최근 검증 결과 조회")
def get_results():
    """가장 최근 실행된 검증 결과를 반환합니다.
    검증을 아직 실행하지 않았으면 404를 반환합니다."""
    result = _validator.load_results()
    if result is None:
        raise HTTPException(
            status_code=404,
            detail="검증 결과 없음. POST /rdf/validate/run 을 먼저 실행하세요."
        )
    return result


@router.get("/readiness", summary="공표 준비도 조회")
def get_readiness():
    """공표 준비도 점수(0~100)와 공표 가능 여부를 반환합니다.

    - 100점: 공표 가능
    - 80~99점: 경고 있음, 공표 권장
    - 0~79점: 오류 있음, 공표 불가
    """
    return _validator.get_readiness()


@router.post("/consistency", summary="OWL 일관성 검사 (단독 실행)")
def check_consistency():
    """owlready2를 사용한 OWL DL 일관성 검사만 단독으로 실행합니다.
    owlready2 미설치 시 skip 상태를 반환합니다."""
    return _validator._check_consistency()
