# tests/test_triple_store.py
# TripleStore 단위 테스트

import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from graph.triple_store import Triple, TripleStore
from ontology.ontology import NodeType, RelationType


@pytest.fixture
def store() -> TripleStore:
    s = TripleStore()
    s.add_node("rec-001", NodeType.RECORD, title="제주 4.3 구술")
    s.add_node("nar-001", NodeType.NARRATOR, name="김철수")
    s.add_node("cat:정치사건", NodeType.CATEGORY, name="정치사건")
    return s


def test_add_node(store: TripleStore) -> None:
    node = store.get_node("rec-001")
    assert node is not None
    assert node["title"] == "제주 4.3 구술"
    assert node["node_type"] == NodeType.RECORD


def test_add_triple(store: TripleStore) -> None:
    store.add_triple(Triple("rec-001", RelationType.NARRATED_BY, "nar-001"))
    triples = store.triples(subject="rec-001")
    assert len(triples) == 1
    assert triples[0].predicate == RelationType.NARRATED_BY
    assert triples[0].object == "nar-001"


def test_triple_missing_node_raises(store: TripleStore) -> None:
    with pytest.raises(KeyError):
        store.add_triple(Triple("rec-001", RelationType.NARRATED_BY, "nar-999"))


def test_nodes_by_type(store: TripleStore) -> None:
    records = store.nodes_by_type(NodeType.RECORD)
    assert "rec-001" in records


def test_neighbors(store: TripleStore) -> None:
    store.add_triple(Triple("rec-001", RelationType.NARRATED_BY, "nar-001"))
    store.add_triple(Triple("rec-001", RelationType.BELONGS_TO, "cat:정치사건"))
    neighbors = store.neighbors("rec-001")
    assert set(neighbors) == {"nar-001", "cat:정치사건"}


def test_stats(store: TripleStore) -> None:
    s = store.stats()
    assert s["nodes"] == 3
    assert s["edges"] == 0
