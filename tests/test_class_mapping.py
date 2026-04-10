"""tests/test_class_mapping.py — ClassMapping 모델 + 자동 매핑 + CRUD API 테스트"""

from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

import pytest

from ontology.ontology_manager import (
    ClassMapping,
    OntologyClass,
    OntologyManager,
    OntologyStatus,
    _safe_class,
    _safe_mapping,
)
from ontology.ontology_store import OntologyStore


# ── 픽스처 ────────────────────────────────────────────────────────────────────

@pytest.fixture
def store(tmp_path):
    return OntologyStore(
        drafts_dir=tmp_path / "drafts",
        confirmed_dir=tmp_path / "confirmed",
    )


@pytest.fixture
def manager(store):
    return OntologyManager(store=store)


# ── ClassMapping 모델 ────────────────────────────────────────────────────────

def test_class_mapping_defaults():
    m = ClassMapping(curie="crm:E21_Person", ontology_id="cidoc-crm")
    assert m.is_primary is True
    assert m.confidence == 1.0
    assert m.note == ""


def test_class_mapping_full():
    m = ClassMapping(
        curie="crm:E5_Event",
        ontology_id="cidoc-crm",
        is_primary=False,
        confidence=0.80,
        note="보조 매핑",
    )
    assert m.curie == "crm:E5_Event"
    assert m.is_primary is False
    assert m.confidence == 0.80


def test_ontology_class_has_mappings_field():
    cls = OntologyClass(name="Person", label_ko="인물", color="#f59e0b")
    assert cls.mappings == []


def test_ontology_class_with_mappings():
    mappings = [
        ClassMapping(curie="crm:E21_Person", ontology_id="cidoc-crm", is_primary=True, confidence=0.95),
        ClassMapping(curie="schema:Person", ontology_id="schema-org", is_primary=False, confidence=0.85),
    ]
    cls = OntologyClass(
        name="Person", label_ko="인물", color="#f59e0b", mappings=mappings
    )
    assert len(cls.mappings) == 2
    assert cls.mappings[0].curie == "crm:E21_Person"
    assert cls.mappings[1].is_primary is False


# ── _safe_mapping() ──────────────────────────────────────────────────────────

def test_safe_mapping_valid():
    m = _safe_mapping({"curie": "crm:E21_Person", "ontology_id": "cidoc-crm"})
    assert m is not None
    assert m.curie == "crm:E21_Person"


def test_safe_mapping_with_all_fields():
    m = _safe_mapping({
        "curie": "crm:E5_Event",
        "ontology_id": "cidoc-crm",
        "is_primary": False,
        "confidence": 0.8,
        "note": "보조",
    })
    assert m.confidence == 0.8
    assert m.is_primary is False


def test_safe_mapping_missing_curie_returns_none():
    assert _safe_mapping({"ontology_id": "cidoc-crm"}) is None


def test_safe_mapping_non_dict_returns_none():
    assert _safe_mapping("crm:E21_Person") is None  # type: ignore
    assert _safe_mapping(None) is None               # type: ignore


# ── _safe_class() — mappings 처리 ────────────────────────────────────────────

def test_safe_class_without_mappings():
    cls = _safe_class({
        "name": "Person", "label_ko": "인물", "color": "#f59e0b"
    })
    assert cls is not None
    assert cls.mappings == []


def test_safe_class_with_dict_mappings():
    cls = _safe_class({
        "name": "Person",
        "label_ko": "인물",
        "color": "#f59e0b",
        "mappings": [
            {"curie": "crm:E21_Person", "ontology_id": "cidoc-crm", "is_primary": True, "confidence": 0.95},
            {"curie": "schema:Person", "ontology_id": "schema-org", "is_primary": False, "confidence": 0.85},
        ],
    })
    assert cls is not None
    assert len(cls.mappings) == 2
    assert isinstance(cls.mappings[0], ClassMapping)
    assert cls.mappings[0].curie == "crm:E21_Person"


def test_safe_class_invalid_mapping_skipped():
    cls = _safe_class({
        "name": "Person",
        "label_ko": "인물",
        "color": "#f59e0b",
        "mappings": [
            {"curie": "crm:E21_Person", "ontology_id": "cidoc-crm"},
            "invalid-entry",   # 잘못된 항목 — 무시되어야 함
            {},                # curie 없음 — 무시
        ],
    })
    assert cls is not None
    assert len(cls.mappings) == 1  # 유효한 것만


# ── 직렬화/역직렬화 라운드트립 ────────────────────────────────────────────────

def test_ontology_class_mapping_roundtrip(store):
    """OntologyClass.mappings가 JSON 저장 후 복원되어야 한다."""
    import dataclasses
    from ontology.ontology_manager import OntologyVersion

    cls = OntologyClass(
        name="Person",
        label_ko="인물",
        color="#f59e0b",
        mappings=[
            ClassMapping(curie="crm:E21_Person", ontology_id="cidoc-crm", is_primary=True, confidence=0.95),
        ],
    )
    version = OntologyVersion(
        version_id="v-mapping-test",
        classes=[cls],
    )
    store.save_draft(version)
    loaded = store.load("v-mapping-test")
    assert len(loaded.classes) == 1
    assert len(loaded.classes[0].mappings) == 1
    restored = loaded.classes[0].mappings[0]
    assert restored.curie == "crm:E21_Person"
    assert restored.is_primary is True
    assert restored.confidence == 0.95


