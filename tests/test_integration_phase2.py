"""
tests/test_integration_phase2.py — Phase 2 통합 검증

P2-1. 온톨로지 이벤트 발행 확인
P2-2. 트리플 추출 세션 생성 확인
P2-3. bulk-confirm 세션 완료 확인
완료 기준:
  □ 온톨로지 confirm → ontology_events 테이블 기록 확인
  □ 트리플 추출 → extraction_sessions 세션 생성 확인
  □ 확정 저장 → 세션 completed 상태 확인
  □ get_summary() → 정확한 통계
"""

from __future__ import annotations

import pytest


@pytest.fixture(autouse=True)
def isolated_db(tmp_path, monkeypatch):
    """테스트마다 독립된 임시 SQLite DB 사용."""
    import core.database as db_module
    db_path = str(tmp_path / "test_phase2.db")
    monkeypatch.setattr(db_module, "DB_PATH", db_path)
    db_module.init_db()
    yield


@pytest.fixture
def ontology_store(tmp_path):
    from ontology.ontology_store import OntologyStore
    return OntologyStore(
        drafts_dir=tmp_path / "ontologies" / "drafts",
        confirmed_dir=tmp_path / "ontologies" / "confirmed",
    )


@pytest.fixture
def manager(ontology_store):
    from ontology.ontology_manager import OntologyManager
    return OntologyManager(store=ontology_store)


@pytest.fixture
def history():
    from core.history_store import HistoryStore
    return HistoryStore()


# ── P2-1: 온톨로지 이벤트 발행 ────────────────────────────────────────────────

class TestOntologyEventRecording:

    def test_create_records_event(self, manager, history):
        """create() → ontology_events 에 'created' 이벤트 기록"""
        manager.create("v1.0", description="테스트")
        events = history.list_ontology_events(version_id="v1.0")
        assert len(events) == 1
        assert events[0]["event_type"] == "created"
        assert events[0]["version_id"] == "v1.0"
        assert "테스트" in events[0]["detail"]

    def test_update_records_event(self, manager, history):
        """update() → ontology_events 에 'updated' 이벤트 기록"""
        from ontology.ontology_manager import OntologyClass
        manager.create("v1.0")
        manager.update("v1.0", classes=[
            OntologyClass(name="Person", label_ko="인물", color="#ff0000")
        ])
        events = history.list_ontology_events(version_id="v1.0",
                                               event_type="updated")
        assert len(events) == 1
        assert "클래스 1개" in events[0]["detail"]

    def test_confirm_records_event(self, manager, history):
        """confirm() → ontology_events 에 'confirmed' 이벤트 기록 + after_snapshot 포함"""
        import json
        from ontology.ontology_manager import OntologyClass
        manager.create("v1.0")
        manager.update("v1.0", classes=[
            OntologyClass(name="Person", label_ko="인물", color="#ff0000")
        ])
        manager.confirm("v1.0")

        events = history.list_ontology_events(version_id="v1.0",
                                               event_type="confirmed")
        assert len(events) == 1
        ev = events[0]
        assert ev["event_type"] == "confirmed"
        assert "클래스 1개" in ev["detail"]
        after = json.loads(ev["after_snapshot"])
        assert after["version_id"] == "v1.0"

    def test_delete_records_event(self, manager, history):
        """delete() → ontology_events 에 'deleted' 이벤트 기록"""
        manager.create("v1.0")
        manager.delete("v1.0")
        events = history.list_ontology_events(version_id="v1.0",
                                               event_type="deleted")
        assert len(events) == 1

    def test_archive_records_event(self, manager, history):
        """archive() → ontology_events 에 'archived' 이벤트 기록"""
        manager.create("v1.0")
        manager.confirm("v1.0")
        manager.archive("v1.0")
        events = history.list_ontology_events(version_id="v1.0",
                                               event_type="archived")
        assert len(events) == 1

    def test_timeline_order(self, manager, history):
        """타임라인: created → updated → confirmed 순 이벤트 3개"""
        from ontology.ontology_manager import OntologyClass
        manager.create("v1.0")
        manager.update("v1.0", classes=[
            OntologyClass(name="Person", label_ko="인물", color="#ff0000")
        ])
        manager.confirm("v1.0")

        timeline = history.get_version_timeline("v1.0")
        assert len(timeline) == 3
        # 최신순이므로 confirmed → updated → created
        types = [e["event_type"] for e in timeline]
        assert types == ["confirmed", "updated", "created"]


