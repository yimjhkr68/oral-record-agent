"""구술기록 CRUD"""
import uuid
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from .database import get_connection

# 원본 파일 저장 디렉토리
FILES_DIR = Path(os.environ.get("RECORDS_FILES_DIR", "data/records/files"))


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _row_to_dict(row) -> dict:
    return dict(row) if row else None


class RecordStore:

    def create_text(self, title: str, content: str, note: str = "",
                    source: str = "manual") -> dict:
        """텍스트 직접 입력으로 기록 생성."""
        record_id = str(uuid.uuid4())
        now = _now()
        with get_connection() as conn:
            conn.execute(
                """INSERT INTO oral_records
                   (id, title, source_type, file_name, file_path, file_ext,
                    source, content, char_count, note, created_at, is_deleted)
                   VALUES (?, ?, 'text', '', '', '', ?, ?, ?, ?, ?, 0)""",
                (record_id, title, source, content, len(content), note, now),
            )
        return self.get(record_id)

    def create_file(
        self,
        file_name: str,
        content: str,
        note: str = "",
        source: str = "manual",
        raw_bytes: bytes = b"",
    ) -> dict:
        """파일 업로드로 기록 생성. 제목은 파일명에서 자동 설정.

        Args:
            raw_bytes: 원본 파일 바이트. 전달하면 data/records/files/ 에 저장.
            source:    "manual" | "ontology" | "triple"
        """
        record_id = str(uuid.uuid4())
        title = file_name.rsplit(".", 1)[0] if "." in file_name else file_name
        ext = file_name.rsplit(".", 1)[-1].lower() if "." in file_name else ""
        now = _now()

        # 원본 파일 저장
        file_path = ""
        if raw_bytes:
            FILES_DIR.mkdir(parents=True, exist_ok=True)
            dest = FILES_DIR / f"{record_id}.{ext}" if ext else FILES_DIR / record_id
            dest.write_bytes(raw_bytes)
            file_path = str(dest)

        with get_connection() as conn:
            conn.execute(
                """INSERT INTO oral_records
                   (id, title, source_type, file_name, file_path, file_ext,
                    source, content, char_count, note, created_at, is_deleted)
                   VALUES (?, ?, 'file', ?, ?, ?, ?, ?, ?, ?, ?, 0)""",
                (record_id, title, file_name, file_path, ext,
                 source, content, len(content), note, now),
            )
        return self.get(record_id)

    def list(self, query: str = "", source_type: str = "",
             source: str = "", limit: int = 100) -> list[dict]:
        """목록 조회. 최신순. 소프트 삭제 제외."""
        conn = get_connection()
        params = []
        conditions = ["is_deleted = 0"]

        if query:
            conditions.append("(title LIKE ? OR content LIKE ?)")
            params += [f"%{query}%", f"%{query}%"]
        if source_type:
            conditions.append("source_type = ?")
            params.append(source_type)
        if source:
            conditions.append("source = ?")
            params.append(source)

        where = " AND ".join(conditions)
        params.append(limit)

        rows = conn.execute(
            f"""SELECT id, title, source_type, file_name, file_path, file_ext,
                       source, SUBSTR(content, 1, 200) AS content_preview,
                       char_count, note, created_at
                FROM oral_records
                WHERE {where}
                ORDER BY created_at DESC
                LIMIT ?""",
            params,
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]

    def get(self, record_id: str) -> Optional[dict]:
        """단건 조회. content 전문 포함."""
        conn = get_connection()
        row = conn.execute(
            "SELECT * FROM oral_records WHERE id = ? AND is_deleted = 0",
            (record_id,),
        ).fetchone()
        conn.close()
        return _row_to_dict(row)

    def update(self, record_id: str,
               title: str = None, note: str = None) -> Optional[dict]:
        """제목/메모만 수정. content 수정 불가."""
        sets = []
        params = []
        if title is not None:
            sets.append("title = ?")
            params.append(title)
        if note is not None:
            sets.append("note = ?")
            params.append(note)
        if not sets:
            return self.get(record_id)
        params.append(record_id)
        with get_connection() as conn:
            conn.execute(
                f"UPDATE oral_records SET {', '.join(sets)} WHERE id = ?",
                params,
            )
        return self.get(record_id)

    def delete(self, record_id: str) -> bool:
        """소프트 삭제 (is_deleted=1)."""
        with get_connection() as conn:
            cur = conn.execute(
                "UPDATE oral_records SET is_deleted = 1 WHERE id = ? AND is_deleted = 0",
                (record_id,),
            )
        return cur.rowcount > 0

    def get_usage(self, record_id: str) -> list[dict]:
        """이 기록이 사용된 ExtractionSession 목록."""
        conn = get_connection()
        rows = conn.execute(
            """SELECT es.id, es.ontology_version_id, es.status,
                      es.extracted_count, es.confirmed_count,
                      es.created_at, es.completed_at,
                      sr.extracted AS record_extracted
               FROM session_records sr
               JOIN extraction_sessions es ON sr.session_id = es.id
               WHERE sr.record_id = ?
               ORDER BY es.created_at DESC""",
            (record_id,),
        ).fetchall()
        conn.close()
        return [dict(r) for r in rows]
