# -*- coding: utf-8 -*-
"""core/owl_reasoner.py — OWL 추론 엔진 래퍼 (v5.0)

owlready2의 HermiT 추론기를 사용하여 OWL DL 추론을 실행합니다.
추론으로 생성된 암묵적 트리플을 rdflib Graph에 통합합니다.

owlready2 미설치 또는 Java 없는 환경에서는 graceful degradation:
  - run_reasoning() → status: "unavailable"
  - get_status()    → reasoner_available: false
"""

import json
from datetime import datetime
from pathlib import Path
from typing import Optional

# ── 경로 ──────────────────────────────────────────────────────────────────────
_ROOT        = Path(__file__).parent.parent
OWL_PATH     = _ROOT / "data" / "rdf" / "oral-history.owl"
TTL_PATH     = _ROOT / "data" / "rdf" / "oral-history.ttl"
STATUS_PATH  = _ROOT / "data" / "reasoner_status.json"


def _owlready2_available() -> bool:
    try:
        import owlready2  # noqa: F401
        return True
    except ImportError:
        return False


class OWLReasoner:
    """owlready2 HermiT 추론기 래퍼."""

    def __init__(self):
        STATUS_PATH.parent.mkdir(parents=True, exist_ok=True)

    # ── 추론 실행 ──────────────────────────────────────────────────────────────

    def run_reasoning(self) -> dict:
        """OWL DL 추론을 실행하고 암묵적 트리플 수를 반환합니다."""
        if not _owlready2_available():
            return {
                "status": "unavailable",
                "message": "owlready2 미설치. pip install owlready2 로 설치하세요.",
            }
        if not OWL_PATH.exists():
            return {
                "status": "error",
                "message": "OWL 파일 없음. 마이그레이션 시 xml 형식을 포함하세요.",
            }

        try:
            import owlready2  # type: ignore
            from rdflib import Graph

            # 추론 전 그래프 크기
            g_before = Graph()
            g_before.parse(str(TTL_PATH), format="turtle") if TTL_PATH.exists() else None
            before_count = len(g_before)

            # owlready2 로드 + sync_reasoner
            world = owlready2.World()
            onto  = world.get_ontology(OWL_PATH.resolve().as_uri()).load()
            with onto:
                owlready2.sync_reasoner_pellet(
                    infer_property_values=True,
                    infer_data_property_values=True,
                    debug=0,
                )

            # 추론 결과를 rdflib Graph로 변환
            import io
            buf = io.BytesIO()
            world.as_rdflib_graph().serialize(buf, format="turtle")
            buf.seek(0)

            g_after = Graph()
            g_after.parse(buf, format="turtle")
            after_count = len(g_after)
            new_triples = max(0, after_count - before_count)

            # 추론 결과 TTL 저장
            inferred_path = _ROOT / "data" / "rdf" / "oral-history-inferred.ttl"
            g_after.serialize(str(inferred_path), format="turtle", encoding="utf-8")

            status = {
                "status":      "done",
                "run_at":      datetime.now().isoformat(),
                "before":      before_count,
                "after":       after_count,
                "new_triples": new_triples,
                "inferred_file": inferred_path.name,
            }
            self._save_status(status)
            return status

        except Exception as e:
            status = {
                "status":  "error",
                "message": str(e),
                "run_at":  datetime.now().isoformat(),
            }
            self._save_status(status)
            return status

    # ── 상태 조회 ──────────────────────────────────────────────────────────────

    def get_status(self) -> dict:
        """추론 엔진 가용 여부와 마지막 실행 결과를 반환합니다."""
        available = _owlready2_available()
        last = self._load_status()
        return {
            "reasoner_available": available,
            "owl_file_exists":    OWL_PATH.exists(),
            "last_run": last,
        }

    # ── 상태 파일 I/O ─────────────────────────────────────────────────────────

    def _save_status(self, data: dict):
        STATUS_PATH.write_text(
            json.dumps(data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def _load_status(self) -> Optional[dict]:
        if STATUS_PATH.exists():
            try:
                return json.loads(STATUS_PATH.read_text(encoding="utf-8"))
            except Exception:
                pass
        return None
