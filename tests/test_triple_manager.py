"""tests/test_triple_manager.py — TripleManager 단위 테스트"""

from __future__ import annotations

import pytest

from graph.graph_db import GraphDB, TripleStatus
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


# ── 테스트 ────────────────────────────────────────────────────────────────────

def test_create(tm):
    t = _create(tm)
    assert t.subject == "김영수"
    assert t.predicate == "출생지"


def test_duplicate_returns_existing(tm):
    t1 = _create(tm)
    t2 = _create(tm)
    assert t1.id == t2.id


def test_update(tm):
    t = _create(tm)
    updated = tm.update(t.id, note="수정된 메모")
    assert updated.note == "수정된 메모"
    assert updated.updated_at is not None


def test_delete(tm):
    t = _create(tm)
    tm.delete(t.id)
    with pytest.raises(KeyError):
        tm.get(t.id)


def test_archive(tm):
    t = _create(tm)
    archived = tm.archive(t.id, reason="오류 데이터")
    assert archived.status == TripleStatus.ARCHIVED
    assert archived.archived_at is not None


def test_bulk_create(tm):
    items = [
        {"subject": "김영수", "subjectType": "Person",
         "predicate": "출생지", "object": "경북안동", "objectType": "Place"},
        {"subject": "김영수", "subjectType": "Person",
         "predicate": "참여함", "object": "6·25전쟁", "objectType": "Event"},
        # 중복
        {"subject": "김영수", "subjectType": "Person",
         "predicate": "출생지", "object": "경북안동", "objectType": "Place"},
    ]
    result = tm.bulk_create(items, ontology_version="v1.0")
    assert result["added"]   == 2
    assert result["skipped"] == 1
    assert len(result["triples"]) == 3


def test_search_with_neighbor(tm):
    _create(tm, subject="김영수", predicate="출생지",  object_="경북안동")
    _create(tm, subject="김영수", predicate="참여함",  object_="6·25전쟁")
    _create(tm, subject="박철호", predicate="거주지",  object_="서울")

    result = tm.search("김영수")
    node_ids = {n["id"] for n in result["nodes"]}
    assert "김영수"  in node_ids
    assert "경북안동" in node_ids
    assert "6·25전쟁" in node_ids
    assert "박철호"  not in node_ids


def test_get_not_found(tm):
    with pytest.raises(KeyError):
        tm.get("nonexistent")


def test_stats(tm):
    _create(tm, subject="A", object_="B")
    _create(tm, subject="C", object_="D")
    s = tm.stats()
    assert s["triples"] == 2
    assert s["active"]  == 2
