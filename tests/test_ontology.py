# tests/test_ontology.py
# 온톨로지 정의 단위 테스트

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ontology.ontology import NODE_SCHEMA, NodeType, RelationType


def test_node_types_defined() -> None:
    expected = {
        "Record", "Narrator", "Interviewer", "Session",
        "Category", "Keyword", "Event", "Place", "Person",
    }
    actual = {nt.value for nt in NodeType}
    assert actual == expected


def test_relation_types_defined() -> None:
    assert RelationType.NARRATED_BY == "narrated_by"
    assert RelationType.BELONGS_TO  == "belongs_to"
    assert RelationType.TAGGED_WITH == "tagged_with"


def test_schema_required_fields() -> None:
    assert "id"    in NODE_SCHEMA[NodeType.RECORD]["required"]
    assert "name"  in NODE_SCHEMA[NodeType.NARRATOR]["required"]
    assert "name"  in NODE_SCHEMA[NodeType.KEYWORD]["required"]


def test_all_node_types_have_schema() -> None:
    for nt in NodeType:
        assert nt in NODE_SCHEMA, f"{nt} 스키마 없음"
