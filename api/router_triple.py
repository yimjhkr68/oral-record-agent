"""api/router_triple.py — 트리플 API 엔드포인트 (F5)"""

from __future__ import annotations

from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel

from graph.graph_db import GraphDB, TripleStatus, EXTRACTION_AUTO, EXTRACTION_MANUAL, EXTRACTION_EDITED
from graph.triple_manager import TripleManager
from pipeline.triple_extractor import TripleExtractor
from api.router_ontology import get_manager as get_ontology_manager
from core.history_store import HistoryStore

_history: Optional[HistoryStore] = None

def get_history() -> HistoryStore:
    global _history
    if _history is None:
        _history = HistoryStore()
    return _history

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
    subject:           str
    subject_type:      str
    predicate:         str
    object:            str
    object_type:       str
    ontology_version:  str
    source_record_id:  Optional[str] = None
    confidence:        float         = 1.0
    note:              str           = ""
    created_by:        str           = "system"
    extraction_method: str           = EXTRACTION_AUTO


class UpdateRequest(BaseModel):
    predicate:   Optional[str]   = None
    object:      Optional[str]   = None
    object_type: Optional[str]   = None
    confidence:  Optional[float] = None
    note:        Optional[str]   = None
    updated_by:  Optional[str]   = None


class PutRequest(BaseModel):
    """전체 수정 (PUT). subject / subject_type 포함."""
    subject:      Optional[str]   = None
    subject_type: Optional[str]   = None
    predicate:    Optional[str]   = None
    object:       Optional[str]   = None
    object_type:  Optional[str]   = None
    confidence:   Optional[float] = None
    note:         Optional[str]   = None
    updated_by:   Optional[str]   = None


# ── 인증 의존성 ────────────────────────────────────────────────────────────────

def require_admin(x_role: str = Header(default="viewer")) -> str:
    """X-Role: admin 헤더 필수. 없으면 403."""
    if x_role.lower() != "admin":
        raise HTTPException(status_code=403, detail="관리자 권한이 필요합니다.")
    return x_role


class ArchiveRequest(BaseModel):
    reason: str = ""


class ExtractRequest(BaseModel):
    content:             str
    ontology_version_id: str
    source_record_id:    Optional[str] = None
    session_id:          Optional[str] = None  # 기존 세션에 추가 시


class BulkConfirmRequest(BaseModel):
    triples:        list[dict]        # PendingTriple.toJson() 목록
    session_id:     Optional[str] = None
    rejected_count: int = 0
    modified_count: int = 0


# ── 엔드포인트 ─────────────────────────────────────────────────────────────────

@router.post("/", status_code=201)
def create_triple(body: CreateRequest,
                  _: str = Depends(require_admin)):
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
        created_by=body.created_by,
        extraction_method=body.extraction_method,
    )


@router.get("/")
def list_triples_endpoint(
    q:            str           = Query("",       description="검색어 (주어/술어/목적어)"),
    subject_type: str           = Query("",       description="클래스 필터 (주어 타입)"),
    version:      Optional[str] = Query(None,     description="온톨로지 버전"),
    status:       str           = Query("active", description="active | archived | all"),
    limit:        int           = Query(500,      description="최대 반환 건수"),
):
    """트리플 목록 조회. q=키워드, subject_type=클래스 필터."""
    from dataclasses import asdict

    include_archived = status in ("archived", "all")
    all_t = get_triple_manager().db.all_triples(include_archived=include_archived)

    result = list(all_t)

    # 상태 필터
    if status == "active":
        result = [t for t in result if t.status.value == "active"]
    elif status == "archived":
        result = [t for t in result if t.status.value == "archived"]

    # 버전 필터
    if version:
        result = [t for t in result if t.ontology_version == version]

    # 키워드 필터 (주어/술어/목적어 모두 검색)
    if q:
        q_lower = q.lower()
        result = [
            t for t in result
            if q_lower in t.subject.lower()
            or q_lower in t.predicate.lower()
            or q_lower in t.object.lower()
        ]

    # 클래스 필터 (주어 타입)
    if subject_type:
        result = [t for t in result if t.subject_type == subject_type]

    items = []
    for t in result[:limit]:
        d = asdict(t)
        d["status"] = t.status.value
        items.append(d)

    return {"total": len(result), "items": items}


@router.get("/stats")
def triple_stats():
    """트리플 통계."""
    return get_triple_manager().stats()


