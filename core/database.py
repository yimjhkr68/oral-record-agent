"""SQLite 연결 + 테이블 초기화"""
import sqlite3
import os
from pathlib import Path

DB_PATH = os.environ.get("DB_PATH", "data/oral_record_agent.db")


def get_connection() -> sqlite3.Connection:
    """연결 반환. Row 팩토리 설정으로 dict 처럼 사용."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_db():
    """앱 시작 시 테이블 없으면 생성."""
    Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
    conn = get_connection()
    with conn:
        conn.executescript("""
            CREATE TABLE IF NOT EXISTS oral_records (
                id           TEXT PRIMARY KEY,
                title        TEXT NOT NULL,
                source_type  TEXT NOT NULL CHECK(source_type IN ('text','file')),
                file_name    TEXT DEFAULT '',
                content      TEXT NOT NULL,
                char_count   INTEGER DEFAULT 0,
                note         TEXT DEFAULT '',
                created_at   TEXT NOT NULL,
                is_deleted   INTEGER DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS ontology_events (
                id              TEXT PRIMARY KEY,
                event_type      TEXT NOT NULL,
                version_id      TEXT NOT NULL,
                detail          TEXT DEFAULT '',
                before_snapshot TEXT DEFAULT '',
                after_snapshot  TEXT DEFAULT '',
                created_at      TEXT NOT NULL,
                user_note       TEXT DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS extraction_sessions (
                id                   TEXT PRIMARY KEY,
                ontology_version_id  TEXT NOT NULL,
                status               TEXT DEFAULT 'running',
                total_records        INTEGER DEFAULT 0,
                processed_records    INTEGER DEFAULT 0,
                extracted_count      INTEGER DEFAULT 0,
                confirmed_count      INTEGER DEFAULT 0,
                rejected_count       INTEGER DEFAULT 0,
                modified_count       INTEGER DEFAULT 0,
                note                 TEXT DEFAULT '',
                created_at           TEXT NOT NULL,
                completed_at         TEXT DEFAULT ''
            );

            CREATE TABLE IF NOT EXISTS session_records (
                session_id  TEXT NOT NULL,
                record_id   TEXT NOT NULL,
                extracted   INTEGER DEFAULT 0,
                PRIMARY KEY (session_id, record_id)
            );

            CREATE INDEX IF NOT EXISTS idx_records_created
                ON oral_records(created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_events_version
                ON ontology_events(version_id);
            CREATE INDEX IF NOT EXISTS idx_events_created
                ON ontology_events(created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_sessions_created
                ON extraction_sessions(created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_session_records
                ON session_records(session_id);
        """)
    conn.close()
