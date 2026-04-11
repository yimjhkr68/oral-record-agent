"""이력 조회 + 삭제 API"""
from fastapi import APIRouter, Query, HTTPException
from pydantic import BaseModel
from core.history_store import HistoryStore

router = APIRouter(prefix="/api/history", tags=["history"])
store = HistoryStore()


class BulkDeleteRequest(BaseModel):
    ids: list[str]


# ── 온톨로지 이벤트 ──────────────────────────────────────────────────────────

@router.get("/ontology")
def list_ontology_events(
    version_id: str = Query(default=""),
    event_type: str = Query(default=""),
    limit: int = Query(default=50, ge=1, le=200),
):
    events = store.list_ontology_events(
        version_id=version_id,
        event_type=event_type,
        limit=limit,
    )
    return {"events": events, "total": len(events)}


@router.get("/ontology/{version_id}/timeline")
def get_version_timeline(version_id: str):
    events = store.get_version_timeline(version_id)
    return {"version_id": version_id, "events": events, "total": len(events)}


# ── 트리플 생성 세션 ─────────────────────────────────────────────────────────

@router.get("/extractions")
def list_extraction_sessions(
    status: str = Query(default=""),
    ontology_version: str = Query(default=""),
    limit: int = Query(default=20, ge=1, le=100),
):
    sessions = store.list_sessions(
        status=status,
        ontology_version=ontology_version,
        limit=limit,
    )
    return {"sessions": sessions, "total": len(sessions)}


@router.get("/extractions/{session_id}")
def get_session_detail(session_id: str):
    session = store.get_session_detail(session_id)
    if not session:
        raise HTTPException(404, f"세션을 찾을 수 없습니다: {session_id}")
    return session


# ── 요약 통계 ────────────────────────────────────────────────────────────────

@router.get("/summary")
def get_summary():
    return store.get_summary()


# ── 이력 삭제 ─────────────────────────────────────────────────────────────────

@router.delete("/all")
def clear_all_history():
    """온톨로지 이벤트 + 추출 세션 전체 삭제."""
    return store.clear_all()


@router.delete("/ontology/all")
def clear_all_ontology_events():
    """온톨로지 이벤트 전체 삭제."""
    count = store.clear_all_ontology_events()
    return {"deleted": count}


@router.delete("/ontology/bulk")
def delete_ontology_events_bulk(body: BulkDeleteRequest):
    """온톨로지 이벤트 다건 삭제."""
    count = store.delete_ontology_events_bulk(body.ids)
    return {"deleted": count}


@router.delete("/ontology/{event_id}")
def delete_ontology_event(event_id: str):
    """온톨로지 이벤트 단건 삭제."""
    ok = store.delete_ontology_event(event_id)
    if not ok:
        raise HTTPException(404, f"이벤트 없음: {event_id}")
    return {"deleted": event_id}


@router.delete("/extractions/all")
def clear_all_sessions():
    """추출 세션 전체 삭제."""
    count = store.clear_all_sessions()
    return {"deleted": count}


@router.delete("/extractions/bulk")
def delete_sessions_bulk(body: BulkDeleteRequest):
    """추출 세션 다건 삭제."""
    count = store.delete_sessions_bulk(body.ids)
    return {"deleted": count}


@router.delete("/extractions/{session_id}")
def delete_session(session_id: str):
    """추출 세션 단건 삭제."""
    ok = store.delete_session(session_id)
    if not ok:
        raise HTTPException(404, f"세션 없음: {session_id}")
    return {"deleted": session_id}