# ── P2-2: 트리플 추출 세션 관리 ───────────────────────────────────────────────

class TestExtractionSessionManagement:

    def test_create_session(self, history):
        """세션 생성 → status=running, total_records 정확"""
        s = history.create_session("v1.0", ["rec1", "rec2", "rec3"])
        assert s["status"] == "running"
        assert s["total_records"] == 3
        assert len(s["records"]) == 3

    def test_update_progress(self, history):
        """진행 업데이트 → processed_records, extracted_count 반영"""
        s = history.create_session("v1.0", ["rec1"])
        history.update_session_progress(s["id"],
                                        processed_records=1,
                                        extracted_count=12)
        detail = history.get_session_detail(s["id"])
        assert detail["processed_records"] == 1
        assert detail["extracted_count"] == 12

    def test_fail_session(self, history):
        """fail_session() → status=failed, note에 에러 메시지"""
        s = history.create_session("v1.0", ["rec1"])
        history.fail_session(s["id"], "AI API 타임아웃")
        detail = history.get_session_detail(s["id"])
        assert detail["status"] == "failed"
        assert "AI API 타임아웃" in detail["note"]


# ── P2-3: bulk-confirm 세션 완료 ──────────────────────────────────────────────

class TestBulkConfirmSessionCompletion:

    def test_complete_session_after_bulk_confirm(self, history):
        """complete_session() → status=completed, 카운터 정확, completed_at 기록"""
        s = history.create_session("v1.0", ["rec1"])
        history.update_session_progress(s["id"], 1, 10)

        completed = history.complete_session(
            session_id=s["id"],
            confirmed=8,
            rejected=1,
            modified=3,
        )
        assert completed["status"] == "completed"
        assert completed["confirmed_count"] == 8
        assert completed["rejected_count"] == 1
        assert completed["modified_count"] == 3
        assert completed["completed_at"] != ""

    def test_session_list_status_filter(self, history):
        """완료 세션과 실행 중 세션 필터링"""
        s1 = history.create_session("v1.0", [])
        history.complete_session(s1["id"], 5, 0, 0)
        history.create_session("v2.0", [])  # running

        completed = history.list_sessions(status="completed")
        running   = history.list_sessions(status="running")
        assert len(completed) == 1
        assert len(running)   == 1


# ── Phase 2 완료 기준: get_summary() 통계 ─────────────────────────────────────

class TestSummaryStats:

    def test_summary_reflects_all_activity(self, manager, history, ontology_store):
        """
        온톨로지 생성+확정 + 기록 생성 + 세션 완료 후
        get_summary() 통계 정확성 검증.
        """
        from ontology.ontology_manager import OntologyClass
        from core.record_store import RecordStore

        # 온톨로지 2개 생성, 1개 확정
        manager.create("v1.0")
        manager.update("v1.0", classes=[
            OntologyClass(name="Person", label_ko="인물", color="#ff0000")
        ])
        manager.confirm("v1.0")
        manager.create("v2.0")  # draft 상태 유지

        # 구술기록 2개
        rs = RecordStore()
        rs.create_text("기록1", "구술 내용 1")
        rs.create_text("기록2", "구술 내용 2")

        # 세션 1개 완료
        s = history.create_session("v1.0", [])
        history.complete_session(s["id"], confirmed=10, rejected=2, modified=1)

        summary = history.get_summary()

        assert summary["records"] == 2
        assert summary["ontology_versions"] == 2      # v1.0, v2.0 모두 이벤트 있음
        assert summary["confirmed_ontologies"] == 1   # v1.0만 confirmed
        assert summary["extraction_sessions"] == 1
        assert summary["last_activity"] != ""
