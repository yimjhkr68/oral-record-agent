"""ontology/ontology_manager.py — 온톨로지 CRUDA + AI 생성 + 버전 확정"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional

import anthropic

logger = logging.getLogger(__name__)


def _extract_json(raw: str) -> dict:
    """AI 응답에서 JSON 객체를 robust하게 추출.

    처리 순서:
    1. 코드 펜스(```json ... ```) 제거 + BOM/제어문자 정리
    2. raw_decode: 첫 번째 '{' 위치부터 파싱 — 괄호 균형을 JSON 파서가 직접 계산
       (rfind('}')로 슬라이싱하면 JSON 뒤 설명 텍스트 안의 '}'에 오염될 수 있음)
    3. 실패 시 fallback: rfind('}') 슬라이싱 후 재시도
    4. 여전히 실패하면 ValueError (→ HTTP 422)
    """
    # 1. 코드 펜스 + BOM 제거
    clean = raw.replace("```json", "").replace("```", "").strip().lstrip('\ufeff')

    # 2. raw_decode: 첫 번째 '{' 위치에서 JSON 파서가 직접 경계 계산
    decoder = json.JSONDecoder()
    start = clean.find('{')
    if start != -1:
        try:
            obj, _ = decoder.raw_decode(clean, start)
            return obj
        except json.JSONDecodeError:
            pass

    # 3. fallback: rfind('}') 슬라이싱
    end = clean.rfind('}')
    if start != -1 and end != -1 and end > start:
        candidate = clean[start:end + 1]
        try:
            return json.loads(candidate)
        except json.JSONDecodeError:
            pass

    # 4. 실패
    logger.error("[ONTOLOGY_PARSE_FAIL] raw 앞부분: %r", raw[:500])
    raise ValueError(
        f"AI 응답에서 JSON을 찾을 수 없습니다.\n응답 앞부분: {raw[:300]!r}"
    )


# ── 데이터 모델 ────────────────────────────────────────────────────────────────

class OntologyStatus(str, Enum):
    DRAFT     = "draft"      # 편집 가능
    CONFIRMED = "confirmed"  # 확정 — 수정 불가, 트리플 생성에 사용
    ARCHIVED  = "archived"   # 보관 — 조회만 가능


@dataclass
class ClassMapping:
    """자체 클래스 ↔ 공표 온톨로지 클래스 매핑 (1:N, 주/보조 구분)."""
    curie:        str         # e.g. "crm:E21_Person"
    ontology_id:  str         # e.g. "cidoc-crm"
    is_primary:   bool  = True
    confidence:   float = 1.0
    note:         str   = ""


@dataclass
class OntologyClass:
    name:         str
    label_ko:     str
    color:        str
    description:  str = ""
    examples:     list[str] = field(default_factory=list)
    note:              str = ""
    standard_tag:      str = ""   # "foaf:Person · cidoc:E21_Person · schema:Person"
    merge_note:        str = ""   # 종합 시 처리 내역
    mappings:          list[ClassMapping] = field(default_factory=list)  # 공표 클래스 매핑
    mapping_confirmed: bool = False  # 관리자가 standard_tag 확정 여부


@dataclass
class OntologyPredicate:
    name:              str
    domain:            list[str] = field(default_factory=list)
    range_:            list[str] = field(default_factory=list)
    description:       str = ""
    note:              str = ""
    standard_tag:      str = ""   # "dc:relation · schema:relatedTo"
    merge_note:        str = ""   # 종합 시 처리 내역
    mapping_confirmed: bool = False  # 관리자가 standard_tag 확정 여부


# ── AI 종합 시스템 프롬프트 ───────────────────────────────────────────────────

MERGE_SYSTEM_PROMPT = """당신은 구술기록 아카이브 온톨로지 전문가입니다.
여러 Draft 온톨로지를 하나로 통합해주세요.

종합 원칙:
1. 동일/유사 클래스 통합: 같은 개념을 다르게 표현한 클래스는 하나로 합침
   예) Person + Person → Person (중복 제거)
   예) Victim + ColonialViolenceVictim → Victim (상위 개념으로 통일)
2. 독자 클래스 보존: 한쪽에만 있는 클래스는 합집합으로 포함
3. 구술 도메인 부적합 클래스 제거: 구술기록과 무관한 지나치게 구체적 클래스 제거
4. 속성(predicate) 도메인/범위 재정의: 통합된 클래스 기준으로 재설정

