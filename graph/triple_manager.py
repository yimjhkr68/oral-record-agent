"""graph/triple_manager.py — 트리플 CRUDA 비즈니스 로직 (F5)"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Optional

from graph.graph_db import (
    GraphDB, Triple, TripleStatus,
    EXTRACTION_AUTO, EXTRACTION_MANUAL, EXTRACTION_EDITED,
)


class TripleManager:
    """트리플 CRUDA 비즈니스 로직. GraphDB 위에서 동작."""

    def __init__(self, graph_db: GraphDB) -> None:
        self.db = graph_db

    # ── 엔티티 표기 정규화 ──────────────────────────────────────────────────────

    @staticmethod
    def _normalize_entity(name: str) -> str:
        """동일 엔티티의 다양한 표기를 통일.

        - 중점(·/・) → 마침표(.)
        - 연속 공백 → 단일 공백
        - '4 . 3' / '4·3' 등 → '4.3'
        """
        name = name.replace('·', '.').replace('・', '.')
        name = re.sub(r'4\s*\.\s*3', '4.3', name)
        name = re.sub(r'\s+', ' ', name).strip()
        return name

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
               note: str = "",
               created_by: str = "system",
               extraction_method: str = EXTRACTION_AUTO) -> Triple:
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
            created_by=created_by,
            extraction_method=extraction_method,
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
               subject: Optional[str] = None,
               subject_type: Optional[str] = None,
               predicate: Optional[str] = None,
               object_: Optional[str] = None,
               object_type: Optional[str] = None,
               confidence: Optional[float] = None,
               note: Optional[str] = None,
               updated_by: Optional[str] = None) -> Triple:
        """수정. updated_at 자동 갱신. subject/object 변경 시 노드 재계산."""
        self.get(triple_id)   # KeyError 발생 확인
        kwargs: dict = {}
        if subject     is not None: kwargs["subject"]            = subject
        if subject_type is not None: kwargs["subject_type"]      = subject_type
        if predicate   is not None: kwargs["predicate"]          = predicate
        if object_     is not None: kwargs["object"]             = object_
        if object_type is not None: kwargs["object_type"]        = object_type
        if confidence  is not None: kwargs["confidence"]         = confidence
        if note        is not None: kwargs["note"]               = note
        if updated_by  is not None: kwargs["updated_by"]         = updated_by
        if updated_by  is not None: kwargs["extraction_method"]  = EXTRACTION_EDITED
        return self.db.update(triple_id, **kwargs)

    def list_triples(self,
                     ontology_version: Optional[str] = None,
                     source_record_id: Optional[str] = None,
                     created_by: Optional[str] = None,
                     date_from: Optional[str] = None,
                     date_to: Optional[str] = None,
                     status: Optional[str] = None) -> list[Triple]:
        """
        관리자용 트리플 목록 조회 (필터 지원).
        status: "active" | "archived" | None(전체)
        date_from / date_to: ISO 날짜 prefix (예: "2026-01-01")
        """
        include_archived = status != "active" if status else True
        triples = self.db.all_triples(include_archived=include_archived)

        # status 필터
        if status and status not in ("all", ""):
            try:
                st = TripleStatus(status)
                triples = [t for t in triples if t.status == st]
            except ValueError:
                pass

        if ontology_version:
            triples = [t for t in triples
                       if t.ontology_version == ontology_version]
        if source_record_id:
            triples = [t for t in triples
                       if t.source_record_id == source_record_id]
        if created_by:
            triples = [t for t in triples if t.created_by == created_by]
        if date_from:
            triples = [t for t in triples if t.created_at >= date_from]
        if date_to:
            # date_to 는 "2026-12-31" 형식 — 해당 날짜까지 포함
            triples = [t for t in triples
                       if t.created_at[:10] <= date_to]

        triples.sort(key=lambda t: t.created_at, reverse=True)
        return triples

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
                    source_record_id: Optional[str] = None,
                    created_by: str = "system",
                    extraction_method: str = EXTRACTION_AUTO) -> dict:
        """
        배치 생성. 중복 제외.
        반환: {"added": N, "skipped": N, "triples": [...]}
        """
        added   = 0
        skipped = 0
        results = []
        for item in triples:
            subj = self._normalize_entity(item["subject"])
            obj  = self._normalize_entity(item["object"])
            existing = self._find_by_spk(subj, item["predicate"], obj)
            if existing:
                skipped += 1
                results.append(existing)
                continue
            t = self.create(
                subject=subj,
                subject_type=item.get("subject_type", item.get("subjectType", "")),
                predicate=item["predicate"],
                object_=obj,
                object_type=item.get("object_type", item.get("objectType", "")),
                ontology_version=ontology_version,
                source_record_id=source_record_id,
                confidence=item.get("confidence", 1.0),
                note=item.get("note", ""),
                created_by=item.get("created_by", created_by),
                extraction_method=item.get("extraction_method", extraction_method),
            )
            added += 1
            results.append(t)

        return {"added": added, "skipped": skipped, "triples": results}

    def get_categories(self,
                       ontology_version: Optional[str] = None,
                       status: Optional[str] = "active") -> dict:
        """
        클래스별 트리플 범주화.
        반환: {
            "categories": [
                {"name": "Person", "count": N, "triple_ids": [...]}
            ],
            "total_triples": N
        }
        """
        triples = self.list_triples(
            ontology_version=ontology_version,
            status=status,
        )

        # class_name → set of triple_ids
        cat_map: dict[str, set[str]] = {}
        for t in triples:
            for cls in (t.subject_type, t.object_type):
                if cls:
                    cat_map.setdefault(cls, set()).add(t.id)

        categories = [
            {"name": name, "count": len(ids), "triple_ids": sorted(ids)}
            for name, ids in sorted(cat_map.items(), key=lambda x: -len(x[1]))
        ]
        return {"categories": categories, "total_triples": len(triples)}

    def search_with_categories(self,
                                query: str = "",
                                ontology_version: Optional[str] = None,
                                status: str = "active") -> dict:
        """
        검색어 기반 1홉 서브그래프 + 결과 범주 정보.
        반환: {"triples": [...], "nodes": [...], "categories": [...], "total": N}
        """
        try:
            triple_status = TripleStatus(status)
        except ValueError:
            triple_status = TripleStatus.ACTIVE
        include_archived = (triple_status == TripleStatus.ARCHIVED)

        graph = self.db.query(search=query, include_archived=include_archived)

        # ontology_version 필터
        triples = graph["triples"]
        if ontology_version:
            triples = [t for t in triples
                       if t.get("ontology_version") == ontology_version]

        # 범주 계산 (dict 리스트 기준)
        cat_map: dict[str, set[str]] = {}
        for t in triples:
            for cls in (t.get("subject_type", ""), t.get("object_type", "")):
                if cls:
                    cat_map.setdefault(cls, set()).add(t["id"])

        categories = [
            {"name": name, "count": len(ids), "triple_ids": sorted(ids)}
            for name, ids in sorted(cat_map.items(), key=lambda x: -len(x[1]))
        ]
        return {
            "query": query,
            "triples": triples,
            "nodes": graph["nodes"],
            "categories": categories,
            "total": len(triples),
        }

    def stats(self) -> dict:
        """{"nodes": N, "triples": N, "active": N, "archived": N}"""
        return self.db.stats()
