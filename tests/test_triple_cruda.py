"""tests/test_triple_cruda.py — Phase B: list_triples + full update + role 가드"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from graph.graph_db import GraphDB, TripleStatus, EXTRACTION_AUTO, EXTRACTION_EDITED
from graph.triple_manager import TripleManager


# ── TripleManager 픽스처 ───────────────────────────────────────────────────────

@pytest.fixture
def tm(tmp_path):
    db = GraphDB(graph_file=tmp_path / "graph.json", auto_save=True)
    return TripleManager(graph_db=db)


def _c(tm, subject="김영수", predicate="출생지", object_="경북안동", **kw):
    return tm.create(
        subject=subject, subject_type=kw.pop("subject_type", "Person"),
        predicate=predicate,
        object_=object_, object_type=kw.pop("object_type", "Place"),
        ontology_version=kw.pop("ontology_version", "v1.0"),
        **kw,
    )


# ── list_triples 필터 테스트 ──────────────────────────────────────────────────

def test_list_returns_all_active(tm):
    _c(tm); _c(tm, predicate="거주지", object_="서울")
    result = tm.list_triples()
    assert len(result) == 2


def test_list_filter_by_ontology_version(tm):
    _c(tm, ontology_version="v1.0")
    _c(tm, predicate="거주지", object_="서울", ontology_version="v2.0")
    assert len(tm.list_triples(ontology_version="v1.0")) == 1
    assert len(tm.list_triples(ontology_version="v2.0")) == 1


def test_list_filter_by_source_record_id(tm):
    _c(tm, source_record_id="rec_001")
    _c(tm, predicate="거주지", object_="서울", source_record_id="rec_002")
    assert len(tm.list_triples(source_record_id="rec_001")) == 1


def test_list_filter_by_created_by(tm):
    _c(tm, created_by="홍길동")
    _c(tm, predicate="거주지", object_="서울", created_by="system")
    assert len(tm.list_triples(created_by="홍길동")) == 1
    assert len(tm.list_triples(created_by="system")) == 1


def test_list_filter_status_active(tm):
    t = _c(tm)
    _c(tm, predicate="거주지", object_="서울")
    tm.archive(t.id)
    assert len(tm.list_triples(status="active")) == 1


def test_list_filter_status_archived(tm):
    t = _c(tm)
    tm.archive(t.id)
    archived = tm.list_triples(status="archived")
    assert len(archived) == 1
    assert archived[0].status == TripleStatus.ARCHIVED


def test_list_filter_date_from(tm):
    t1 = _c(tm)
    # created_at 을 과거로 조작 (DB 직접 접근)
    t1.created_at = "2025-01-01T00:00:00"
    _c(tm, predicate="거주지", object_="서울")  # 현재 시각
    result = tm.list_triples(date_from="2026-01-01")
    assert all(t.created_at >= "2026-01-01" for t in result)


def test_list_sorted_desc(tm):
    t1 = _c(tm)
    t2 = _c(tm, predicate="거주지", object_="서울")
    t1.created_at = "2025-01-01T00:00:00"
    t2.created_at = "2026-06-01T00:00:00"
    result = tm.list_triples()
    assert result[0].id == t2.id  # 최신이 먼저


# ── full update (subject 변경) 테스트 ─────────────────────────────────────────

def test_update_subject(tm):
    t = _c(tm, subject="김영수")
    updated = tm.update(t.id, subject="박철호", updated_by="관리자")
    assert updated.subject == "박철호"
    assert updated.updated_by == "관리자"
    assert updated.extraction_method == EXTRACTION_EDITED


def test_update_subject_recalcs_nodes(tm):
    db = tm.db
    t = _c(tm, subject="김영수")
    assert "김영수" in db._nodes

    tm.update(t.id, subject="박철호")

    # 새 노드 추가, 구 노드 제거
    assert "박철호" in db._nodes
    assert "김영수" not in db._nodes


def test_update_subject_type(tm):
    t = _c(tm, subject="6·25전쟁", subject_type="Event")
    updated = tm.update(t.id, subject_type="Topic")
    assert updated.subject_type == "Topic"


def test_update_partial_no_subject_keeps_others(tm):
    t = _c(tm, subject="김영수", predicate="출생지")
    updated = tm.update(t.id, predicate="거주지", updated_by="admin")
    assert updated.subject == "김영수"   # 변경 없음
    assert updated.predicate == "거주지"


# ── API role 가드 테스트 ──────────────────────────────────────────────────────

@pytest.fixture
def api(tmp_path):
    """격리된 GraphDB를 사용하는 FastAPI TestClient."""
    import api.router_triple as rt
    # 싱글톤 초기화 — 테스트마다 새 DB
    rt._db = GraphDB(graph_file=tmp_path / "graph.json", auto_save=True)
    rt._tm = TripleManager(graph_db=rt._db)
    rt._extractor = None

    from main import app
    return TestClient(app, raise_server_exceptions=True)


def test_list_endpoint_no_role_allowed(api):
    """GET /list 는 인증 불필요."""
    resp = api.get("/api/triples/list")
    assert resp.status_code == 200
    assert "triples" in resp.json()


def test_create_requires_admin(api):
    resp = api.post("/api/triples/", json={
        "subject": "A", "subject_type": "Person",
        "predicate": "관계", "object": "B", "object_type": "Place",
        "ontology_version": "v1.0",
    })
    assert resp.status_code == 403


def test_create_with_admin_header(api):
    resp = api.post("/api/triples/", json={
        "subject": "A", "subject_type": "Person",
        "predicate": "관계", "object": "B", "object_type": "Place",
        "ontology_version": "v1.0",
    }, headers={"x-role": "admin"})
    assert resp.status_code == 201


def test_delete_requires_admin(api):
    # 먼저 admin으로 생성
    r = api.post("/api/triples/", json={
        "subject": "A", "subject_type": "Person",
        "predicate": "관계", "object": "B", "object_type": "Place",
        "ontology_version": "v1.0",
    }, headers={"x-role": "admin"})
    tid = r.json()["id"]

    # viewer로 삭제 시도
    resp = api.delete(f"/api/triples/{tid}")
    assert resp.status_code == 403

    # admin으로 삭제
    resp = api.delete(f"/api/triples/{tid}", headers={"x-role": "admin"})
    assert resp.status_code == 204


def test_put_full_update(api):
    r = api.post("/api/triples/", json={
        "subject": "김영수", "subject_type": "Person",
        "predicate": "출생지", "object": "경북안동", "object_type": "Place",
        "ontology_version": "v1.0",
    }, headers={"x-role": "admin"})
    tid = r.json()["id"]

    resp = api.put(f"/api/triples/{tid}", json={
        "subject": "박철호",
        "predicate": "거주지",
        "updated_by": "관리자",
    }, headers={"x-role": "admin"})
    assert resp.status_code == 200
    data = resp.json()
    assert data["subject"] == "박철호"
    assert data["predicate"] == "거주지"
    assert data["updated_by"] == "관리자"


def test_archive_patch(api):
    r = api.post("/api/triples/", json={
        "subject": "A", "subject_type": "Person",
        "predicate": "관계", "object": "B", "object_type": "Place",
        "ontology_version": "v1.0",
    }, headers={"x-role": "admin"})
    tid = r.json()["id"]

    resp = api.patch(f"/api/triples/{tid}/archive",
                     json={"reason": "테스트 아카이브"},
                     headers={"x-role": "admin"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "archived"


def test_list_filter_via_api(api):
    # admin으로 트리플 2개 생성
    for pred, obj in [("출생지", "경북안동"), ("거주지", "서울")]:
        api.post("/api/triples/", json={
            "subject": "김영수", "subject_type": "Person",
            "predicate": pred, "object": obj, "object_type": "Place",
            "ontology_version": "v1.0",
        }, headers={"x-role": "admin"})

    resp = api.get("/api/triples/list?version=v1.0")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] == 2
    assert all(t["ontology_version"] == "v1.0" for t in data["triples"])
