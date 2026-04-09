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
    note:        str = ""


@dataclass
class OntologyPredicate:
    name:        str
    domain:      list[str] = field(default_factory=list)
    range_:      list[str] = field(default_factory=list)
    description: str = ""
    note:        str = ""


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
        from core.history_store import HistoryStore
        self._store: OntologyStore = store or OntologyStore()
        self._history: HistoryStore = HistoryStore()
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
        try:
            self._history.record_ontology_event(
                event_type="created",
                version_id=version_id,
                detail=f"Draft 생성{': ' + description if description else ''}",
            )
        except Exception:
            pass
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
        import dataclasses
        version = self.get(version_id)
        if version.status != OntologyStatus.DRAFT:
            raise PermissionError(
                f"Draft 상태만 수정 가능합니다. 현재 상태: {version.status}"
            )
        before = dataclasses.asdict(version)
        if classes is not None:
            version.classes = classes
        if predicates is not None:
            version.predicates = predicates
        if description is not None:
            version.description = description
        self._store.save_draft(version)
        try:
            changes = []
            if classes is not None:
                changes.append(f"클래스 {len(classes)}개")
            if predicates is not None:
                changes.append(f"속성 {len(predicates)}개")
            self._history.record_ontology_event(
                event_type="updated",
                version_id=version_id,
                detail="수정: " + ", ".join(changes) if changes else "수정",
                before=before,
                after=dataclasses.asdict(version),
            )
        except Exception:
            pass
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
        try:
            self._history.record_ontology_event(
                event_type="deleted",
                version_id=version_id,
                detail="Draft 삭제",
            )
        except Exception:
            pass

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
        try:
            self._history.record_ontology_event(
                event_type="archived",
                version_id=version_id,
                detail="아카이브 처리",
            )
        except Exception:
            pass
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

        _cls_fields  = {"name", "label_ko", "color", "description", "examples", "note"}
        _pred_fields = {"name", "domain", "range_", "description", "note"}
        classes = [
            OntologyClass(**{k: v for k, v in c.items() if k in _cls_fields})
            for c in parsed.get("classes", [])
        ]
        predicates = [
            OntologyPredicate(**{k: v for k, v in p.items() if k in _pred_fields})
            for p in parsed.get("predicates", [])
        ]

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
        try:
            self._history.record_ontology_event(
                event_type="generated",
                version_id=version_id,
                detail=(
                    f"샘플 텍스트 {len(sample_text)}자 기반 AI 생성"
                    + (f" (기반: {base_version_id})" if base_version_id else "")
                ),
            )
        except Exception:
            pass
        return version

    # ── Draft 종합 병합 ────────────────────────────────────────────────────────

    def merge_drafts(self,
                     version_ids: list[str],
                     new_version_id: str) -> OntologyVersion:
        """
        지정된 Draft 버전들의 클래스/속성을 수집 → AI로 중복 제거 + 정리 → 새 Draft 저장.
        Draft/Confirmed/Archived 모두 병합 소스로 사용 가능.
        new_version_id 중복 시 ValueError.
        """
        if new_version_id in self._cache:
            raise ValueError(f"이미 존재하는 version_id: {new_version_id!r}")
        if not version_ids:
            raise ValueError("병합할 버전을 1개 이상 지정해야 합니다.")

        # 소스 버전들 수집
        import dataclasses
        sources = []
        for vid in version_ids:
            v = self.get(vid)  # KeyError면 그대로 전파
            sources.append(dataclasses.asdict(v))

        sources_json = json.dumps(sources, ensure_ascii=False, indent=2)

        system_prompt = f"""당신은 구술기록 아카이브 온톨로지 전문가다.
아래에 여러 온톨로지 버전 초안(Draft)이 주어진다.
이 초안들을 분석하여 중복을 제거하고, 의미가 유사한 클래스/속성은 통합하여
하나의 완성도 높은 온톨로지를 만들어라.

원칙:
- 클래스 name 은 영문 PascalCase
- 속성 name 은 한국어 동사형
- 초안에 없는 새 항목은 추가하지 말 것
- 의미 중복 항목은 더 구체적인 쪽을 살리고 나머지 제거

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
}}

병합 대상 초안들:
{sources_json}"""

        client = anthropic.Anthropic()
        try:
            response = client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=4096,
                messages=[{"role": "user", "content": system_prompt}],
            )
        except Exception as e:
            raise RuntimeError(f"AI API 호출 실패: {e}") from e

        raw = response.content[0].text.strip()
        if "```" in raw:
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"AI 응답 JSON 파싱 실패 — 원문: {raw[:200]!r}") from e

        _cls_fields  = {"name", "label_ko", "color", "description", "examples", "note"}
        _pred_fields = {"name", "domain", "range_", "description", "note"}
        classes = [
            OntologyClass(**{k: v for k, v in c.items() if k in _cls_fields})
            for c in parsed.get("classes", [])
        ]
        predicates = [
            OntologyPredicate(**{k: v for k, v in p.items() if k in _pred_fields})
            for p in parsed.get("predicates", [])
        ]

        version = OntologyVersion(
            version_id=new_version_id,
            classes=classes,
            predicates=predicates,
            description=f"AI 종합 병합 ({', '.join(version_ids)})",
        )
        self._cache[new_version_id] = version
        self._store.save_draft(version)
        try:
            self._history.record_ontology_event(
                event_type="merged",
                version_id=new_version_id,
                detail=f"병합 소스: {', '.join(version_ids)} → 클래스 {len(classes)}개, 속성 {len(predicates)}개",
            )
        except Exception:
            pass
        return version

    # ── 버전 확정 (F3) ──────────────────────────────────────────────────────────

    def confirm(self, version_id: str) -> OntologyVersion:
        """
        Draft → Confirmed. 비가역.
        data/ontologies/confirmed/{version_id}.json 에 복사본 저장.
        draft 파일은 OntologyStore.save_confirmed() 에서 자동 삭제.
        """
        import dataclasses
        version = self.get(version_id)
        if version.status != OntologyStatus.DRAFT:
            raise PermissionError(
                f"Draft 상태만 확정 가능합니다. 현재 상태: {version.status}"
            )
        version.status       = OntologyStatus.CONFIRMED
        version.confirmed_at = datetime.now().isoformat()
        self._store.save_confirmed(version)
        try:
            self._history.record_ontology_event(
                event_type="confirmed",
                version_id=version_id,
                detail=(
                    f"클래스 {len(version.classes)}개, "
                    f"속성 {len(version.predicates)}개 확정"
                ),
                after=dataclasses.asdict(version),
            )
        except Exception:
            pass
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
