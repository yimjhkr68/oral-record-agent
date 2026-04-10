"""tests/test_published_ontology.py — 공표 온톨로지 단위 테스트"""

from __future__ import annotations

import pytest

from ontology.published_ontology import PublishedClass, PublishedOntology
from ontology.published_ontology_store import PublishedOntologyStore


# ── 픽스처 ────────────────────────────────────────────────────────────────────

@pytest.fixture
def store(tmp_path):
    """임시 경로를 사용하는 PublishedOntologyStore (시드 데이터 포함)."""
    return PublishedOntologyStore(path=tmp_path / "published_ontologies.json")


@pytest.fixture
def empty_store(tmp_path):
    """빈 저장소 — 시드 없이 테스트용."""
    s = PublishedOntologyStore(path=tmp_path / "empty.json")
    # 시드 데이터 제거
    from utils.file_io import atomic_write_json
    atomic_write_json(s._path, {"ontologies": []})
    return s


def _sample_onto(id_="test-onto") -> PublishedOntology:
    return PublishedOntology(
        id=id_,
        name="Test Ontology",
        prefix="to",
        namespace_uri="http://example.org/test/",
        description="테스트용",
        version="1.0",
    )


def _sample_class(curie="to:TestClass") -> PublishedClass:
    return PublishedClass(
        curie=curie,
        uri=f"http://example.org/test/{curie.split(':')[1]}",
        label="TestClass",
        label_ko="테스트 클래스",
        description="테스트용 클래스",
    )


# ── 시드 데이터 테스트 ────────────────────────────────────────────────────────

def test_seed_data_loaded(store):
    """저장소 초기화 시 시드 온톨로지가 로드되어야 한다."""
    ontologies = store.list_all()
    assert len(ontologies) >= 4


def test_seed_contains_cidoc_crm(store):
    onto = store.get("cidoc-crm")
    assert onto.prefix == "crm"
    assert len(onto.classes) > 0


def test_seed_cidoc_crm_has_key_classes(store):
    onto = store.get("cidoc-crm")
    curies = {c.curie for c in onto.classes}
    assert "crm:E21_Person" in curies
    assert "crm:E5_Event" in curies
    assert "crm:E53_Place" in curies


def test_seed_contains_schema_org(store):
    onto = store.get("schema-org")
    assert onto.prefix == "schema"
    curies = {c.curie for c in onto.classes}
    assert "schema:Person" in curies
    assert "schema:Event" in curies


def test_seed_contains_foaf(store):
    onto = store.get("foaf")
    assert onto.prefix == "foaf"


def test_seed_contains_dublin_core(store):
    onto = store.get("dublin-core")
    assert onto.prefix == "dc"


def test_seed_classes_have_label_ko(store):
    """모든 시드 클래스에 한국어 레이블이 있어야 한다."""
    for onto in store.list_all():
        for cls in onto.classes:
            assert cls.label_ko, f"{cls.curie} 한국어 레이블 없음"


# ── 온톨로지 CRUD ────────────────────────────────────────────────────────────

def test_create_ontology(empty_store):
    onto = _sample_onto()
    result = empty_store.create(onto)
    assert result.id == "test-onto"
    assert result.prefix == "to"


def test_list_all_returns_created(empty_store):
    empty_store.create(_sample_onto("a"))
    empty_store.create(_sample_onto("b"))
    ids = {o.id for o in empty_store.list_all()}
    assert "a" in ids and "b" in ids


def test_get_ontology(empty_store):
    empty_store.create(_sample_onto())
    onto = empty_store.get("test-onto")
    assert onto.name == "Test Ontology"


def test_get_nonexistent_raises(empty_store):
    with pytest.raises(KeyError):
        empty_store.get("no-such-id")


def test_create_duplicate_raises(empty_store):
    empty_store.create(_sample_onto())
    with pytest.raises(ValueError, match="test-onto"):
        empty_store.create(_sample_onto())


def test_update_ontology(empty_store):
    empty_store.create(_sample_onto())
    updated = empty_store.update("test-onto", name="Updated Name", version="2.0")
    assert updated.name == "Updated Name"
    assert updated.version == "2.0"


