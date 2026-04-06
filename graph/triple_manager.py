"""graph/triple_manager.py — 트리플 CRUDA 비즈니스 로직 (F5)"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from graph.graph_db import GraphDB, Triple, TripleStatus


class TripleManager:
    """트리플 CRUDA 비즈니스 로직. GraphDB 위에서 동작."""

    def __init__(self, graph_db: GraphDB) -> None:
        self.db = graph_db

    # ── 중복 키 생성 ────────────────────────────────────────────────────────────

    @staticmethod
    def _spk(subject: str, predicate: str, object_: str) -> str:
        """동일 S+P+O 판별용 복합 키."""
        return f"{subject}|{predicate}|{object_}"

    def _find_by_spk(self, subject: str, predicate: str,
                     object_: str) -> Optional[Triple]:
        """동일 S+P+O 트리플 존재 시 반환."""
        for t in self.db.all_triples(include_archived=True):
            if (t.subject == subject
                    and t.predicate == predicate
                    and t.object == object_):
                return t
        return None

    # ── CRUDA ──────────────────────────────────────────────────────────────────

    def create(self,
               subject: str,
               subject_type: str,
               predicate: str,
               object_: str,
               object_type: str,
               ontology_version: str,
               source_record_id: Optional[str] = None,
               confidence: float = 1.0,
               note: str = "") -> Triple:
        """생성. 동일 S+P+O 존재 시 기존 반환."""
        existing = self._find_by_spk(subject, predicate, object_)
        if existing:
            return existing

        triple = Triple(
            subject=subject,
            subject_type=subject_type,
            predicate=predicate,
            object=object_,
            object_type=object_type,
            ontology_version=ontology_version,
            source_record_id=source_record_id,
            confidence=confidence,
            note=note,
        )
        self.db.add(triple)
        return triple

    def get(self, triple_id: str) -> Triple:
        """ID로 조회. 없으면 KeyError."""
        t = self.db.get(triple_id)
        if t is None:
            raise KeyError(f"트리플을 찾을 수 없습니다: {triple_id!r}")
        return t

    def search(self,
               query: str = "",
               ontology_version: Optional[str] = None,
               status: TripleStatus = TripleStatus.ACTIVE) -> dict:
        """
        검색어 기반 서브그래프 (1홉 확장).
        반환: {"nodes": [...], "triples": [...]}
        """
        include_archived = (status == TripleStatus.ARCHIVED)
        result = self.db.query(search=query, include_archived=include_archived)

        # ontology_version 필터 (지정 시)
        if ontology_version:
            filtered_ids = {
                t["id"] for t in result["triples"]
                if t.get("ontology_version") == ontology_version
            }
            result["triples"] = [t for t in result["triples"]
                                  if t["id"] in filtered_ids]

        return result

    def update(self,
               triple_id: str,
               predicate: Optional[str] = None,
               object_: Optional[str] = None,
               object_type: Optional[str] = None,
               confidence: Optional[float] = None,
               note: Optional[str] = None) -> Triple:
        """수정. updated_at 자동 갱신."""
        self.get(triple_id)   # KeyError 발생 확인
        kwargs = {}
        if predicate   is not None: kwargs["predicate"]   = predicate
        if object_     is not None: kwargs["object"]       = object_
        if object_type is not None: kwargs["object_type"]  = object_type
        if confidence  is not None: kwargs["confidence"]   = confidence
        if note        is not None: kwargs["note"]         = note
        return self.db.update(triple_id, **kwargs)

    def delete(self, triple_id: str) -> None:
        """영구 삭제."""
        self.get(triple_id)   # KeyError 발생 확인
        self.db.remove(triple_id)

    def archive(self, triple_id: str, reason: str = "") -> Triple:
        """Active → Archived. archived_at 기록."""
        triple = self.get(triple_id)
        if triple.status == TripleStatus.ARCHIVED:
            return triple
        return self.db.update(
            triple_id,
            status=TripleStatus.ARCHIVED,
            archived_at=datetime.now().isoformat(),
            note=reason if reason else triple.note,
        )

    def bulk_create(self,
                    triples: list[dict],
                    ontology_version: str,
                    source_record_id: Optional[str] = None) -> dict:
        """
        배치 생성. 중복 제외.
        반환: {"added": N, "skipped": N, "triples": [...]}
        """
        added   = 0
        skipped = 0
        results = []
        for item in triples:
            existing = self._find_by_spk(
                item["subject"], item["predicate"], item["object"]
            )
            if existing:
                skipped += 1
                results.append(existing)
                continue
            t = self.create(
                subject=item["subject"],
                subject_type=item.get("subject_type", item.get("subjectType", "")),
                predicate=item["predicate"],
                object_=item["object"],
                object_type=item.get("object_type", item.get("objectType", "")),
                ontology_version=ontology_version,
                source_record_id=source_record_id,
                confidence=item.get("confidence", 1.0),
                note=item.get("note", ""),
            )
            added += 1
            results.append(t)

        return {"added": added, "skipped": skipped, "triples": results}

    def stats(self) -> dict:
        """{"nodes": N, "triples": N, "active": N, "archived": N}"""
        return self.db.stats()
