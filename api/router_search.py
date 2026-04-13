"""api/router_search.py — 검색 API 엔드포인트 (F6)"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from api.router_triple import get_triple_manager

router = APIRouter(prefix="/api/graph", tags=["지식그래프"])


@router.get("")
def full_graph(ontology_version: str = Query("", description="온톨로지 버전 필터 (빈 값=전체)")):
    """전체 그래프 (모든 노드 + 트리플). ontology_version 으로 필터링 가능."""
    result = get_triple_manager().search(
        query="",
        ontology_version=ontology_version or None,
    )

    # ontology_version 필터 시 노드도 트리플 기준으로 재계산
    if ontology_version:
        valid_ids: set[str] = set()
        for t in result["triples"]:
            valid_ids.add(t["subject"])
            valid_ids.add(t["object"])
        result["nodes"] = [n for n in result["nodes"] if n["id"] in valid_ids]

    return result


@router.get("/ontology-versions")
def get_ontology_versions():
    """트리플에 실제 사용된 온톨로지 버전 목록 (버전별 트리플 수 포함)."""
    from collections import Counter
    all_triples = get_triple_manager().db.all_triples(include_archived=False)
    counts: Counter = Counter()
    for t in all_triples:
        v = t.ontology_version or "미지정"
        counts[v] += 1

    # 지정 버전 정렬, 미지정은 마지막
    named   = sorted(v for v in counts if v != "미지정")
    ordered = named + (["미지정"] if "미지정" in counts else [])

    return {
        "versions": [
            {"version_id": v, "triple_count": counts[v]}
            for v in ordered
        ]
    }


@router.get("/search")
def search_graph(q: str = Query(..., description="검색어")):
    """검색어 기반 서브그래프 (매칭 노드 + 1홉 이웃)."""
    return get_triple_manager().search(query=q)


@router.get("/node/{node_id}")
def get_node(node_id: str):
    """노드 상세 + 연결된 트리플 목록."""
    tm  = get_triple_manager()
    db  = tm.db

    node = db._nodes.get(node_id)
    if node is None:
        raise HTTPException(status_code=404,
                            detail=f"노드를 찾을 수 없습니다: {node_id!r}")

    connected = [
        db._triple_to_dict(t)
        for t in db.all_triples()
        if t.subject == node_id or t.object == node_id
    ]
    return {"node": node, "triples": connected}
