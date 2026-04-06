# pipeline/hive_pipeline.py
# Hive JSON 내보내기 → 트리플 파이프라인
# 앱에서 내보낸 records.json을 읽어 TripleStore에 적재한다.

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from graph.triple_store import Triple, TripleStore
from ontology.ontology import NodeType, RelationType


def load_from_json(path: str | Path, store: TripleStore | None = None) -> TripleStore:
    """
    records.json (앱 내보내기 포맷)을 읽어 TripleStore로 변환한다.

    Args:
        path:  records.json 파일 경로
        store: 기존 스토어에 추가할 경우 전달. None이면 새로 생성.

    Returns:
        적재 완료된 TripleStore
    """
    if store is None:
        store = TripleStore()

    data: list[dict[str, Any]] = json.loads(Path(path).read_text(encoding="utf-8"))

    for rec in data:
        _ingest_record(rec, store)

    return store


def _ingest_record(rec: dict[str, Any], store: TripleStore) -> None:
    """Record 딕셔너리 → 노드 + 트리플 추가."""
    rec_id = rec.get("id", "")
    if not rec_id:
        return

    # ── Record 노드 ──────────────────────────────────────────────
    store.add_node(
        rec_id,
        NodeType.RECORD,
        title=rec.get("title", ""),
        display_id=rec.get("displayId"),
        summary=rec.get("summary"),
        main_category=rec.get("mainCategory", ""),
        input_type=rec.get("inputType", ""),
        created_at=rec.get("createdAt"),
    )

    # ── Narrator 노드 + 트리플 ────────────────────────────────────
    narrator_id = rec.get("narratorId")
    if narrator_id:
        if store.get_node(narrator_id) is None:
            store.add_node(narrator_id, NodeType.NARRATOR, name="")
        store.add_triple(Triple(rec_id, RelationType.NARRATED_BY, narrator_id))

    # ── Category 노드 + 트리플 ────────────────────────────────────
    main_cat = rec.get("mainCategory", "").strip()
    if main_cat:
        cat_id = f"cat:{main_cat}"
        if store.get_node(cat_id) is None:
            store.add_node(cat_id, NodeType.CATEGORY, name=main_cat)
        store.add_triple(Triple(rec_id, RelationType.BELONGS_TO, cat_id))

    # ── Keyword 노드 + 트리플 ─────────────────────────────────────
    for kw in rec.get("keywordTags", []):
        kw = kw.strip()
        if not kw:
            continue
        kw_id = f"kw:{kw}"
        if store.get_node(kw_id) is None:
            store.add_node(kw_id, NodeType.KEYWORD, name=kw)
        store.add_triple(Triple(rec_id, RelationType.TAGGED_WITH, kw_id))

    # ── Session 노드 + 트리플 ─────────────────────────────────────
    session_id = rec.get("sessionId")
    if session_id:
        if store.get_node(session_id) is None:
            store.add_node(session_id, NodeType.SESSION, interview_date="")
        store.add_triple(Triple(rec_id, RelationType.PART_OF_SESSION, session_id))
