"""HistoryStore 단위 테스트"""
import os
import pytest
import tempfile

# 테스트용 임시 DB 사용 (test_record_store.py 와 공유 방지)
_tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
_tmp.close()
os.environ["DB_PATH"] = _tmp.name

from core.database import init_db
from core.history_store import HistoryStore


@pytest.fixture(autouse=True)
def setup_db():
    init_db()
    yield
    from core.database import get_connection
    with get_connection() as conn:
        conn.execute("DELETE FROM session_records")
        conn.execute("DELETE FROM extraction_sessions")
        conn.execute("DELETE FROM ontology_events")
        conn.execute("DELETE FROM oral_records")


@pytest.fixture
def store():
    return HistoryStore()


class TestOntologyEvents:
    def test_record_event(self, store):
        e = store.record_ontology_event(
            event_type="created",
            version_id="v1.0",
            detail="Draft 생성",
        )
        assert e["id"]
        assert e["event_type"] == "created"
        assert e["version_id"] == "v1.0"
        assert e["detail"] == "Draft 생성"

    def test_record_with_snapshots(self, store):
        e = store.record_ontology_event(
            event_type="updated",
            version_id="v1.0",
            before={"classes": ["A"]},
            after={"classes": ["A", "B"]},
        )
        import json
        assert json.loads(e["before_snapshot"]) == {"classes": ["A"]}
        assert json.loads(e["after_snapshot"]) == {"classes": ["A", "B"]}

    def test_list_all(self, store):
        store.record_ontology_event("created", "v1.0")
        store.record_ontology_event("confirmed", "v1.0")
        events = store.list_ontology_events()
        assert len(events) == 2

    def test_list_filter_version(self, store):
        store.record_ontology_event("created", "v1.0")
        store.record_ontology_event("created", "v2.0")
        result = store.list_ontology_events(version_id="v1.0")
        assert len(result) == 1
        assert result[0]["version_id"] == "v1.0"

    def test_list_filter_type(self, store):
        store.record_ontology_event("created", "v1.0")
        store.record_ontology_event("confirmed", "v1.0")
        result = store.list_ontology_events(event_type="confirmed")
        assert len(result) == 1
        assert result[0]["event_type"] == "confirmed"

    def test_timeline(self, store):
        store.record_ontology_event("created", "v1.0")
        store.record_ontology_event("updated", "v1.0")
        store.record_ontology_event("confirmed", "v1.0")
        timeline = store.get_version_timeline("v1.0")
        assert len(timeline) == 3


class TestExtractionSessions:
    def test_create_session(self, store):
        s = store.create_session("v1.0", ["rec1", "rec2"])
        assert s["id"]
        assert s["ontology_version_id"] == "v1.0"
        assert s["status"] == "running"
        assert s["total_records"] == 2
        assert len(s["records"]) == 2

    def test_create_empty_record_ids(self, store):
        s = store.create_session("v1.0", [])
        assert s["total_records"] == 0
        assert s["records"] == []

    def test_update_progress(self, store):
        s = store.create_session("v1.0", ["rec1"])
        store.update_session_progress(s["id"], 1, 8)
        detail = store.get_session_detail(s["id"])
        assert detail["processed_records"] == 1
        assert detail["extracted_count"] == 8

    def test_complete_session(self, store):
        s = store.create_session("v1.0", ["rec1"])
        completed = store.complete_session(s["id"], confirmed=7, rejected=1, modified=2)
        assert completed["status"] == "completed"
        assert completed["confirmed_count"] == 7
        assert completed["rejected_count"] == 1
        assert completed["modified_count"] == 2
        assert completed["completed_at"] != ""

    def test_fail_session(self, store):
        s = store.create_session("v1.0", ["rec1"])
        store.fail_session(s["id"], "연결 오류")
        detail = store.get_session_detail(s["id"])
        assert detail["status"] == "failed"

    def test_list_sessions(self, store):
        store.create_session("v1.0", [])
        store.create_session("v2.0", [])
        sessions = store.list_sessions()
        assert len(sessions) == 2

    def test_list_filter_status(self, store):
        s1 = store.create_session("v1.0", [])
        store.complete_session(s1["id"], 0, 0, 0)
        store.create_session("v2.0", [])  # running
        running = store.list_sessions(status="running")
        assert len(running) == 1
        assert running[0]["ontology_version_id"] == "v2.0"

    def test_get_nonexistent(self, store):
        assert store.get_session_detail("ghost") is None


class TestGetSummary:
    def test_empty_db(self, store):
        summary = store.get_summary()
        assert summary["records"] == 0
        assert summary["extraction_sessions"] == 0
        assert summary["ontology_versions"] == 0

    def test_with_data(self, store):
        from core.record_store import RecordStore
        rs = RecordStore()
        rs.create_text("기록1", "내용1")
        store.record_ontology_event("created", "v1.0")
        store.record_ontology_event("confirmed", "v1.0")
        store.create_session("v1.0", [])

        summary = store.get_summary()
        assert summary["records"] == 1
        assert summary["ontology_versions"] == 1
        assert summary["confirmed_ontologies"] == 1
        assert summary["extraction_sessions"] == 1
        assert summary["last_activity"] != ""
