"""ontology/ontology_manager.py — 온톨로지 CRUDA + AI 생성 + 버전 확정 (F1·F2·F3)"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional

import json

import anthropic


# ── 데이터 모델 ────────────────────────────────────────────────────────────────

class OntologyStatus(str, Enum):
    DRAFT     = "draft"      # 편집 가능
    CONFIRMED = "confirmed"  # 확정 — 수정 불가, 트리플 생성에 사용
    ARCHIVED  = "archived"   # 보관 — 조회만 가능


@dataclass
class OntologyClass:
    name:        str
    label_ko:    str
    color:       str
    description: str = ""
    examples:    list[str] = field(default_factory=list)


@dataclass
class OntologyPredicate:
    name:        str
    domain:      list[str] = field(default_factory=list)
    range_:      list[str] = field(default_factory=list)
    description: str = ""


@dataclass
class OntologyVersion:
    version_id:   str
    status:       OntologyStatus = OntologyStatus.DRAFT
    classes:      list[OntologyClass]     = field(default_factory=list)
    predicates:   list[OntologyPredicate] = field(default_factory=list)
    created_at:   str = field(default_factory=lambda: datetime.now().isoformat())
    confirmed_at: Optional[str] = None
    archived_at:  Optional[str] = None
    description:  str = ""
    based_on:     Optional[str] = None   # 이전 버전 ID


# ── OntologyManager ────────────────────────────────────────────────────────────

class OntologyManager:
    """온톨로지 CRUDA + AI 자동 생성 + 버전 확정."""

    def __init__(self, store=None) -> None:
        from ontology.ontology_store import OntologyStore
        self._store: OntologyStore = store or OntologyStore()
        # 인메모리 캐시: version_id → OntologyVersion
        self._cache: dict[str, OntologyVersion] = {}
        self._load_all()

    def _load_all(self) -> None:
        for v in self._store.load_all():
            self._cache[v.version_id] = v

    # ── CRUDA ──────────────────────────────────────────────────────────────────

    def create(self, version_id: str, description: str = "") -> OntologyVersion:
        """새 Draft 생성. version_id 중복 시 ValueError."""
        if version_id in self._cache:
            raise ValueError(f"이미 존재하는 version_id: {version_id!r}")
        version = OntologyVersion(version_id=version_id, description=description)
        self._cache[version_id] = version
        self._store.save_draft(version)
        return version

    def get(self, version_id: str) -> OntologyVersion:
        """버전 조회. 없으면 KeyError."""
        if version_id not in self._cache:
            raise KeyError(f"온톨로지 버전을 찾을 수 없습니다: {version_id!r}")
        return self._cache[version_id]

    def list_all(self) -> list[OntologyVersion]:
        """전체 버전 목록, 최신순."""
        return sorted(
            self._cache.values(),
            key=lambda v: v.created_at,
            reverse=True,
        )

    def update(self,
               version_id: str,
               classes: list[OntologyClass] | None = None,
               predicates: list[OntologyPredicate] | None = None,
               description: str | None = None) -> OntologyVersion:
        """Draft 상태만 수정 가능. 그 외 PermissionError."""
        version = self.get(version_id)
        if version.status != OntologyStatus.DRAFT:
            raise PermissionError(
                f"Draft 상태만 수정 가능합니다. 현재 상태: {version.status}"
            )
        if classes is not None:
            version.classes = classes
        if predicates is not None:
            version.predicates = predicates
        if description is not None:
            version.description = description
        self._store.save_draft(version)
        return version

    def delete(self, version_id: str) -> None:
        """Draft 상태만 삭제 가능. 그 외 PermissionError."""
        version = self.get(version_id)
        if version.status != OntologyStatus.DRAFT:
            raise PermissionError(
                f"Draft 상태만 삭제 가능합니다. 현재 상태: {version.status}"
            )
        self._store.delete_draft(version_id)
        del self._cache[version_id]

    def archive(self, version_id: str) -> OntologyVersion:
        """Confirmed → Archived. 비가역."""
        version = self.get(version_id)
        if version.status != OntologyStatus.CONFIRMED:
            raise PermissionError(
                f"Confirmed 상태만 아카이브 가능합니다. 현재 상태: {version.status}"
            )
        version.status      = OntologyStatus.ARCHIVED
        version.archived_at = datetime.now().isoformat()
        self._store.save_confirmed(version)
        return version

    # ── AI 자동 생성 (F2) ──────────────────────────────────────────────────────

    def generate_from_sample(self,
                              sample_text: str,
                              base_version_id: str | None = None) -> OntologyVersion:
        """
        구술 샘플 → AI 분석 → Draft OntologyVersion 생성 + 파일 저장.
        base_version_id 있으면 해당 버전 기반으로 확장 제안.
        """
        base_ontology_json = ""
        if base_version_id:
            try:
                base = self.get(base_version_id)
                import dataclasses
                base_ontology_json = json.dumps(
                    dataclasses.asdict(base), ensure_ascii=False, indent=2
                )
            except KeyError:
                pass

        system_prompt = f"""당신은 구술기록 아카이브 전문가다.