def test_empty_mappings_roundtrip(store):
    """mappings=[] 인 클래스도 정상 저장/복원."""
    from ontology.ontology_manager import OntologyVersion
    cls = OntologyClass(name="Place", label_ko="장소", color="#10b981")
    version = OntologyVersion(version_id="v-empty-mapping", classes=[cls])
    store.save_draft(version)
    loaded = store.load("v-empty-mapping")
    assert loaded.classes[0].mappings == []


# ── generate_from_sample 자동 매핑 (AI 모킹) ──────────────────────────────────

def _make_ai_response(content: str):
    msg = MagicMock()
    block = MagicMock()
    block.text = content
    msg.content = [block]
    return msg


_AI_RESPONSE_WITH_MAPPINGS = json.dumps({
    "classes": [
        {
            "name": "Person",
            "label_ko": "인물",
            "color": "#f59e0b",
            "description": "구술기록 인물",
            "examples": ["김영수"],
            "mappings": [
                {"curie": "crm:E21_Person", "ontology_id": "cidoc-crm", "is_primary": True, "confidence": 0.95, "note": ""},
                {"curie": "schema:Person", "ontology_id": "schema-org", "is_primary": False, "confidence": 0.85, "note": ""},
            ],
        },
        {
            "name": "Place",
            "label_ko": "장소",
            "color": "#10b981",
            "description": "지리적 장소",
            "examples": ["제주시"],
            "mappings": [
                {"curie": "crm:E53_Place", "ontology_id": "cidoc-crm", "is_primary": True, "confidence": 0.97, "note": ""},
            ],
        },
    ],
    "predicates": [
        {"name": "출생지", "domain": ["Person"], "range_": ["Place"], "description": "출생 장소"},
    ],
})

_AI_RESPONSE_NO_MAPPINGS = json.dumps({
    "classes": [
        {"name": "Person", "label_ko": "인물", "color": "#f59e0b", "description": "인물", "examples": []},
    ],
    "predicates": [],
})


@patch("anthropic.Anthropic")
def test_generate_with_mappings(mock_anthropic_cls, manager):
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = _make_ai_response(
        _AI_RESPONSE_WITH_MAPPINGS
    )
    manager.client = mock_client

    version = manager.generate_from_sample("제주 4·3 구술 샘플")
    assert len(version.classes) == 2

    person = next(c for c in version.classes if c.name == "Person")
    assert len(person.mappings) == 2
    primary = next(m for m in person.mappings if m.is_primary)
    assert primary.curie == "crm:E21_Person"
    assert primary.confidence == 0.95

    place = next(c for c in version.classes if c.name == "Place")
    assert len(place.mappings) == 1
    assert place.mappings[0].curie == "crm:E53_Place"


@patch("anthropic.Anthropic")
def test_generate_without_mappings_still_works(mock_anthropic_cls, manager):
    """AI가 mappings 없는 응답을 줘도 정상 처리되어야 한다."""
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = _make_ai_response(
        _AI_RESPONSE_NO_MAPPINGS
    )
    manager.client = mock_client

    version = manager.generate_from_sample("샘플 텍스트")
    assert len(version.classes) == 1
    assert version.classes[0].mappings == []


@patch("anthropic.Anthropic")
def test_generate_mappings_persisted(mock_anthropic_cls, manager):
    """생성된 매핑이 파일에 저장되어 재로드해도 유지되어야 한다."""
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = _make_ai_response(
        _AI_RESPONSE_WITH_MAPPINGS
    )
    manager.client = mock_client

    version = manager.generate_from_sample("제주 4·3 구술 샘플")
    version_id = version.version_id

    # 스토어에서 직접 재로드
    loaded = manager._store.load(version_id)
    person = next(c for c in loaded.classes if c.name == "Person")
    assert len(person.mappings) == 2
    assert person.mappings[0].curie == "crm:E21_Person"


# ── 매핑 CRUD — manager 레이어 ────────────────────────────────────────────────

def test_update_class_mappings_directly(manager):
    """클래스 mappings 필드를 직접 수정 후 저장/복원."""
    manager.create("v1.0")
    cls = OntologyClass(name="Event", label_ko="사건", color="#ef4444")
    manager.update("v1.0", classes=[cls])

    # 매핑 수정
    version = manager.get("v1.0")
    target = version.classes[0]
    target.mappings = [
        ClassMapping(curie="crm:E5_Event", ontology_id="cidoc-crm", is_primary=True, confidence=0.9),
    ]
    manager._store.save_draft(version)

    # 재로드
    reloaded = manager._store.load("v1.0")
    assert len(reloaded.classes[0].mappings) == 1
    assert reloaded.classes[0].mappings[0].curie == "crm:E5_Event"


def test_update_draft_preserves_mappings(manager):
    """manager.update() 호출 시 기존 mappings가 유지된다."""
    manager.create("v1.0")
    cls = OntologyClass(
        name="Person",
        label_ko="인물",
        color="#f59e0b",
        mappings=[
            ClassMapping(curie="crm:E21_Person", ontology_id="cidoc-crm")
        ],
    )
    manager.update("v1.0", classes=[cls])
    loaded = manager._store.load("v1.0")
    assert len(loaded.classes[0].mappings) == 1
