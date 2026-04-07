"""graph/graph_db.py — 인메모리 트리플 저장소 + 로컬 파일 자동 저장 (F5)"""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Optional

import os

from utils.file_io import atomic_write_json, ensure_dir, read_json

# DATA_DIR 환경변수 → 없으면 프로젝트 루트 data/
_DATA_ROOT = Path(os.environ["DATA_DIR"]) if os.environ.get("DATA_DIR") else Path(__file__).parent.parent / "data"
GRAPH_FILE_DEFAULT  = _DATA_ROOT / "triples" / "graph.json"
ARCHIVE_DIR_DEFAULT = _DATA_ROOT / "triples" / "archive"


# ── 데이터 모델 ────────────────────────────────────────────────────────────────

from enum import Enum
from dataclasses import dataclass, field
import uuid


class TripleStatus(str, Enum):
    ACTIVE   = "active"
    ARCHIVED = "archived"


@dataclass
class Triple:
    subject:          str = ""
    subject_type:     str = ""
    predicate:        str = ""
    object:           str = ""
    object_type:      str = ""
    ontology_version: str = ""
    source_record_id: Optional[str] = None
    confidence:       float = 1.0
    status:           TripleStatus = TripleStatus.ACTIVE
    created_at:       str = field(default_factory=lambda: datetime.now().isoformat())
    updated_at:       Optional[str] = None
    archived_at:      Optional[str] = None
    note:             str = ""
    id:               str = field(default_factory=lambda: str(uuid.uuid4())[:8])

    def __post_init__(self):
        if isinstance(self.status, str):
            self.status = TripleStatus(self.status)


# ── GraphDB ────────────────────────────────────────────────────────────────────

