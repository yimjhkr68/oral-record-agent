# -*- coding: utf-8 -*-
"""api/router_rdf_publish.py — 온톨로지 공표 관리자 API (v5.0)

엔드포인트:
  POST /rdf/publish/package   공표 패키지 생성 (파일 5개)
  GET  /rdf/publish/preview   README.md 미리보기
  POST /rdf/publish/run       패키지 생성 + 외부 경로 배포 + 이력 기록
  GET  /rdf/publish/history   공표 이력 조회
"""

from typing import Optional
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from core.rdf_publisher import RDFPublisher

router = APIRouter(prefix="/rdf/publish", tags=["온톨로지 공표"])
_pub: Optional[RDFPublisher] = None


def _get_pub() -> RDFPublisher:
    global _pub
    if _pub is None:
        _pub = RDFPublisher()
    return _pub


# ── 요청 스키마 ────────────────────────────────────────────────────────────────

class PublishConfig(BaseModel):
    name:             str  = Field(default="한국 구술기록 온톨로지",  description="온톨로지 이름")
    version:          str  = Field(default="1.0.0",                  description="공표 버전")
    uri:              str  = Field(
        default="https://yimjhkr68.github.io/oral-history-ontology/core",
        description="온톨로지 기본 URI",
    )
    license:          str  = Field(
        default="https://creativecommons.org/licenses/by/4.0/",
        description="라이선스 URI",
    )
    description:      str  = Field(default="구술기록 수집·관리·공유를 위한 도메인 온톨로지", description="설명")
    author:           str  = Field(default="oral-record-agent project", description="저자")
    output_path:      str  = Field(default="", description="외부 배포 경로 (비워두면 로컬 패키지만 생성)")
    git_tag:          str  = Field(default="", description="Git 태그 (예: onto/1.0)")
    include_examples: bool = Field(default=False, description="예시 데이터 포함 여부")


# ── 엔드포인트 ─────────────────────────────────────────────────────────────────

@router.post("/package", summary="공표 패키지 생성")
def create_package(config: PublishConfig):
    """data/publish/v{version}/ 폴더에 5개 파일을 생성합니다.

    생성 파일:
    - oral-history.ttl     (Turtle)
    - oral-history.jsonld  (JSON-LD)
    - oral-history.owl     (OWL/XML)
    - README.md            (설명 문서)
    - CHANGELOG.md         (변경 이력)

    이력은 기록되지 않습니다. 이력까지 남기려면 POST /rdf/publish/run 을 사용하세요.
    """
    result = _get_pub().create_package(config.model_dump())
    if not result.get("files"):
        raise HTTPException(
            status_code=404,
            detail="RDF 파일을 찾을 수 없습니다. 마이그레이션 → 확정을 먼저 실행하세요.",
        )
    return result


@router.get("/preview", summary="README.md 미리보기")
def preview_readme():
    """패키지 생성 없이 README.md 내용을 미리 확인합니다."""
    return _get_pub().preview_readme()


@router.post("/run", summary="공표 실행 (패키지 생성 + 이력 기록)")
def publish(config: PublishConfig):
    """패키지를 생성하고 data/publish_history.json 에 이력을 기록합니다.

    output_path 가 설정된 경우 해당 경로에도 파일을 복사합니다.
    git_tag 는 현재 자동 태깅하지 않으며 이력에만 기록됩니다.
    """
    result = _get_pub().publish(config.model_dump())
    return result


@router.get("/history", summary="공표 이력 조회")
def get_history():
    """공표 이력 전체를 최신 순으로 반환합니다."""
    return _get_pub().get_history()