제공된 구술 텍스트 샘플을 분석하여 지식그래프 온톨로지를 제안해라.

기존 온톨로지({base_ontology_json if base_ontology_json else "없음"})가 있으면 그것을 기반으로 확장 제안해라.
텍스트에서 실제로 등장하는 개념만 포함해라.

반드시 다음 JSON 형식으로만 응답해:
{{
  "classes": [
    {{
      "name": "영문 PascalCase",
      "label_ko": "한국어 레이블",
      "color": "#hex",
      "description": "정의",
      "examples": ["예시1", "예시2"]
    }}
  ],
  "predicates": [
    {{
      "name": "속성명 (한국어 동사형)",
      "domain": ["허용 주어 클래스"],
      "range_": ["허용 목적어 클래스"],
      "description": "의미 설명"
    }}
  ]
}}"""

        client = anthropic.Anthropic()
        try:
            response = client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=4096,
                system=system_prompt,
                messages=[{"role": "user", "content": sample_text}],
            )
        except Exception as e:
            raise RuntimeError(f"AI API 호출 실패: {e}") from e

        raw = response.content[0].text.strip()
        # JSON 블록만 추출
        if "```" in raw:
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as e:
            raise RuntimeError(
                f"AI 응답 JSON 파싱 실패 — 원문: {raw[:200]!r}"
            ) from e

        classes = [OntologyClass(**c) for c in parsed.get("classes", [])]
        predicates = [OntologyPredicate(**p) for p in parsed.get("predicates", [])]

        # 새 버전 ID 자동 생성 (타임스탬프 기반)
        ts = datetime.now().strftime("%Y%m%d%H%M%S")
        version_id = f"draft-{ts}"

        version = OntologyVersion(
            version_id=version_id,
            classes=classes,
            predicates=predicates,
            based_on=base_version_id,
            description=f"AI 자동 생성 (샘플 기반{', 기반: ' + base_version_id if base_version_id else ''})",
        )
        self._cache[version_id] = version
        self._store.save_draft(version)
        return version

    # ── 버전 확정 (F3) ──────────────────────────────────────────────────────────

    def confirm(self, version_id: str) -> OntologyVersion:
        """
        Draft → Confirmed. 비가역.
        data/ontologies/confirmed/{version_id}.json 에 복사본 저장.
        draft 파일은 OntologyStore.save_confirmed() 에서 자동 삭제.
        """
        version = self.get(version_id)
        if version.status != OntologyStatus.DRAFT:
            raise PermissionError(
                f"Draft 상태만 확정 가능합니다. 현재 상태: {version.status}"
            )
        version.status       = OntologyStatus.CONFIRMED
        version.confirmed_at = datetime.now().isoformat()
        self._store.save_confirmed(version)
        return version

    def get_confirmed_versions(self) -> list[OntologyVersion]:
        """Confirmed 상태 버전만 반환."""
        return [v for v in self._cache.values()
                if v.status == OntologyStatus.CONFIRMED]

    def get_latest_confirmed(self) -> Optional[OntologyVersion]:
        """가장 최근 Confirmed 버전. 없으면 None."""
        confirmed = self.get_confirmed_versions()
        if not confirmed:
            return None
        return max(confirmed, key=lambda v: v.confirmed_at or "")
