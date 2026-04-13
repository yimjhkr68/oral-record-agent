# -*- coding: utf-8 -*-
"""api/router_rdf_export.py — RDF 형식 내보내기 API (v5.0)

엔드포인트:
  GET /rdf/export/ontology   온톨로지 전체 다운로드 (turtle|json-ld|xml)
  GET /rdf/export/triples    트리플 부분 다운로드 (turtle|json-ld|xml)

Content-Type 매핑:
  turtle  → text/turtle                  → oral-history.ttl
  json-ld → application/ld+json          → oral-history.jsonld
  xml     → application/rdf+xml          → oral-history.owl
"""

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import Response

from core.rdf_store import get_rdf_store

router = APIRouter(prefix="/rdf/export", tags=["RDF 내보내기"])

# ── 형식 → (Content-Type, 파일 확장자, rdflib 직렬화 형식) ────────────────────
_FORMATS: dict[str, tuple[str, str, str]] = {
    "turtle":  ("text/turtle",           ".ttl",     "turtle"),
    "json-ld": ("application/ld+json",   ".jsonld",  "json-ld"),
    "xml":     ("application/rdf+xml",   ".owl",     "xml"),
}
_FORMAT_KEYS = list(_FORMATS.keys())


def _serialize(fmt: str) -> bytes:
    """현재 RDFStore 그래프를 지정 형식으로 직렬화하여 bytes로 반환."""
    store = get_rdf_store()
    if len(store.graph) == 0:
        raise HTTPException(
            status_code=404,
            detail="RDF 그래프가 비어 있습니다. 마이그레이션 → 확정을 먼저 실행하세요.",
        )
    _, _, rdflib_fmt = _FORMATS[fmt]
    text = store.graph.serialize(format=rdflib_fmt)
    return text.encode("utf-8") if isinstance(text, str) else text


# ── 엔드포인트 ─────────────────────────────────────────────────────────────────

@router.get("/ontology", summary="온톨로지 전체 파일 다운로드")
def export_ontology(
    format: str = Query(
        default="turtle",
        enum=_FORMAT_KEYS,
        description="출력 형식: turtle | json-ld | xml",
    ),
):
    """현재 RDF 그래프 전체를 지정 형식으로 다운로드합니다.

    | format  | Content-Type          | 파일명              |
    |---------|-----------------------|---------------------|
    | turtle  | text/turtle           | oral-history.ttl    |
    | json-ld | application/ld+json   | oral-history.jsonld |
    | xml     | application/rdf+xml   | oral-history.owl    |
    """
    media_type, ext, _ = _FORMATS[format]
    content = _serialize(format)
    return Response(
        content=content,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="oral-history{ext}"',
            "Content-Length":      str(len(content)),
        },
    )


@router.get("/triples", summary="트리플 파일 다운로드")
def export_triples(
    format: str = Query(
        default="turtle",
        enum=_FORMAT_KEYS,
        description="출력 형식: turtle | json-ld | xml",
    ),
    selected_ids: str = Query(
        default=None,
        description="(미구현) 선택된 트리플 ID 목록 (쉼표 구분). 생략 시 전체 출력.",
    ),
):
    """트리플 데이터를 지정 형식으로 다운로드합니다.

    selected_ids 파라미터는 현재 전체 그래프를 반환합니다
    (트리플 ID 기반 필터링은 추후 구현 예정).
    """
    media_type, ext, _ = _FORMATS[format]
    content = _serialize(format)
    return Response(
        content=content,
        media_type=media_type,
        headers={
            "Content-Disposition": f'attachment; filename="triples{ext}"',
            "Content-Length":      str(len(content)),
        },
    )