def test_update_nonexistent_raises(empty_store):
    with pytest.raises(KeyError):
        empty_store.update("no-such-id", name="X")


def test_delete_ontology(empty_store):
    empty_store.create(_sample_onto())
    empty_store.delete("test-onto")
    assert not any(o.id == "test-onto" for o in empty_store.list_all())


def test_delete_nonexistent_raises(empty_store):
    with pytest.raises(KeyError):
        empty_store.delete("no-such-id")


def test_persistence_across_instances(tmp_path):
    """저장 후 새 인스턴스에서도 읽혀야 한다."""
    path = tmp_path / "pub.json"
    s1 = PublishedOntologyStore(path=path)
    # 시드 외 추가
    s1.create(_sample_onto())
    s2 = PublishedOntologyStore(path=path)
    ids = {o.id for o in s2.list_all()}
    assert "test-onto" in ids


# ── 클래스 CRUD ──────────────────────────────────────────────────────────────

def test_add_class(empty_store):
    empty_store.create(_sample_onto())
    cls = _sample_class()
    result = empty_store.add_class("test-onto", cls)
    curies = {c.curie for c in result.classes}
    assert "to:TestClass" in curies


def test_add_duplicate_class_raises(empty_store):
    empty_store.create(_sample_onto())
    empty_store.add_class("test-onto", _sample_class())
    with pytest.raises(ValueError, match="to:TestClass"):
        empty_store.add_class("test-onto", _sample_class())


def test_add_class_to_nonexistent_onto_raises(empty_store):
    with pytest.raises(KeyError):
        empty_store.add_class("no-such-id", _sample_class())


def test_update_class(empty_store):
    empty_store.create(_sample_onto())
    result = empty_store.add_class("test-onto", _sample_class())
    class_id = result.classes[0].id
    updated = empty_store.update_class(
        "test-onto", class_id, label_ko="수정된 레이블"
    )
    assert updated.classes[0].label_ko == "수정된 레이블"


def test_update_nonexistent_class_raises(empty_store):
    empty_store.create(_sample_onto())
    with pytest.raises(KeyError):
        empty_store.update_class("test-onto", "nonexistent-id", label="X")


def test_delete_class(empty_store):
    empty_store.create(_sample_onto())
    result = empty_store.add_class("test-onto", _sample_class())
    class_id = result.classes[0].id
    result2 = empty_store.delete_class("test-onto", class_id)
    assert len(result2.classes) == 0


def test_delete_nonexistent_class_raises(empty_store):
    empty_store.create(_sample_onto())
    with pytest.raises(KeyError):
        empty_store.delete_class("test-onto", "nonexistent-id")


# ── list_classes_flat ────────────────────────────────────────────────────────

def test_list_classes_flat_includes_ontology_info(store):
    flat = store.list_classes_flat()
    assert len(flat) > 0
    first = flat[0]
    assert "ontology_id" in first
    assert "prefix" in first
    assert "curie" in first


def test_list_classes_flat_covers_all_ontologies(store):
    all_ontologies = store.list_all()
    total_classes = sum(len(o.classes) for o in all_ontologies)
    flat = store.list_classes_flat()
    assert len(flat) == total_classes


# ── PublishedClass / PublishedOntology 모델 ──────────────────────────────────

def test_published_class_roundtrip():
    cls = PublishedClass(
        curie="crm:E21_Person",
        uri="http://www.cidoc-crm.org/cidoc-crm/E21_Person",
        label="Person",
        label_ko="인물",
        description="테스트",
    )
    restored = PublishedClass.from_dict(cls.to_dict())
    assert restored.curie == cls.curie
    assert restored.label_ko == cls.label_ko
    assert restored.id == cls.id


def test_published_ontology_roundtrip():
    onto = PublishedOntology(
        id="test",
        name="Test",
        prefix="t",
        namespace_uri="http://test.org/",
        classes=[
            PublishedClass(
                curie="t:A",
                uri="http://test.org/A",
                label="A",
                label_ko="에이",
            )
        ],
    )
    restored = PublishedOntology.from_dict(onto.to_dict())
    assert restored.id == "test"
    assert len(restored.classes) == 1
    assert restored.classes[0].curie == "t:A"