반드시 다음 JSON 형식으로만 응답하세요:
{
  "merge_report": {
    "merged":  [{"result": "클래스명", "sources": ["원본1", "원본2"], "reason": "이유"}],
    "added":   [{"name": "클래스명", "from": "draft-xxx", "reason": "이유"}],
    "removed": [{"name": "클래스명", "reason": "이유"}]
  },
  "classes": [
    {"name": "영문PascalCase", "label_ko": "한국어", "color": "#hex",
     "description": "정의", "examples": [], "merge_note": "처리내역"}
  ],
  "predicates": [
    {"name": "속성명", "domain": [], "range_": [], "description": "설명",
     "merge_note": "처리내역"}
  ]
}"""


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


# ── 공통 필터링 함수 ───────────────────────────────────────────────────────────

_ALLOWED_CLASS_FIELDS = {
    "name", "label_ko", "color", "description",
    "examples", "note", "standard_tag", "merge_note", "mappings",
    "mapping_confirmed",
}
_ALLOWED_PRED_FIELDS = {
    "name", "domain", "range_", "description",
    "note", "standard_tag", "merge_note",
    "mapping_confirmed",
}
_ALLOWED_MAPPING_FIELDS = {"curie", "ontology_id", "is_primary", "confidence", "note"}


def _safe_mapping(data: dict) -> "ClassMapping | None":
    """dict → ClassMapping. curie 없거나 타입 오류 시 None."""
    if not isinstance(data, dict):
        return None
    try:
        return ClassMapping(
            curie=data["curie"],
            ontology_id=data.get("ontology_id", ""),
            is_primary=bool(data.get("is_primary", True)),
            confidence=float(data.get("confidence", 1.0)),
            note=data.get("note", ""),
        )
    except (KeyError, TypeError, ValueError):
        return None


def _safe_class(data: dict) -> "OntologyClass | None":
    """dict → OntologyClass. 알 수 없는 필드·필수 필드 누락 시 None."""
    if not isinstance(data, dict):
        return None
    filtered = {k: v for k, v in data.items() if k in _ALLOWED_CLASS_FIELDS}
    # mappings: list[dict] → list[ClassMapping] (비-dict 항목 무시)
    raw = filtered.pop("mappings", [])
    filtered["mappings"] = [
        m for m in (
            _safe_mapping(d) if isinstance(d, dict) else None
            for d in (raw if isinstance(raw, list) else [])
        )
        if m is not None
    ]
    try:
        return OntologyClass(**filtered)
    except TypeError:
        return None


def _safe_predicate(data: dict) -> "OntologyPredicate | None":
    """dict → OntologyPredicate. 알 수 없는 필드·필수 필드 누락 시 None."""
    if not isinstance(data, dict):
        return None
    filtered = {k: v for k, v in data.items() if k in _ALLOWED_PRED_FIELDS}
    try:
        return OntologyPredicate(**filtered)
    except TypeError:
        return None


# ── OntologyManager ────────────────────────────────────────────────────────────

class OntologyManager:
    """온톨로지 CRUDA + AI 자동 생성 + 버전 확정."""

    def __init__(self, store=None) -> None:
        from ontology.ontology_store import OntologyStore
        from core.history_store import HistoryStore
        self._store: OntologyStore = store or OntologyStore()
        self._history: HistoryStore = HistoryStore()
        self.client = anthropic.Anthropic()
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

    def list_all(
        self,
        status: str | None = None,
        has_standard_tag: bool | None = None,
    ) -> list[OntologyVersion]:
        """전체 버전 목록, 최신순. status / has_standard_tag 필터 지원."""
        versions: list[OntologyVersion] = sorted(
            self._cache.values(),
            key=lambda v: v.created_at,
            reverse=True,
        )
        if status is not None:
            try:
                status_enum = OntologyStatus(status)
            except ValueError:
                return []
            versions = [v for v in versions if v.status == status_enum]
        if has_standard_tag is not None:
            versions = [
                v for v in versions
                if has_standard_tag == any(c.standard_tag for c in v.classes)
            ]
        return versions

    def rename(self, version_id: str, new_version_id: str) -> OntologyVersion:
        """버전 ID(이름) 변경. 중복 시 ValueError, 없으면 KeyError.

        - 파일 rename (old 삭제 → new 저장)
        - 메모리 캐시 업데이트
        - 이력 기록: "renamed" 이벤트
        """
        if version_id not in self._cache:
            raise KeyError(f"온톨로지 버전을 찾을 수 없습니다: {version_id!r}")
        if new_version_id in self._cache:
            raise ValueError(f"이미 존재하는 version_id: {new_version_id!r}")

        version = self._cache[version_id]
        version.version_id = new_version_id

        # 파일 저장 (old 파일 삭제 → new 파일 저장)
        if version.status == OntologyStatus.DRAFT:
            try:
                self._store.delete_draft(version_id)
            except KeyError:
                pass
            self._store.save_draft(version)
        else:
            # CONFIRMED or ARCHIVED — confirmed 디렉토리
            try:
                self._store.delete_confirmed(version_id)
            except KeyError:
                pass
            self._store.save_confirmed(version)

        # 캐시 갱신
        del self._cache[version_id]
        self._cache[new_version_id] = version

        try:
            self._history.record_ontology_event(
                event_type="renamed",
                version_id=new_version_id,
                detail=f"이름 변경: {version_id!r} → {new_version_id!r}",
            )
        except Exception:
            pass

        return version

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

    def _generate_unique_version_id(self, prefix: str) -> str:
        """타임스탬프 기반 고유 version_id 생성. 충돌 시 카운터 접미사 추가."""
        ts = datetime.now().strftime("%Y%m%d%H%M%S")
        candidate = f"{prefix}-{ts}"
        if candidate not in self._cache:
            return candidate
        counter = 2
        while f"{candidate}-{counter}" in self._cache:
            counter += 1
        return f"{candidate}-{counter}"

    def delete(self, version_id: str, force: bool = False) -> None:
        """Draft 상태만 삭제 가능. force=True 이면 Confirmed/Archived도 삭제."""
        version = self.get(version_id)
        if version.status != OntologyStatus.DRAFT and not force:
            raise PermissionError(
                f"Draft 상태만 삭제 가능합니다. 현재 상태: {version.status.value} "
                f"(강제 삭제하려면 force=True 사용)"
            )
        if version.status == OntologyStatus.DRAFT:
            self._store.delete_draft(version_id)
        else:
            self._store.delete_confirmed(version_id)
        del self._cache[version_id]
        try:
            self._history.record_ontology_event(
                event_type="deleted",
                version_id=version_id,
                detail=f"{version.status.value} 삭제" + (" (강제)" if force else ""),
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
        공표 온톨로지 클래스 목록을 프롬프트에 포함해 자동 매핑도 함께 생성.
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

        # 공표 온톨로지 클래스 목록 수집 (매핑 제안용)
        published_classes_section = ""
        try:
            from ontology.published_ontology_store import PublishedOntologyStore
            pub_store = PublishedOntologyStore()
            lines = []
            for onto in pub_store.list_all():
                items = ", ".join(
                    f"{c.curie}({c.label_ko})" for c in onto.classes
                )
                lines.append(f"  {onto.name} ({onto.prefix}): {items}")
            if lines:
                published_classes_section = (
                    "\n\n[공표 온톨로지 클래스 참조 — mappings 작성에 활용]\n"
                    + "\n".join(lines)
                )
        except Exception:
            pass  # 로드 실패 시 매핑 없이 진행

        system_prompt = f"""당신은 구술기록 아카이브 전문가다.
