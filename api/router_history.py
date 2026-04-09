"""이력 조회 API"""
from fastapi import APIRouter, Query
from fastapi import HTTPException
from core.history_store import HistoryStore

router = APIRouter(prefix="/api/history", tags=["history"])
store = HistoryStore()


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
