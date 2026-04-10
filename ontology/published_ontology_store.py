"""ontology/published_ontology_store.py — 공표 온톨로지 JSON 저장소"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path

from ontology.published_ontology import PublishedClass, PublishedOntology
from utils.file_io import atomic_write_json, ensure_dir, read_json

_DATA_ROOT = (
    Path(os.environ["DATA_DIR"])
    if os.environ.get("DATA_DIR")
    else Path(__file__).parent.parent / "data"
)
_DEFAULT_PATH = _DATA_ROOT / "published_ontologies.json"


# ── 제주 4·3 구술기록에 적합한 CIDOC-CRM 시드 데이터 ─────────────────────────────

_SEED_DATA: list[dict] = [
    {
        "id": "cidoc-crm",
        "name": "CIDOC Conceptual Reference Model",
        "prefix": "crm",
        "namespace_uri": "http://www.cidoc-crm.org/cidoc-crm/",
        "description": (
            "문화유산 정보를 위한 국제 표준 온톨로지(ISO 21127). "
            "박물관·도서관·기록관의 개념적 참조 모델로, 역사적 사건·인물·장소·"
            "시간 범위 등을 정밀하게 표현함."
        ),
        "version": "7.1.2",
        "classes": [
            {
                "curie": "crm:E4_Period",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E4_Period",
                "label": "Period",
                "label_ko": "역사적 시기",
                "description": "문화적으로 정의된 시공간 범위. 예: 일제강점기, 미군정기, 제주4·3 사건 기간.",
            },
            {
                "curie": "crm:E5_Event",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E5_Event",
                "label": "Event",
                "label_ko": "사건/이벤트",
                "description": "특정 시간·장소에서 발생한 역사적 사건. 예: 무장봉기, 초토화 작전, 학살 사건.",
            },
            {
                "curie": "crm:E7_Activity",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E7_Activity",
                "label": "Activity",
                "label_ko": "활동/행위",
                "description": "행위자가 수행한 의도적 활동. 예: 피난, 저항 활동, 증언 활동.",
            },
            {
                "curie": "crm:E9_Move",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E9_Move",
                "label": "Move",
                "label_ko": "이동/피난",
                "description": "사람이나 사물의 공간적 이동. 예: 주민 소개(疏開), 피난, 강제 이주.",
            },
            {
                "curie": "crm:E21_Person",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E21_Person",
                "label": "Person",
                "label_ko": "인물",
                "description": "개별 인간 존재. 구술자, 피해자, 가해자, 목격자 등 역사적 인물.",
            },
            {
                "curie": "crm:E39_Actor",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E39_Actor",
                "label": "Actor",
                "label_ko": "행위자",
                "description": "의도적 행위를 수행할 수 있는 존재(개인 또는 집단). 군부대, 경찰, 민간인 집단 포함.",
            },
            {
                "curie": "crm:E40_Legal_Body",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E40_Legal_Body",
                "label": "Legal Body",
                "label_ko": "법적 기관/조직",
                "description": "법적 지위를 가진 기관. 예: 제주경찰청, 9연대, 미군정청.",
            },
            {
                "curie": "crm:E74_Group",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E74_Group",
                "label": "Group",
                "label_ko": "집단/단체",
                "description": "공통 특성을 가진 사람들의 집합. 예: 무장대, 토벌대, 피난민 집단.",
            },
            {
                "curie": "crm:E53_Place",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E53_Place",
                "label": "Place",
                "label_ko": "장소",
                "description": "지리적 위치나 공간. 예: 마을, 해변, 오름, 수용소, 학살 현장.",
            },
            {
                "curie": "crm:E27_Site",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E27_Site",
                "label": "Site",
                "label_ko": "유적지/현장",
                "description": "역사적 사건과 연관된 특정 장소. 예: 4·3 유적지, 집단 학살 현장.",
            },
            {
                "curie": "crm:E52_Time-Span",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E52_Time-Span",
                "label": "Time-Span",
                "label_ko": "시간 범위",
                "description": "시작·끝 시점으로 정의되는 기간. 예: 4·3 사건 기간(1947–1954).",
            },
            {
                "curie": "crm:E50_Date",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E50_Date",
                "label": "Date",
                "label_ko": "날짜/시점",
                "description": "특정 날짜 표현. 예: 1948년 4월 3일, 1949년 6월.",
            },
            {
                "curie": "crm:E67_Birth",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E67_Birth",
                "label": "Birth",
                "label_ko": "출생",
                "description": "인물의 출생 사건.",
            },
            {
                "curie": "crm:E69_Death",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E69_Death",
                "label": "Death",
                "label_ko": "사망/희생",
                "description": "인물의 사망 사건. 4·3 희생자의 경우 특히 중요한 분류.",
            },
            {
                "curie": "crm:E33_Linguistic_Object",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E33_Linguistic_Object",
                "label": "Linguistic Object",
                "label_ko": "언어적 객체/구술",
                "description": "언어로 표현된 내용물. 구술 증언, 진술서, 구전 기억 등.",
            },
            {
                "curie": "crm:E31_Document",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E31_Document",
                "label": "Document",
                "label_ko": "문서/기록",
                "description": "정보를 담은 물리적 또는 디지털 문서. 재판 기록, 군 명령서, 신문 기사 등.",
            },
            {
                "curie": "crm:E55_Type",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E55_Type",
                "label": "Type",
                "label_ko": "유형/분류",
                "description": "사물이나 사건의 분류 범주. 예: 학살 유형, 피해 유형.",
            },
            {
                "curie": "crm:E78_Curated_Holding",
                "uri": "http://www.cidoc-crm.org/cidoc-crm/E78_Curated_Holding",
                "label": "Curated Holding",
                "label_ko": "컬렉션/소장",
                "description": "체계적으로 관리되는 소장 자료 집합. 4·3 아카이브, 구술 기록 컬렉션 등.",
            },
        ],
    },
    {
        "id": "schema-org",
        "name": "Schema.org",
        "prefix": "schema",
        "namespace_uri": "https://schema.org/",
        "description": (
            "웹에서 구조화 데이터를 표현하기 위한 광범위하게 채택된 어휘. "
            "Google, Microsoft, Yahoo, Yandex가 공동 개발."
        ),
        "version": "26.0",
        "classes": [
            {
                "curie": "schema:Person",
                "uri": "https://schema.org/Person",
                "label": "Person",
                "label_ko": "인물",
                "description": "살아있거나 사망한 개인 인물.",
            },
            {
                "curie": "schema:Place",
                "uri": "https://schema.org/Place",
                "label": "Place",
                "label_ko": "장소",
                "description": "지리적 위치 또는 물리적 장소.",
            },
            {
                "curie": "schema:Event",
                "uri": "https://schema.org/Event",
                "label": "Event",
                "label_ko": "사건/행사",
                "description": "특정 시간·장소에서 발생한 사건 또는 행사.",
            },
            {
                "curie": "schema:Organization",
                "uri": "https://schema.org/Organization",
                "label": "Organization",
                "label_ko": "조직/단체",
                "description": "기관, 단체, 회사 등의 조직.",
            },
            {
                "curie": "schema:CreativeWork",
                "uri": "https://schema.org/CreativeWork",
                "label": "CreativeWork",
                "label_ko": "창작물/기록물",
                "description": "책, 영화, 음악, 구술 기록 등 창작된 작품.",
            },
            {
                "curie": "schema:ArchiveComponent",
                "uri": "https://schema.org/ArchiveComponent",
                "label": "ArchiveComponent",
                "label_ko": "아카이브 구성요소",
                "description": "아카이브 컬렉션의 구성 항목.",
            },
        ],
    },
    {
        "id": "foaf",
        "name": "Friend of a Friend",
        "prefix": "foaf",
        "namespace_uri": "http://xmlns.com/foaf/0.1/",
        "description": (
            "사람, 그들의 활동, 다른 사람·사물과의 관계를 기계가 읽을 수 있게 "
            "표현하는 온톨로지."
        ),
        "version": "0.99",
        "classes": [
            {
                "curie": "foaf:Person",
                "uri": "http://xmlns.com/foaf/0.1/Person",
                "label": "Person",
                "label_ko": "인물",
                "description": "개별 인간 존재.",
            },
            {
                "curie": "foaf:Organization",
                "uri": "http://xmlns.com/foaf/0.1/Organization",
                "label": "Organization",
                "label_ko": "조직",
                "description": "사회적 기관이나 단체.",
            },
            {
                "curie": "foaf:Document",
                "uri": "http://xmlns.com/foaf/0.1/Document",
                "label": "Document",
                "label_ko": "문서",
                "description": "문서 자료.",
            },
        ],
    },
    {
        "id": "dublin-core",
        "name": "Dublin Core Metadata Initiative",
        "prefix": "dc",
        "namespace_uri": "http://purl.org/dc/elements/1.1/",
        "description": (
            "자원 설명을 위한 15개 핵심 메타데이터 요소 표준. "
            "도서관·아카이브 분야에서 광범위하게 사용."
        ),
        "version": "1.1",
        "classes": [
            {
                "curie": "dcterms:Agent",
                "uri": "http://purl.org/dc/terms/Agent",
                "label": "Agent",
                "label_ko": "행위자",
                "description": "행위를 수행하는 자원. 사람, 조직, 소프트웨어 에이전트 포함.",
            },
            {
                "curie": "dcterms:AgentClass",
                "uri": "http://purl.org/dc/terms/AgentClass",
                "label": "AgentClass",
                "label_ko": "행위자 분류",
                "description": "행위자의 집합.",
            },
            {
                "curie": "dcterms:Location",
                "uri": "http://purl.org/dc/terms/Location",
                "label": "Location",
                "label_ko": "위치/장소",
                "description": "공간적 지역 또는 명명된 장소.",
            },
            {
                "curie": "dcterms:PeriodOfTime",
                "uri": "http://purl.org/dc/terms/PeriodOfTime",
                "label": "PeriodOfTime",
                "label_ko": "시기",
                "description": "시작·끝 시점으로 정의되는 기간.",
            },
        ],
    },
]


class PublishedOntologyStore:
    """공표 온톨로지 JSON 단일 파일 저장소.

    구조: {"ontologies": [PublishedOntology.to_dict(), ...]}
    """

    def __init__(self, path: Path | None = None) -> None:
        self._path = Path(path) if path else _DEFAULT_PATH
        ensure_dir(self._path.parent)
        # 파일이 없으면 시드 데이터로 초기화
        if not self._path.exists():
            self._seed()

    # ── 내부 헬퍼 ────────────────────────────────────────────────────────────

    def _load_raw(self) -> dict:
        data = read_json(self._path)
        if not data:
            return {"ontologies": []}
        return data

    def _save_raw(self, data: dict) -> None:
        atomic_write_json(self._path, data)

    def _seed(self) -> None:
        """최초 실행 시 제주 4·3 적합 시드 데이터 저장."""
        self._save_raw({"ontologies": _SEED_DATA})

    # ── CRUD ────────────────────────────────────────────────────────────────

    def list_all(self) -> list[PublishedOntology]:
        data = self._load_raw()
        return [PublishedOntology.from_dict(d) for d in data.get("ontologies", [])]

    def get(self, ontology_id: str) -> PublishedOntology:
        for onto in self.list_all():
            if onto.id == ontology_id:
                return onto
        raise KeyError(f"공표 온톨로지를 찾을 수 없습니다: {ontology_id!r}")

    def create(self, onto: PublishedOntology) -> PublishedOntology:
        data = self._load_raw()
        ids = {d["id"] for d in data.get("ontologies", [])}
        if onto.id in ids:
            raise ValueError(f"이미 존재하는 ID입니다: {onto.id!r}")
        data.setdefault("ontologies", []).append(onto.to_dict())
        self._save_raw(data)
        return onto

    def update(self, ontology_id: str, **kwargs) -> PublishedOntology:
        """메타데이터(name, prefix, namespace_uri, description, version) 수정."""
        data = self._load_raw()
        items = data.get("ontologies", [])
        for i, d in enumerate(items):
            if d["id"] == ontology_id:
                allowed = {"name", "prefix", "namespace_uri", "description", "version"}
                for k, v in kwargs.items():
                    if k in allowed:
                        d[k] = v
                d["updated_at"] = datetime.now(timezone.utc).isoformat()
                items[i] = d
                self._save_raw(data)
                return PublishedOntology.from_dict(d)
        raise KeyError(f"공표 온톨로지를 찾을 수 없습니다: {ontology_id!r}")

    def delete(self, ontology_id: str) -> None:
        data = self._load_raw()
        items = data.get("ontologies", [])
        new_items = [d for d in items if d["id"] != ontology_id]
        if len(new_items) == len(items):
            raise KeyError(f"공표 온톨로지를 찾을 수 없습니다: {ontology_id!r}")
        data["ontologies"] = new_items
        self._save_raw(data)

    # ── 클래스 CRUD ──────────────────────────────────────────────────────────

    def add_class(self, ontology_id: str, cls: PublishedClass) -> PublishedOntology:
        data = self._load_raw()
        for i, d in enumerate(data.get("ontologies", [])):
            if d["id"] == ontology_id:
                existing_curies = {c["curie"] for c in d.get("classes", [])}
                if cls.curie in existing_curies:
                    raise ValueError(f"이미 존재하는 CURIE: {cls.curie!r}")
                d.setdefault("classes", []).append(cls.to_dict())
                d["updated_at"] = datetime.now(timezone.utc).isoformat()
                data["ontologies"][i] = d
                self._save_raw(data)
                return PublishedOntology.from_dict(d)
        raise KeyError(f"공표 온톨로지를 찾을 수 없습니다: {ontology_id!r}")

    def update_class(
        self, ontology_id: str, class_id: str, **kwargs
    ) -> PublishedOntology:
        data = self._load_raw()
        for i, d in enumerate(data.get("ontologies", [])):
            if d["id"] == ontology_id:
                classes = d.get("classes", [])
                for j, c in enumerate(classes):
                    if c["id"] == class_id:
                        allowed = {"curie", "uri", "label", "label_ko", "description"}
                        for k, v in kwargs.items():
                            if k in allowed:
                                c[k] = v
                        classes[j] = c
                        d["classes"] = classes
                        d["updated_at"] = datetime.now(timezone.utc).isoformat()
                        data["ontologies"][i] = d
                        self._save_raw(data)
                        return PublishedOntology.from_dict(d)
                raise KeyError(f"클래스 ID를 찾을 수 없습니다: {class_id!r}")
        raise KeyError(f"공표 온톨로지를 찾을 수 없습니다: {ontology_id!r}")

    def delete_class(self, ontology_id: str, class_id: str) -> PublishedOntology:
        data = self._load_raw()
        for i, d in enumerate(data.get("ontologies", [])):
            if d["id"] == ontology_id:
                classes = d.get("classes", [])
                new_classes = [c for c in classes if c["id"] != class_id]
                if len(new_classes) == len(classes):
                    raise KeyError(f"클래스 ID를 찾을 수 없습니다: {class_id!r}")
                d["classes"] = new_classes
                d["updated_at"] = datetime.now(timezone.utc).isoformat()
                data["ontologies"][i] = d
                self._save_raw(data)
                return PublishedOntology.from_dict(d)
        raise KeyError(f"공표 온톨로지를 찾을 수 없습니다: {ontology_id!r}")

    def list_classes_flat(self) -> list[dict]:
        """모든 공표 온톨로지의 클래스를 평탄화하여 반환. ontology_id 포함."""
        result = []
        for onto in self.list_all():
            for cls in onto.classes:
                result.append({
                    **cls.to_dict(),
                    "ontology_id": onto.id,
                    "ontology_name": onto.name,
                    "prefix": onto.prefix,
                })
        return result
