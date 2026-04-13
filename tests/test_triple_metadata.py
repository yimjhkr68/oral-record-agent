"""tests/test_triple_metadata.py — Triple 메타데이터 필드 단위 테스트 (Phase A)"""

from __future__ import annotations

import json

import pytest

from graph.graph_db import GraphDB, Triple, TripleStatus, EXTRACTION_AUTO, EXTRACTION_MANUAL, EXTRACTION_EDITED
from graph.triple_manager import TripleManager


@pytest.fixture
def tm(tmp_path):
    db = GraphDB(graph_file=tmp_path / "graph.json", auto_save=True)
    return TripleManager(graph_db=db)


def _create(tm: TripleManager, **kwargs):
    defaults = dict(
        subject="김영수", subject_type="Person",
        predicate="출생지",
        object_="경북안동", object_type="Place",
        ontology_version="v1.0",
    )
    defaults.update(kwargs)
    return tm.create(**defaults)


# ── 기본값 테스트 ──────────────────────────────────────────────────────────────

def test_default_created_by(tm):
    t = _create(tm)
    assert t.created_by == "system"


def test_default_extraction_method(tm):
    t = _create(tm)
    assert t.extraction_method == EXTRACTION_AUTO


def test_default_updated_by_is_none(tm):
    t = _create(tm)
    assert t.updated_by is None


def test_created_at_is_set(tm):
    t = _create(tm)
    assert t.created_at != ""


# ── 커스텀 값 설정 테스트 ──────────────────────────────────────────────────────

def test_custom_created_by(tm):
    t = _create(tm, created_by="홍길동")
    assert t.created_by == "홍길동"


def test_manual_extraction_method(tm):
    t = _create(tm, extraction_method=EXTRACTION_MANUAL)
    assert t.extraction_method == EXTRACTION_MANUAL


# ── update 메타데이터 테스트 ──────────────────────────────────────────────────

def test_update_sets_updated_by(tm):
    t = _create(tm)
    updated = tm.update(t.id, note="수정됨", updated_by="관리자")
    assert updated.updated_by == "관리자"
    assert updated.updated_at is not None


def test_update_sets_extraction_method_to_edited(tm):
    t = _create(tm)
    updated = tm.update(t.id, note="수정됨", updated_by="관리자")
    assert updated.extraction_method == EXTRACTION_EDITED


def test_update_without_updated_by_keeps_original_method(tm):
    t = _create(tm, extraction_method=EXTRACTION_AUTO)
    updated = tm.update(t.id, note="메모만 변경")
    # updated_by 없이 수정 → extraction_method 유지
    assert updated.extraction_method == EXTRACTION_AUTO


# ── bulk_create 메타데이터 테스트 ─────────────────────────────────────────────

def test_bulk_create_default_metadata(tm):
    items = [
        {"subject": "A", "subjectType": "Person",
         "predicate": "관계", "object": "B", "objectType": "Place"},
    ]
    result = tm.bulk_create(items, ontology_version="v1.0",
                            created_by="시스템배치")
    t = result["triples"][0]
    assert t.created_by == "시스템배치"
    assert t.extraction_method == EXTRACTION_AUTO


def test_bulk_create_item_level_metadata_overrides(tm):
    """개별 item에 메타데이터가 있으면 bulk 기본값보다 우선."""
    items = [
        {"subject": "A", "subjectType": "Person",
         "predicate": "관계", "object": "B", "objectType": "Place",
         "created_by": "홍길동", "extraction_method": EXTRACTION_MANUAL},
    ]
    result = tm.bulk_create(items, ontology_version="v1.0",
                            created_by="시스템배치")
    t = result["triples"][0]
    assert t.created_by == "홍길동"
    assert t.extraction_method == EXTRACTION_MANUAL


# ── 직렬화/역직렬화 호환성 테스트 ─────────────────────────────────────────────

def test_roundtrip_with_metadata(tmp_path):
    """저장 → 재로드 시 메타데이터 필드 보존."""
    graph_file = tmp_path / "graph.json"
    db1 = GraphDB(graph_file=graph_file, auto_save=True)
    tm1 = TripleManager(graph_db=db1)
    t = tm1.create(
        subject="김영수", subject_type="Person",
        predicate="출생지", object_="경북안동", object_type="Place",
        ontology_version="v1.0",
        created_by="홍길동",
        extraction_method=EXTRACTION_MANUAL,
    )
    tm1.update(t.id, note="수정", updated_by="관리자")

    # 재로드
    db2 = GraphDB(graph_file=graph_file, auto_save=False)
    reloaded = db2.get(t.id)
    assert reloaded is not None
    assert reloaded.created_by == "홍길동"
    assert reloaded.extraction_method == EXTRACTION_EDITED
    assert reloaded.updated_by == "관리자"


def test_backward_compat_old_json_without_metadata(tmp_path):
    """메타데이터 필드 없는 구 JSON 로드 시 기본값 적용."""
    graph_file = tmp_path / "graph.json"
    # 구 형식 JSON (created_by, extraction_method, updated_by 없음)
    old_data = {
        "version": "4.0",
        "last_updated": "2026-01-01T00:00:00",
        "stats": {"nodes": 2, "triples": 1, "active": 1, "archived": 0},
        "nodes": {},
        "triples": [
            {
                "subject": "김영수",
                "subject_type": "Person",
                "predicate": "출생지",
                "object": "경북안동",
                "object_type": "Place",
                "ontology_version": "v1.0",
                "source_record_id": None,
                "confidence": 1.0,
                "status": "active",
                "created_at": "2026-01-01T00:00:00",
                "updated_at": None,
                "archived_at": None,
                "note": "",
                "id": "abc12345",
            }
        ],
    }
    graph_file.write_text(json.dumps(old_data), encoding="utf-8")

    db = GraphDB(graph_file=graph_file, auto_save=False)
    t = db.get("abc12345")
    assert t is not None
    assert t.created_by == "system"
    assert t.extraction_method == EXTRACTION_AUTO
    assert t.updated_by is None
