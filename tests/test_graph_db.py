"""tests/test_graph_db.py — GraphDB 단위 테스트"""

from __future__ import annotations

import json
import pytest

from graph.graph_db import GraphDB, Triple, TripleStatus


@pytest.fixture
def db(tmp_path):
    """임시 경로를 사용하는 GraphDB."""
    return GraphDB(graph_file=tmp_path / "graph.json", auto_save=True)


def _triple(**kwargs) -> Triple:
    defaults = dict(
        subject="김영수", subject_type="Person",
        predicate="출생지",
        object="경북안동", object_type="Place",
        ontology_version="v1.0",
    )
    defaults.update(kwargs)
    return Triple(**defaults)


# ── 테스트 ────────────────────────────────────────────────────────────────────

def test_add_and_get(db):
    t = _triple()
    assert db.add(t) is True
    result = db.get(t.id)
    assert result is not None
    assert result.subject == "김영수"


def test_auto_save_creates_file(db, tmp_path):
    db.add(_triple())
    graph_file = tmp_path / "graph.json"
    assert graph_file.exists()
    data = json.loads(graph_file.read_text(encoding="utf-8"))
    assert len(data["triples"]) == 1


def test_load_on_init(tmp_path):
    graph_file = tmp_path / "graph.json"
    db1 = GraphDB(graph_file=graph_file, auto_save=True)
    t = _triple()
    db1.add(t)

    db2 = GraphDB(graph_file=graph_file, auto_save=False)
    assert db2.get(t.id) is not None
    assert db2.get(t.id).subject == "김영수"


def test_atomic_write(db, tmp_path):
    """저장 후 tmp 파일이 남아있지 않아야 한다."""
    db.add(_triple())
    tmp_file = tmp_path / "graph.json.tmp"
    assert not tmp_file.exists()


def test_query_subgraph(db):
    db.add(_triple(subject="김영수", predicate="출생지",  object="경북안동"))
    db.add(_triple(subject="김영수", predicate="참여함",  object="6·25전쟁"))
    db.add(_triple(subject="박철호", predicate="거주지",  object="서울"))

    result = db.query("김영수")
    node_ids = {n["id"] for n in result["nodes"]}
    # 매칭 노드
    assert "김영수" in node_ids
    # 1홉 이웃
    assert "경북안동" in node_ids
    assert "6·25전쟁" in node_ids
    # 비매칭
    assert "박철호" not in node_ids


def test_stats(db):
    db.add(_triple(subject="A", object="B"))
    db.add(_triple(subject="C", object="D"))
    s = db.stats()
    assert s["triples"] == 2
    assert s["active"]  == 2
    assert s["nodes"]   == 4


def test_archive_not_delete(db):
    """archive → status 변경, 레코드 유지."""
    t = _triple()
    db.add(t)
    db.update(t.id, status=TripleStatus.ARCHIVED,
              archived_at="2026-04-06T00:00:00")

    # 기본 조회에서는 제외
    assert len(db.all_triples()) == 0
    # include_archived=True 시 포함
    all_ = db.all_triples(include_archived=True)
    assert len(all_) == 1
    assert all_[0].status == TripleStatus.ARCHIVED


def test_remove(db):
    t = _triple()
    db.add(t)
    assert db.remove(t.id) is True
    assert db.get(t.id) is None


def test_duplicate_add(db):
    t = _triple()
    db.add(t)
    assert db.add(t) is False   # 중복 추가 → False
