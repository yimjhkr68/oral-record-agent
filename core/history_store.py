"""이력 CRUD (온톨로지 이벤트 + 트리플 생성 세션)"""
import json
import uuid
from datetime import datetime, timezone
from typing import Optional
from .database import get_connection


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


class HistoryStore:

    # ── 온톨로지 이벤트 ────────────────────────────────────────────────────

    def record_ontology_event(
        self,
        event_type: str,
        version_id: str,
        detail: str = "",
        before: dict = None,
        after: dict = None,
        user_note: str = "",
    ) -> dict:
        """이벤트 기록. 추가만 가능, 수정/삭제 없음."""
        event_id = str(uuid.uuid4())
        now = _now()
        with get_connection() as conn:
            conn.execute(
                """INSERT INTO ontology_events
                   (id, event_type, version_id, detail,
                    before_snapshot, after_snapshot, created_at, user_note)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    event_id,
                    event_type,
                    version_id,
                    detail,
                    json.dumps(before or {}, ensure_ascii=False),
                    json.dumps(after or {}, ensure_ascii=False),
                    now,
                    user_note,
                ),
            )
        return self._get_event(event_id)

    def _get_event(self, event_id: str) -> Optional[dict]:
        conn = get_connection()
        row = conn.execute(
            "SELECT * FROM ontology_events WHERE id = ?", (event_id,)
        ).fetchone()
        conn.close()
        return dict(row) if row else None

    def list_ontology_events(
        self,
        version_id: str = "",
        event_type: str = "",
        limit: int = 50,
    ) -> list[dict]:
        """온톨로지 이벤트 목록 (최신순)."""
        conn = get_connection()
        conditions = []
        params = []
        if version_id:
            conditions.append("version_id = ?")
            params.append(version_id)
        if event_type:
            conditions.append("event_type = ?")
            params.append(event_type)
        where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
        params.append(limit)
        rows = conn.execute(
            f"SELECT * FROM ontology_events {where} ORDER BY created_at DESC LIMIT ?",
            params,
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def get_version_timeline(self, version_id: str) -> list[dict]:
        """특정 버전의 전체 이력 타임라인."""
        return self.list_ontology_events(version_id=version_id, limit=1000)

    # ── 트리플 생성 세션 ───────────────────────────────────────────────────

    def create_session(
        self,
        ontology_version_id: str,
        record_ids: list[str],
        note: str = "",
    ) -> dict:
        """세션 시작. status=running."""
        session_id = str(uuid.uuid4())
        now = _now()
        with get_connection() as conn:
            conn.execute(
                """INSERT INTO extraction_sessions
                   (id, ontology_version_id, status, total_records,
                    processed_records, extracted_count, confirmed_count,
                    rejected_count, modified_count, note, created_at, completed_at)
                   VALUES (?, ?, 'running', ?, 0, 0, 0, 0, 0, ?, ?, '')""",
                (session_id, ontology_version_id, len(record_ids), note, now),
            )
            for rid in record_ids:
                if rid:
                    conn.execute(
                        "INSERT OR IGNORE INTO session_records (session_id, record_id) VALUES (?, ?)",
                        (session_id, rid),
                    )
        return self.get_session_detail(session_id)

    def update_session_progress(
        self,
        session_id: str,
        processed_records: int,
        extracted_count: int,
    ) -> None:
        """추출 진행 중 업데이트."""
        with get_connection() as conn:
            conn.execute(
                """UPDATE extraction_sessions
                   SET processed_records = ?, extracted_count = ?
                   WHERE id = ?""",
                (processed_records, extracted_count, session_id),
            )

    def complete_session(
        self,
        session_id: str,
        confirmed: int,
        rejected: int,
        modified: int,
    ) -> dict:
        """세션 완료. status=completed, completed_at 기록."""
        now = _now()
        with get_connection() as conn:
            conn.execute(
                """UPDATE extraction_sessions
                   SET status = 'completed',
                       confirmed_count = ?,
                       rejected_count  = ?,
                       modified_count  = ?,
                       completed_at    = ?
                   WHERE id = ?""",
                (confirmed, rejected, modified, now, session_id),
            )
        return self.get_session_detail(session_id)

    def fail_session(self, session_id: str, error: str) -> None:
        """세션 실패."""
        with get_connection() as conn:
            conn.execute(
                """UPDATE extraction_sessions
                   SET status = 'failed', note = ?
                   WHERE id = ?""",
                (error[:500], session_id),
            )

    def list_sessions(
        self,
        status: str = "",
        ontology_version: str = "",
        limit: int = 20,
    ) -> list[dict]:
        """세션 목록 (최신순)."""
        conn = get_connection()
        conditions = []
        params = []
        if status:
            conditions.append("status = ?")
            params.append(status)
        if ontology_version:
            conditions.append("ontology_version_id = ?")
            params.append(ontology_version)
        where = ("WHERE " + " AND ".join(conditions)) if conditions else ""
        params.append(limit)
        rows = conn.execute(
            f"SELECT * FROM extraction_sessions {where} ORDER BY created_at DESC LIMIT ?",
            params,
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def get_session_detail(self, session_id: str) -> Optional[dict]:
        """세션 상세 + 처리한 기록 목록."""
        conn = get_connection()
        row = conn.execute(
            "SELECT * FROM extraction_sessions WHERE id = ?", (session_id,)
        ).fetchone()
        if not row:
            conn.close()
            return None
        session = dict(row)

        records = conn.execute(
            """SELECT sr.record_id, sr.extracted,
                      r.title, r.source_type, r.file_name
               FROM session_records sr
               LEFT JOIN oral_records r ON sr.record_id = r.id
               WHERE sr.session_id = ?""",
            (session_id,),
        ).fetchall()
        conn.close()
        session["records"] = [dict(r) for r in records]
        return session

    # ── 요약 통계 ──────────────────────────────────────────────────────────

    def get_summary(self) -> dict:
        """전체 요약 통계."""
        conn = get_connection()

        record_count = conn.execute(
            "SELECT COUNT(*) FROM oral_records WHERE is_deleted = 0"
        ).fetchone()[0]

        version_count = conn.execute(
            "SELECT COUNT(DISTINCT version_id) FROM ontology_events"
        ).fetchone()[0]

        confirmed_count = conn.execute(
            "SELECT COUNT(DISTINCT version_id) FROM ontology_events WHERE event_type = 'confirmed'"
        ).fetchone()[0]

        session_count = conn.execute(
            "SELECT COUNT(*) FROM extraction_sessions"
        ).fetchone()[0]

        last_row = conn.execute(
            """SELECT created_at FROM (
                   SELECT created_at FROM oral_records WHERE is_deleted = 0
                   UNION ALL
                   SELECT created_at FROM ontology_events
                   UNION ALL
                   SELECT created_at FROM extraction_sessions
               ) ORDER BY created_at DESC LIMIT 1"""
        ).fetchone()
        conn.close()

        return {
            "records": record_count,
            "ontology_versions": version_count,
            "confirmed_ontologies": confirmed_count,
            "extraction_sessions": session_count,
            "last_activity": (last_row[0][:10] if last_row else ""),
        }