제공된 구술 텍스트 샘플을 분석하여 지식그래프 온톨로지를 제안해라.

기존 온톨로지({base_ontology_json if base_ontology_json else "없음"})가 있으면 그것을 기반으로 확장 제안해라.
텍스트에서 실제로 등장하는 개념만 포함해라.{published_classes_section}

반드시 다음 JSON 형식으로만 응답해:
{{
  "classes": [
    {{
      "name": "영문 PascalCase",
      "label_ko": "한국어 레이블",
      "color": "#hex",
      "description": "정의",
      "examples": ["예시1", "예시2"],
      "mappings": [
        {{"curie": "crm:E21_Person", "ontology_id": "cidoc-crm", "is_primary": true, "confidence": 0.95, "note": ""}},
        {{"curie": "schema:Person", "ontology_id": "schema-org", "is_primary": false, "confidence": 0.85, "note": ""}}
      ]
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

매핑 작성 지침:
- 공표 온톨로지 참조 목록에서 가장 적합한 클래스를 선택해라
- is_primary=true는 주 매핑(가장 의미적으로 가까운 것) 1개만
- is_primary=false는 보조 매핑 (0개 이상)
- confidence: 0.0~1.0 (의미적 유사도)
- 적합한 공표 클래스가 없으면 mappings를 빈 배열로 두어라"""

        client = anthropic.Anthropic()
        try:
            response = client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=8192,
                system=system_prompt,
                messages=[{"role": "user", "content": sample_text}],
            )
        except Exception as e:
            raise RuntimeError(f"AI API 호출 실패: {e}") from e

        if response.stop_reason == "max_tokens":
            raise ValueError(
                "AI 응답이 너무 깁니다. 더 짧은 샘플 텍스트를 입력하거나 "
                "다시 시도해주세요."
            )

        raw = response.content[0].text.strip()
        parsed = _extract_json(raw)

        classes = [
            c for c in (_safe_class(d) for d in parsed.get("classes", []))
            if c is not None
        ]
        predicates = [
            p for p in (_safe_predicate(d) for d in parsed.get("predicates", []))
            if p is not None
        ]

        # 새 버전 ID 자동 생성 (중복 방지)
        version_id = self._generate_unique_version_id("draft")

        version = OntologyVersion(
            version_id=version_id,
            classes=classes,
            predicates=predicates,
            based_on=base_version_id,
            description=f"AI 자동 생성 (샘플 기반{', 기반: ' + base_version_id if base_version_id else ''})",
        )
        from ontology.standard_tags import apply_standard_tags
        apply_standard_tags(version)
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
                     new_version_id: str,
                     description: str = "") -> OntologyVersion:
        """
        지정된 버전들의 클래스/속성을 수집 → AI로 중복 제거 + 정리 → 새 Draft 저장.
        Draft/Confirmed/Archived 모두 병합 소스로 사용 가능.
        new_version_id 중복 시 ValueError.
        """
        if not version_ids:
            raise ValueError("병합할 버전을 1개 이상 지정해야 합니다.")
        if new_version_id in self._cache:
            raise ValueError(f"이미 존재하는 version_id: {new_version_id!r}")

        # 1. 대상 버전 수집
        drafts = []
        for vid in version_ids:
            try:
                drafts.append(self.get(vid))
            except KeyError:
                raise ValueError(f"버전을 찾을 수 없습니다: {vid!r}")

        # 2. 클래스/속성 1차 수집
        all_classes    = [c for d in drafts for c in d.classes]
        all_predicates = [p for d in drafts for p in d.predicates]

        # 3. AI 종합
        merged_classes, merged_predicates = self._ai_merge(
            all_classes, all_predicates, version_ids
        )

        # 4. 새 Draft 생성
        new_version = OntologyVersion(
            version_id=new_version_id,
            status=OntologyStatus.DRAFT,
            classes=merged_classes,
            predicates=merged_predicates,
            description=description or f"AI 종합 병합 ({', '.join(version_ids)})",
            based_on=version_ids[0] if version_ids else None,
        )
        from ontology.standard_tags import apply_standard_tags
        apply_standard_tags(new_version)
        self._cache[new_version_id] = new_version
        self._store.save_draft(new_version)

        # 5. 이력 기록 (실패해도 merge 자체는 성공)
        try:
            self._history.record_ontology_event(
                event_type="merged",
                version_id=new_version_id,
                detail=(
                    f"Draft {version_ids} 종합 → "
                    f"클래스 {len(merged_classes)}개, 속성 {len(merged_predicates)}개"
                ),
            )
        except Exception as e:
            logger.warning(f"이력 기록 실패 (무시): {e}")

        return new_version

    def _ai_merge(self,
                  classes: list[OntologyClass],
                  predicates: list[OntologyPredicate],
                  source_ids: list[str]) -> tuple[list, list]:
        """AI 종합 + 방어적 파싱"""
        prompt = self._build_merge_prompt(classes, predicates, source_ids)

        try:
            message = self.client.messages.create(
                model="claude-sonnet-4-6",
                max_tokens=16000,
                system=MERGE_SYSTEM_PROMPT,
                messages=[{"role": "user", "content": prompt}],
            )
        except Exception as e:
            raise RuntimeError(f"AI API 호출 실패: {e}") from e

        text = "".join(b.text for b in message.content if hasattr(b, "text"))
        parsed = _extract_json(text)

        merged_classes = [
            c for c in (_safe_class(d) for d in parsed.get("classes", []))
            if c is not None
        ]
        merged_predicates = [
            p for p in (_safe_predicate(d) for d in parsed.get("predicates", []))
            if p is not None
        ]

        return merged_classes, merged_predicates

    def _build_merge_prompt(self,
                            classes: list[OntologyClass],
                            predicates: list[OntologyPredicate],
                            source_ids: list[str]) -> str:
        """AI 종합용 사용자 프롬프트 생성"""
        import dataclasses
        cls_list  = [dataclasses.asdict(c) for c in classes]
        pred_list = [dataclasses.asdict(p) for p in predicates]
        return (
            f"병합 소스: {', '.join(source_ids)}\n\n"
            f"수집된 클래스 ({len(cls_list)}개):\n"
            f"{json.dumps(cls_list, ensure_ascii=False, indent=2)}\n\n"
            f"수집된 속성 ({len(pred_list)}개):\n"
            f"{json.dumps(pred_list, ensure_ascii=False, indent=2)}"
        )

    # ── 버전 확정 (F3) ──────────────────────────────────────────────────────────

    def confirm(self, version_id: str) -> OntologyVersion:
        """
        Draft → Confirmed. 비가역.
        data/ontologies/confirmed/{version_id}.json 에 복사본 저장.
        draft 파일은 OntologyStore.save_confirmed() 에서 자동 삭제.
        """
        import dataclasses
        version = self.get(version_id)
        # 이미 Confirmed 이면 멱등 처리 (재호출 방어)
        if version.status == OntologyStatus.CONFIRMED:
            return version
        if version.status != OntologyStatus.DRAFT:
            raise PermissionError(
                f"Draft 상태만 확정 가능합니다. 현재 상태: {version.status.value}"
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
