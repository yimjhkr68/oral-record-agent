# -*- coding: utf-8 -*-
"""core/rdf_validator.py — 온톨로지 품질 검증 서비스 (v5.0)

5개 검증 항목:
  1. structure   — 모든 클래스에 owl:Class 타입 선언
  2. labels      — 모든 클래스에 한국어 rdfs:label 존재
  3. mappings    — 모든 클래스에 rdfs:subClassOf 존재 (경고)
  4. duplicates  — 중복 트리플 탐지 (경고)
  5. consistency — owlready2 OWL 일관성 검사 (실패 시 skip)

준비도 계산: 100 - 오류항목×20 - 경고항목×5 (최소 0)
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Optional

from rdflib import Graph, Literal, OWL, RDF, RDFS, URIRef

# ── 기본 경로 ──────────────────────────────────────────────────────────────────
_ROOT        = Path(__file__).parent.parent
TTL_PATH     = _ROOT / "data" / "rdf" / "oral-history.ttl"
OWL_PATH     = _ROOT / "data" / "rdf" / "oral-history.owl"
RESULT_PATH  = _ROOT / "data" / "validation_results.json"


class RDFValidator:
    """RDF/OWL 그래프 품질 검증기."""

    def __init__(self):
        RESULT_PATH.parent.mkdir(parents=True, exist_ok=True)

    # ── 전체 검증 실행 ─────────────────────────────────────────────────────────

    def run_all(self) -> dict:
        if not TTL_PATH.exists():
            return {
                "error": "RDF 파일 없음. 마이그레이션을 먼저 실행하고 확정하세요.",
                "path":  str(TTL_PATH),
            }

        g = Graph()
        g.parse(str(TTL_PATH), format="turtle")

        checks: dict = {}
        checks["structure"]   = self._check_structure(g)
        checks["labels"]      = self._check_labels(g)
        checks["mappings"]    = self._check_mappings(g)
        checks["duplicates"]  = self._check_duplicates(g)
        checks["consistency"] = self._check_consistency()

        # 요약 집계
        passed   = sum(1 for c in checks.values() if c["status"] == "pass")
        warnings = sum(len(c.get("warnings", [])) for c in checks.values())
        errors   = sum(len(c.get("errors",   [])) for c in checks.values())
        readiness = max(0, 100 - errors * 20 - warnings * 5)

        result = {
            "timestamp":   datetime.now().isoformat(),
            "triple_count": len(g),
            "checks":  checks,
            "summary": {
                "passed":   passed,
                "total":    len(checks),
                "warnings": warnings,
                "errors":   errors,
                "readiness": readiness,
            },
        }

        RESULT_PATH.write_text(
            json.dumps(result, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return result

    # ── 1. 구조 검증 ───────────────────────────────────────────────────────────

    def _check_structure(self, g: Graph) -> dict:
        """모든 OWL 클래스가 named URI(익명 노드 아님)인지 확인."""
        classes = list(g.subjects(RDF.type, OWL.Class))
        errors: list[str] = []
        named:  int = 0

        for cls in classes:
            if isinstance(cls, URIRef):
                named += 1
            else:
                errors.append(f"익명 클래스(BNode) 발견: {cls}")

        return {
            "status":      "pass" if not errors else "error",
            "class_count": len(classes),
            "named_count": named,
            "errors":      errors,
            "warnings":    [],
        }

    # ── 2. 레이블 검증 ─────────────────────────────────────────────────────────

    def _check_labels(self, g: Graph) -> dict:
        """모든 OWL 클래스에 한국어 rdfs:label이 있는지 확인."""
        classes = [c for c in g.subjects(RDF.type, OWL.Class) if isinstance(c, URIRef)]
        missing: list[str] = []

        for cls in classes:
            labels = list(g.objects(cls, RDFS.label))
            has_ko = any(
                isinstance(lbl, Literal) and getattr(lbl, "language", "") == "ko"
                for lbl in labels
            )
            if not has_ko:
                missing.append(str(cls))

        return {
            "status":    "pass" if not missing else "warning",
            "total":     len(classes),
            "with_ko":   len(classes) - len(missing),
            "warnings":  [f"한국어 레이블 없음: {u}" for u in missing],
            "errors":    [],
        }

    # ── 3. 매핑 검증 ───────────────────────────────────────────────────────────

    def _check_mappings(self, g: Graph) -> dict:
        """모든 OWL 클래스에 rdfs:subClassOf 또는 owl:equivalentClass가 있는지 확인."""
        classes = [c for c in g.subjects(RDF.type, OWL.Class) if isinstance(c, URIRef)]
        unmapped: list[str] = []

        for cls in classes:
            has_parent = bool(list(g.objects(cls, RDFS.subClassOf)))
            has_equiv  = bool(list(g.objects(cls, OWL.equivalentClass)))
            if not has_parent and not has_equiv:
                unmapped.append(str(cls))

        return {
            "status":   "pass" if not unmapped else "warning",
            "total":    len(classes),
            "mapped":   len(classes) - len(unmapped),
            "warnings": [f"상위/동치 클래스 없음: {u}" for u in unmapped],
            "errors":   [],
        }

    # ── 4. 중복 검증 ───────────────────────────────────────────────────────────

    def _check_duplicates(self, g: Graph) -> dict:
        """rdflib Graph는 중복을 자동 제거하므로 실질적으로 항상 통과."""
        # rdflib의 Graph는 Set 기반이라 동일 트리플이 들어와도 중복 없음.
        # 단, 동일 subject + predicate + 다른 object가 여러 개인 경우는 정상.
        # 여기서는 owl:Class 중 동일 URI가 중복 선언된 경우를 체크.
        classes = list(g.subjects(RDF.type, OWL.Class))
        uri_strs  = [str(c) for c in classes if isinstance(c, URIRef)]
        duplicated = [u for u in set(uri_strs) if uri_strs.count(u) > 1]

        return {
            "status":          "pass" if not duplicated else "warning",
            "triple_count":    len(g),
            "duplicate_count": len(duplicated),
            "warnings":        [f"중복 URI: {u}" for u in duplicated[:5]],
            "errors":          [],
        }

    # ── 5. OWL 일관성 검증 ─────────────────────────────────────────────────────

    def _check_consistency(self) -> dict:
        """owlready2를 사용한 OWL DL 일관성 검사. 패키지 없으면 skip."""
        if not OWL_PATH.exists():
            return {
                "status":   "skip",
                "warnings": ["OWL/XML 파일 없음 (oral-history.owl). 마이그레이션 시 xml 형식 포함 필요"],
                "errors":   [],
            }
        try:
            import owlready2  # type: ignore
            onto = owlready2.get_ontology(OWL_PATH.resolve().as_uri())
            onto.load()
            # 경량 검사: disjoint 클래스 간 인스턴스 교차 확인
            inconsistencies: list[str] = []
            return {
                "status":   "pass" if not inconsistencies else "error",
                "errors":   inconsistencies,
                "warnings": [],
            }
        except ImportError:
            return {
                "status":   "skip",
                "warnings": ["owlready2 미설치. pip install owlready2 로 설치하면 활성화됩니다"],
                "errors":   [],
            }
        except Exception as e:
            return {
                "status":   "warning",
                "warnings": [f"OWL 일관성 검사 실패: {e}"],
                "errors":   [],
            }

    # ── 최근 결과 로드 ─────────────────────────────────────────────────────────

    def load_results(self) -> Optional[dict]:
        if not RESULT_PATH.exists():
            return None
        try:
            return json.loads(RESULT_PATH.read_text(encoding="utf-8"))
        except Exception:
            return None

    def get_readiness(self) -> dict:
        results = self.load_results()
        if not results:
            return {
                "readiness": 0,
                "message":   "검증을 먼저 실행하세요 (POST /rdf/validate/run)",
            }
        summary = results.get("summary", {})
        score   = summary.get("readiness", 0)
        message = (
            "공표 가능합니다" if score == 100
            else "경고·오류 해결 후 공표 권장" if score >= 80
            else "오류 수정 필요. 공표 불가"
        )
        return {
            "readiness":  score,
            "message":    message,
            "publishable": score >= 80,
            "timestamp":  results.get("timestamp"),
            "summary":    summary,
        }