class GraphDB:
    """
    인메모리 트리플 저장소 + 로컬 파일 자동 저장.
    모든 데이터 변경 후 graph.json 에 자동 저장.
    """

    def __init__(self,
                 graph_file: Path | None = None,
                 auto_save: bool = True) -> None:
        self.graph_file = Path(graph_file) if graph_file else GRAPH_FILE_DEFAULT
        self.auto_save  = auto_save
        self._triples: dict[str, Triple] = {}   # id → Triple
        self._nodes:   dict[str, dict]   = {}   # node_id → {type, degree}
        self._load()

    # ── 내부 I/O ───────────────────────────────────────────────────────────────

    def _load(self) -> None:
        """graph.json 있으면 로드. 없으면 빈 상태. 파일 손상 시 빈 상태로 시작."""
        try:
            data = read_json(self.graph_file)
        except Exception:
            data = {}
        if not data:
            return
        self._nodes = data.get("nodes", {})
        for t in data.get("triples", []):
            try:
                triple = Triple(**t)
                self._triples[triple.id] = triple
            except Exception:
                pass  # 손상된 트리플 레코드 건너뜀

    def _save(self) -> None:
        """
        원자적 쓰기:
          1. graph.json.tmp 에 저장
          2. graph.json.tmp → graph.json rename
        """
        ensure_dir(self.graph_file.parent)
        active_count   = sum(1 for t in self._triples.values()
                             if t.status == TripleStatus.ACTIVE)
        archived_count = len(self._triples) - active_count
        data = {
            "version":      "4.0",
            "last_updated": datetime.now().isoformat(),
            "stats": {
                "nodes":    len(self._nodes),
                "triples":  len(self._triples),
                "active":   active_count,
                "archived": archived_count,
            },
            "nodes":   self._nodes,
            "triples": [self._triple_to_dict(t) for t in self._triples.values()],
        }
        atomic_write_json(str(self.graph_file), data)

    def _triple_to_dict(self, triple: Triple) -> dict:
        from dataclasses import asdict
        d = asdict(triple)
        d["status"] = triple.status.value
        return d

    def _auto_save(self) -> None:
        if self.auto_save:
            self._save()

    # ── 노드 갱신 ─────────────────────────────────────────────────────────────

    def _upsert_node(self, node_id: str, node_type: str, delta: int) -> None:
        if node_id not in self._nodes:
            self._nodes[node_id] = {"id": node_id, "type": node_type, "degree": 0}
        self._nodes[node_id]["degree"] = max(
            0, self._nodes[node_id]["degree"] + delta
        )

    def _recalc_degrees(self) -> None:
        """전체 트리플 기준으로 노드 degree 재계산."""
        degree: dict[str, int] = {}
        for t in self._triples.values():
            if t.status == TripleStatus.ACTIVE:
                degree[t.subject] = degree.get(t.subject, 0) + 1
                degree[t.object]  = degree.get(t.object, 0) + 1
        for node_id, node in self._nodes.items():
            node["degree"] = degree.get(node_id, 0)

    # ── CRUD ───────────────────────────────────────────────────────────────────

    def add(self, triple: Triple) -> bool:
        """추가. 중복(id) 시 False."""
        if triple.id in self._triples:
            return False
        self._triples[triple.id] = triple
        self._upsert_node(triple.subject, triple.subject_type, +1)
        self._upsert_node(triple.object,  triple.object_type,  +1)
        self._auto_save()
        return True

    def get(self, triple_id: str) -> Optional[Triple]:
        """ID로 단건 조회. 없으면 None."""
        return self._triples.get(triple_id)

    def update(self, triple_id: str, **kwargs) -> Optional[Triple]:
        """필드 업데이트 + updated_at 자동 갱신."""
        triple = self._triples.get(triple_id)
        if triple is None:
            return None
        allowed = {
            "predicate", "object", "object_type",
            "confidence", "note", "status",
            "archived_at",
        }
        for k, v in kwargs.items():
            if k in allowed:
                setattr(triple, k, v)
        triple.updated_at = datetime.now().isoformat()
        self._auto_save()
        return triple

    def remove(self, triple_id: str) -> bool:
        """영구 삭제."""
        triple = self._triples.pop(triple_id, None)
        if triple is None:
            return False
        self._recalc_degrees()
        # degree 0인 고립 노드 제거
        self._nodes = {nid: n for nid, n in self._nodes.items()
                       if n["degree"] > 0}
        self._auto_save()
        return True

    def query(self, search: str = "",
              include_archived: bool = False) -> dict:
        """
        검색어 기반 서브그래프 반환 (1홉 이웃 포함).
        search 없으면 전체 그래프.
        반환: {"nodes": [...], "triples": [...]}
        """
        triples = [
            t for t in self._triples.values()
            if include_archived or t.status == TripleStatus.ACTIVE
        ]

        if not search:
            return {
                "nodes":   list(self._nodes.values()),
                "triples": [self._triple_to_dict(t) for t in triples],
            }

        q = search.lower()
        # 1단계: 매칭 노드 수집
        matched_nodes: set[str] = set()
        for t in triples:
            if (q in t.subject.lower()
                    or q in t.object.lower()
                    or q in t.predicate.lower()):
                matched_nodes.add(t.subject)
                matched_nodes.add(t.object)

        # 2단계: 1홉 이웃 트리플 수집
        result_triples: list[Triple] = []
        result_nodes:   set[str]     = set(matched_nodes)
        for t in triples:
            if t.subject in matched_nodes or t.object in matched_nodes:
                result_triples.append(t)
                result_nodes.add(t.subject)
                result_nodes.add(t.object)

        nodes_out = [self._nodes[n] for n in result_nodes if n in self._nodes]
        return {
            "nodes":   nodes_out,
            "triples": [self._triple_to_dict(t) for t in result_triples],
        }

    def all_triples(self, include_archived: bool = False) -> list[Triple]:
        """전체 트리플 목록."""
        return [
            t for t in self._triples.values()
            if include_archived or t.status == TripleStatus.ACTIVE
        ]

    def stats(self) -> dict:
        """{"nodes": N, "triples": N, "active": N, "archived": N}"""
        active   = sum(1 for t in self._triples.values()
                       if t.status == TripleStatus.ACTIVE)
        archived = len(self._triples) - active
        return {
            "nodes":    len(self._nodes),
            "triples":  len(self._triples),
            "active":   active,
            "archived": archived,
        }

    def force_save(self) -> None:
        """명시적 저장 호출."""
        self._save()

    def export_json(self) -> str:
        """현재 상태를 JSON 문자열로 반환."""
        data = {
            "nodes":   self._nodes,
            "triples": [self._triple_to_dict(t) for t in self._triples.values()],
        }
        return json.dumps(data, ensure_ascii=False, indent=2)