@router.get("/list")
def list_triples(
    version:   Optional[str] = Query(None, description="온톨로지 버전"),
    source:    Optional[str] = Query(None, description="출처 record_id"),
    by:        Optional[str] = Query(None, description="생성자"),
    from_:     Optional[str] = Query(None, alias="from", description="날짜 from (YYYY-MM-DD)"),
    to:        Optional[str] = Query(None, description="날짜 to (YYYY-MM-DD)"),
    status:    Optional[str] = Query(None, description="active | archived | (없으면 전체)"),
):
    """관리자용 트리플 목록 조회 (필터 지원)."""
    triples = get_triple_manager().list_triples(
        ontology_version=version,
        source_record_id=source,
        created_by=by,
        date_from=from_,
        date_to=to,
        status=status,
    )
    from dataclasses import asdict
    result = []
    for t in triples:
        d = asdict(t)
        d["status"] = t.status.value
        result.append(d)
    return {"triples": result, "total": len(result)}


@router.get("/categories")
def get_categories(
    version: Optional[str] = Query(None,      description="온톨로지 버전"),
    status:  Optional[str] = Query("active",  description="active | archived | (없으면 전체)"),
):
    """클래스별 트리플 범주화 (건수 포함)."""
    from dataclasses import asdict
    result = get_triple_manager().get_categories(
        ontology_version=version,
        status=status,
    )

    # label_ko 보강 — 온톨로지 버전이 지정된 경우 클래스명 → 한국어 레이블 매핑
    label_map: dict[str, str] = {}
    if version:
        try:
            onto = get_ontology_manager().get_version(version)
            label_map = {c.name: c.label_ko for c in onto.classes if c.label_ko}
        except Exception:
            pass

    for cat in result["categories"]:
        cat["label_ko"] = label_map.get(cat["name"], cat["name"])

    return result


@router.get("/search")
def search_extended(
    q:       str           = Query("",       description="검색어"),
    version: Optional[str] = Query(None,     description="온톨로지 버전"),
    status:  str           = Query("active", description="active | archived"),
):
    """확장 검색: 1홉 트리플 + 범주 정보 반환."""
    result = get_triple_manager().search_with_categories(
        query=q, ontology_version=version, status=status
    )

    # label_ko 보강
    label_map: dict[str, str] = {}
    if version:
        try:
            onto = get_ontology_manager().get_version(version)
            label_map = {c.name: c.label_ko for c in onto.classes if c.label_ko}
        except Exception:
            pass

    for cat in result["categories"]:
        cat["label_ko"] = label_map.get(cat["name"], cat["name"])

    return result


@router.get("/facets")
def get_triple_facets():
    """클래스별 트리플 수 반환 (패싯 버튼용)."""
    from collections import Counter
    all_t = get_triple_manager().db.all_triples(include_archived=False)
    subject_counts = Counter(t.subject_type for t in all_t)
    object_counts  = Counter(t.object_type  for t in all_t)
    all_classes = set(subject_counts) | set(object_counts)
    facets = sorted(
        [
            {
                "class": cls,
                "count": subject_counts.get(cls, 0) + object_counts.get(cls, 0),
            }
            for cls in all_classes
        ],
        key=lambda f: -f["count"],
    )
    return {"facets": facets}


