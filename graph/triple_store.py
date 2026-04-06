# graph/triple_store.py
# 인메모리 트리플 스토어
# (subject, predicate, object) 형식의 트리플을 networkx DiGraph로 관리한다.

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import networkx as nx

from ontology.ontology import NodeType, RelationType


@dataclass
class Triple:
    """RDF 스타일 트리플"""
    subject:   str           # 노드 ID
    predicate: RelationType  # 관계 타입
    object:    str           # 노드 ID
    weight:    float = 1.0   # 관계 강도 (선택)


class TripleStore:
    """
    networkx DiGraph 기반 인메모리 트리플 스토어.

    사용 예:
        store = TripleStore()
        store.add_node("rec-001", NodeType.RECORD, title="제주 4.3 구술")
        store.add_node("nar-001", NodeType.NARRATOR, name="김철수")
        store.add_triple(Triple("rec-001", RelationType.NARRATED_BY, "nar-001"))
    """

    def __init__(self) -> None:
        self._graph: nx.DiGraph = nx.DiGraph()

    # ── 노드 ────────────────────────────────────────────────────

    def add_node(self, node_id: str, node_type: NodeType, **attrs: Any) -> None:
        """노드 추가. 이미 존재하면 속성을 업데이트한다."""
        self._graph.add_node(node_id, node_type=node_type, **attrs)

    def get_node(self, node_id: str) -> dict[str, Any] | None:
        if node_id not in self._graph:
            return None
        return dict(self._graph.nodes[node_id])

    def nodes_by_type(self, node_type: NodeType) -> list[str]:
        return [
            n for n, d in self._graph.nodes(data=True)
            if d.get("node_type") == node_type
        ]

    # ── 트리플(엣지) ─────────────────────────────────────────────

    def add_triple(self, triple: Triple) -> None:
        """트리플 추가. 양쪽 노드가 없으면 KeyError를 발생시킨다."""
        if triple.subject not in self._graph:
            raise KeyError(f"subject 노드 없음: {triple.subject}")
        if triple.object not in self._graph:
            raise KeyError(f"object 노드 없음: {triple.object}")
        self._graph.add_edge(
            triple.subject,
            triple.object,
            predicate=triple.predicate,
            weight=triple.weight,
        )

    def triples(
        self,
        subject:   str | None = None,
        predicate: RelationType | None = None,
        object_:   str | None = None,
    ) -> list[Triple]:
        """조건에 맞는 트리플 목록 반환."""
        result = []
        for s, o, d in self._graph.edges(data=True):
            if subject   is not None and s != subject:
                continue
            if predicate is not None and d.get("predicate") != predicate:
                continue
            if object_   is not None and o != object_:
                continue
            result.append(Triple(s, d["predicate"], o, d.get("weight", 1.0)))
        return result

    # ── 조회 ─────────────────────────────────────────────────────

    def neighbors(self, node_id: str, predicate: RelationType | None = None) -> list[str]:
        """node_id에서 나가는 이웃 노드 목록."""
        return [
            o for _, o, d in self._graph.out_edges(node_id, data=True)
            if predicate is None or d.get("predicate") == predicate
        ]

    def subgraph(self, node_ids: list[str]) -> nx.DiGraph:
        """지정 노드들의 서브그래프 반환."""
        return self._graph.subgraph(node_ids).copy()

    # ── 통계 ─────────────────────────────────────────────────────

    def stats(self) -> dict[str, int]:
        return {
            "nodes": self._graph.number_of_nodes(),
            "edges": self._graph.number_of_edges(),
        }

    def __repr__(self) -> str:
        s = self.stats()
        return f"TripleStore(nodes={s['nodes']}, edges={s['edges']})"
