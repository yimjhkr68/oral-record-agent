"""ontology/ontology_importer.py — JSON / CSV 온톨로지 임포트"""

from __future__ import annotations

import csv
import io
import time

from ontology.ontology_manager import (
    OntologyStatus, OntologyVersion,
    _safe_class, _safe_predicate,
)


class OntologyImporter:
    """JSON 또는 CSV 에서 OntologyVersion(Draft) 을 생성한다."""

    # ── JSON 임포트 ────────────────────────────────────────────────────────────

    def from_json(self, data: dict, version_id: str = "") -> OntologyVersion:
        """
        내보내기 JSON 또는 단일 버전 JSON 파싱.

        지원 포맷:
          A. export_type="ontologies" → items[0] 사용
          B. 단일 버전 JSON (version_id, classes, predicates 포함)
        """
        if data.get("export_type") == "ontologies":
            items = data.get("items", [])
            if not items:
                raise ValueError("임포트할 온톨로지가 없습니다.")
            source = items[0]
        else:
            source = data

        classes = [
            c for c in (
                _safe_class({
                    "name":         c.get("name", ""),
                    "label_ko":     c.get("label_ko", ""),
                    "color":        c.get("color", "#888888"),
                    "description":  c.get("description", ""),
                    "examples":     c.get("examples", []),
                    "standard_tag": c.get("standard_tag", ""),
                })
                for c in source.get("classes", [])
                if isinstance(c, dict)
            )
            if c is not None
        ]
        predicates = [
            p for p in (
                _safe_predicate({
                    "name":         p.get("name", ""),
                    "domain":       p.get("domain", []),
                    "range_":       p.get("range_", []),
                    "description":  p.get("description", ""),
                    "standard_tag": p.get("standard_tag", ""),
                })
                for p in source.get("predicates", [])
                if isinstance(p, dict)
            )
            if p is not None
        ]

        new_id = version_id.strip() or self._generate_id("imported")
        return OntologyVersion(
            version_id  = new_id,
            status      = OntologyStatus.DRAFT,
            classes     = classes,
            predicates  = predicates,
            description = f"임포트: {source.get('version_id', '')}",
        )

    # ── CSV 임포트 ────────────────────────────────────────────────────────────

    def from_csv(
        self,
        csv_text: str,
        csv_type: str,          # "classes" | "predicates"
        version_id: str = "",
    ) -> OntologyVersion:
        """
        CSV 파싱.
          csv_type "classes"    → name, label_ko, color, description, examples
          csv_type "predicates" → name, domain, range_, description
        """
        reader = csv.DictReader(io.StringIO(csv_text))
        new_id = version_id.strip() or self._generate_id("csv-import")

        if csv_type == "classes":
            classes = []
            for row in reader:
                c = _safe_class({
                    "name":        row.get("name", "").strip(),
                    "label_ko":    row.get("label_ko", "").strip(),
                    "color":       row.get("color", "#888888").strip(),
                    "description": row.get("description", "").strip(),
                    "examples":    [
                        e.strip()
                        for e in row.get("examples", "").split(",")
                        if e.strip()
                    ],
                })
                if c:
                    classes.append(c)
            return OntologyVersion(
                version_id  = new_id,
                status      = OntologyStatus.DRAFT,
                classes     = classes,
                predicates  = [],
                description = "CSV 클래스 임포트",
            )

        elif csv_type == "predicates":
            predicates = []
            for row in reader:
                p = _safe_predicate({
                    "name":        row.get("name", "").strip(),
                    "domain":      [
                        d.strip()
                        for d in row.get("domain", "").split(",")
                        if d.strip()
                    ],
                    "range_":      [
                        r.strip()
                        for r in row.get("range_", "").split(",")
                        if r.strip()
                    ],
                    "description": row.get("description", "").strip(),
                })
                if p:
                    predicates.append(p)
            return OntologyVersion(
                version_id  = new_id,
                status      = OntologyStatus.DRAFT,
                classes     = [],
                predicates  = predicates,
                description = "CSV 속성 임포트",
            )

        else:
            raise ValueError(f"알 수 없는 csv_type: {csv_type!r}. 'classes' 또는 'predicates' 중 하나여야 합니다.")

    # ── 헬퍼 ─────────────────────────────────────────────────────────────────

    @staticmethod
    def _generate_id(prefix: str) -> str:
        return f"{prefix}-{int(time.time())}"