@router.put("/{triple_id}")
def put_triple(triple_id: str, body: PutRequest,
               _: str = Depends(require_admin)):
    """트리플 전체 수정 (subject/subject_type 포함)."""
    try:
        return get_triple_manager().update(
            triple_id,
            subject=body.subject,
            subject_type=body.subject_type,
            predicate=body.predicate,
            object_=body.object,
            object_type=body.object_type,
            confidence=body.confidence,
            note=body.note,
            updated_by=body.updated_by,
        )
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/{triple_id}")
def get_triple(triple_id: str):
    """트리플 단건 조회."""
    try:
        return get_triple_manager().get(triple_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/{triple_id}")
def update_triple(triple_id: str, body: UpdateRequest,
                  _: str = Depends(require_admin)):
    """트리플 수정."""
    try:
        return get_triple_manager().update(
            triple_id,
            predicate=body.predicate,
            object_=body.object,
            object_type=body.object_type,
            confidence=body.confidence,
            note=body.note,
            updated_by=body.updated_by,
        )
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/{triple_id}", status_code=204)
def delete_triple(triple_id: str,
                  _: str = Depends(require_admin)):
    """트리플 영구 삭제."""
    try:
        get_triple_manager().delete(triple_id)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{triple_id}/archive")
def archive_triple(triple_id: str, body: ArchiveRequest,
                   _: str = Depends(require_admin)):
    """트리플 아카이브 (POST — 하위 호환)."""
    try:
        return get_triple_manager().archive(triple_id, reason=body.reason)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.patch("/{triple_id}/archive")
def archive_triple_patch(triple_id: str, body: ArchiveRequest,
                         _: str = Depends(require_admin)):
    """트리플 아카이브 (PATCH)."""
    try:
        return get_triple_manager().archive(triple_id, reason=body.reason)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/extract", status_code=200)
def extract_triples(body: ExtractRequest):
    """구술자료 → AI 트리플 추출 (DB 저장 없이 미리보기 반환).
    확정 저장은 /bulk-confirm 에서 수행."""
    # 세션 생성 (source_record_id 있을 때만)
    session_id = body.session_id
    history = get_history()
    if not session_id and body.source_record_id:
        try:
            session = history.create_session(
                ontology_version_id=body.ontology_version_id,
                record_ids=[body.source_record_id],
            )
            session_id = session["id"]
        except Exception:
            pass

    try:
        result = get_extractor().extract_preview(
            content=body.content,
            ontology_version_id=body.ontology_version_id,
            source_record_id=body.source_record_id,
        )
        # 추출 진행 업데이트
        if session_id:
            try:
                extracted = result.get("added", 0) + result.get("skipped", 0)
                if isinstance(result.get("triples"), list):
                    extracted = len(result["triples"])
                history.update_session_progress(
                    session_id=session_id,
                    processed_records=1,
                    extracted_count=extracted,
                )
            except Exception:
                pass
        return {**result, "session_id": session_id}
    except KeyError as e:
        if session_id:
            try:
                history.fail_session(session_id, str(e))
            except Exception:
                pass
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        if session_id:
            try:
                history.fail_session(session_id, str(e))
            except Exception:
                pass
        raise HTTPException(status_code=422, detail=str(e))
    except RuntimeError as e:
        # AI API 호출 실패 (크레딧 부족, 네트워크 오류 등)
        if session_id:
            try:
                history.fail_session(session_id, str(e))
            except Exception:
                pass
        raise HTTPException(status_code=502, detail=str(e))
    except Exception as e:
        if session_id:
            try:
                history.fail_session(session_id, str(e))
            except Exception:
                pass
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/bulk-confirm", status_code=201)
def bulk_confirm_triples(body: BulkConfirmRequest):
    """검토 완료된 pending 트리플 목록 → GraphDB에 active 로 일괄 저장."""
    tm = get_triple_manager()
    added = skipped = 0
    results = []
    for item in body.triples:
        try:
            t = tm.create(
                subject=item.get("subject", ""),
                subject_type=item.get("subjectType", item.get("subject_type", "")),
                predicate=item.get("predicate", ""),
                object_=item.get("object", ""),
                object_type=item.get("objectType", item.get("object_type", "")),
                ontology_version=item.get("ontology_version", ""),
                source_record_id=item.get("source_record_id") or None,
                confidence=float(item.get("confidence", 1.0)),
                note=item.get("note", ""),
                created_by=item.get("created_by", "system"),
                extraction_method=item.get("extraction_method", EXTRACTION_AUTO),
            )
            from dataclasses import asdict
            d = asdict(t); d["status"] = t.status.value
            results.append(d)
            added += 1
        except Exception:
            skipped += 1

    # 세션 완료 처리
    if body.session_id:
        try:
            get_history().complete_session(
                session_id=body.session_id,
                confirmed=added,
                rejected=body.rejected_count,
                modified=body.modified_count,
            )
        except Exception:
            pass

    return {"added": added, "skipped": skipped, "triples": results,
            "session_id": body.session_id}


# ── 일괄 내보내기 ──────────────────────────────────────────────────────────────

class TripleExportRequest(BaseModel):
    triple_ids:       list[str] = []
    status:           str       = ""
    ontology_version: str       = ""


@router.post("/export")
def export_triples(body: TripleExportRequest):
    """트리플 일괄 내보내기. triple_ids 지정 시 해당 ID만, 없으면 status/ontology_version 필터 적용.
    최대 100건 제한."""
    import json
    from datetime import datetime
    from fastapi.responses import Response
    from dataclasses import asdict

    tm = get_triple_manager()
    all_triples = tm.db.all_triples(include_archived=True)

    if body.triple_ids:
        id_set  = set(body.triple_ids)
        triples = [t for t in all_triples if t.id in id_set]
    else:
        triples = list(all_triples)
        if body.status:
            triples = [t for t in triples if t.status.value == body.status]
        if body.ontology_version:
            triples = [t for t in triples
                       if t.ontology_version == body.ontology_version]

    if len(triples) > 10000:
        raise HTTPException(status_code=400, detail="최대 10000건까지 내보내기 가능합니다")

    def _serialize(t):
        d = asdict(t)
        d["status"] = t.status.value
        return d

    export_data = {
        "export_type": "triples",
        "exported_at": datetime.now().isoformat(),
        "total":       len(triples),
        "items":       [_serialize(t) for t in triples],
    }
    filename = f"triples_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    return Response(
        content=json.dumps(export_data, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
