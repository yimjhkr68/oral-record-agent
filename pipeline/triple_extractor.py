"""pipeline/triple_extractor.py — 확정 온톨로지 기반 트리플 추출 (F4)"""

from __future__ import annotations

import json
from typing import Optional

import anthropic

from ontology.ontology_manager import OntologyManager, OntologyStatus, OntologyVersion
from graph.triple_manager import TripleManager


class TripleExtractor:
    """
    확정된 온톨로지 버전 기반으로 구술자료에서 트리플 추출.
    Confirmed 버전의 클래스/속성을 AI 프롬프트에 동적 주입.
    """

    def __init__(self,
                 ontology_manager: OntologyManager,
                 triple_manager: TripleManager) -> None:
        self.om     = ontology_manager
        self.tm     = triple_manager
        self.client = anthropic.Anthropic()

    _MAX_CHARS = 8000  # AI 컨텍스트 초과 방지

    def _call_ai(self, content: str, ontology_version_id: str,
                 source_record_id: Optional[str]) -> tuple[list[dict], str]:
        """공통: 온톨로지 검증 + AI 호출 + JSON 파싱.
        반환: (triples_data, ontology_version_id)"""
        version = self.om.get(ontology_version_id)
        if version.status != OntologyStatus.CONFIRMED:
            raise ValueError(
                f"Confirmed 상태의 온톨로지만 사용 가능합니다. "
                f"현재 상태: {version.status} (version_id={ontology_version_id!r})"
            )

        # 텍스트 길이 제한
        if len(content) > self._MAX_CHARS:
            import logging
            logging.getLogger(__name__).warning(
                "텍스트 %d자 → %d자로 잘림 (source: %s)",
                len(content), self._MAX_CHARS, source_record_id or "-",
            )
            content = content[: self._MAX_CHARS]

        system_prompt = self._build_system_prompt(version)
        try:
            response = self.client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=4096,
                system=system_prompt,
                messages=[{"role": "user", "content": content}],
            )
        except Exception as e:
            raise RuntimeError(f"AI API 호출 실패: {e}") from e

        raw = response.content[0].text.strip()
        # 코드 펜스 제거 + JSON 객체 경계 슬라이싱 (preamble/postamble 방어)
        clean = raw.replace("```json", "").replace("```", "").strip()
        start = clean.find('{')
        end   = clean.rfind('}')
        if start != -1 and end != -1 and end > start:
            clean = clean[start:end + 1]
        try:
            parsed = json.loads(clean)
        except json.JSONDecodeError as e:
            raise RuntimeError(
                f"AI 응답 JSON 파싱 실패 — 원문: {clean[:200]!r}"
            ) from e
        return parsed.get("triples", []), ontology_version_id

    def extract_preview(self,
                        content: str,
                        ontology_version_id: str,
                        source_record_id: Optional[str] = None) -> dict:
        """AI 추출만 수행, DB 저장 없이 반환 (검토 전 미리보기).
        반환: {"triples": [...], "count": N, "source_record_id": "..."}
        """
        triples_data, version_id = self._call_ai(
            content, ontology_version_id, source_record_id
        )
        # source_record_id · ontology_version 주입
        for t in triples_data:
            t["ontology_version"] = version_id
            t["source_record_id"] = source_record_id or ""
        return {
            "triples": triples_data,
            "count": len(triples_data),
            "source_record_id": source_record_id or "",
        }

    def extract(self,
                content: str,
                ontology_version_id: str,
                source_record_id: Optional[str] = None) -> dict:
        """AI 추출 + DB 즉시 저장 (레거시용).
        반환: {"added": N, "skipped": N, "triples": [...]}
        """
        triples_data, version_id = self._call_ai(
            content, ontology_version_id, source_record_id
        )
        return self.tm.bulk_create(
            triples=triples_data,
            ontology_version=version_id,
            source_record_id=source_record_id,
        )

    def _build_system_prompt(self, ontology: OntologyVersion) -> str:
        """확정 온톨로지 기반 동적 시스템 프롬프트 생성."""
        classes_str = "\n".join(
            f"- {c.name} ({c.label_ko}): {c.description}"
            for c in ontology.classes
        )
        predicates_str = "\n".join(
            f"- {p.name}: {p.description} "
            f"[도메인: {p.domain} → 범위: {p.range_}]"
            for p in ontology.predicates
        )
        return f"""당신은 구술기록 전문 온톨로지 파서입니다.
온톨로지 버전: {ontology.version_id}

사용 가능한 클래스:
{classes_str}

사용 가능한 속성:
{predicates_str}

반드시 다음 JSON 형식으로만 응답하세요:
{{
  "triples": [
    {{
      "subject": "주어",
      "subjectType": "클래스명",
      "predicate": "속성명",
      "object": "목적어",
      "objectType": "클래스명",
      "confidence": 0.0
    }}
  ]
}}"""
