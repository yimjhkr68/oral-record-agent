"""tests/test_ontology_manager.py — OntologyManager 단위 테스트"""

from __future__ import annotations

import pytest
from unittest.mock import MagicMock, patch

from ontology.ontology_manager import (
    OntologyClass, OntologyManager, OntologyPredicate, OntologyStatus,
)
from ontology.ontology_store import OntologyStore


# ── 픽스처 ────────────────────────────────────────────────────────────────────

@pytest.fixture
def store(tmp_path):
    """임시 디렉토리를 사용하는 OntologyStore."""
    return OntologyStore(
        drafts_dir=tmp_path / "drafts",
        confirmed_dir=tmp_path / "confirmed",
    )


@pytest.fixture
def manager(store):
    return OntologyManager(store=store)


# ── 테스트 ────────────────────────────────────────────────────────────────────

def test_create_draft(manager):
    v = manager.create("v1.0", description="테스트 버전")
    assert v.version_id == "v1.0"
    assert v.status == OntologyStatus.DRAFT
    assert v.description == "테스트 버전"


def test_duplicate_version_id(manager):
    manager.create("v1.0")
    with pytest.raises(ValueError, match="v1.0"):
        manager.create("v1.0")


def test_update_draft(manager):
    manager.create("v1.0")
    classes = [OntologyClass(name="Person", label_ko="인물", color="#ff0000")]
    v = manager.update("v1.0", classes=classes)
    assert len(v.classes) == 1
    assert v.classes[0].name == "Person"


def test_update_confirmed_blocked(manager):
    manager.create("v1.0")
    manager.confirm("v1.0")
    with pytest.raises(PermissionError):
        manager.update("v1.0", description="수정 시도")


def test_confirm_version(manager):
    manager.create("v1.0")
    v = manager.confirm("v1.0")
    assert v.status == OntologyStatus.CONFIRMED
    assert v.confirmed_at is not None


def test_confirmed_file_saved(manager, store):
    manager.create("v1.0")
    manager.confirm("v1.0")
    # confirmed 디렉토리에 파일 존재 확인
    confirmed_file = store.confirmed_dir / "v1.0.json"
    assert confirmed_file.exists()
    # draft 파일은 삭제됐는지 확인 (보고 [4-2] 반영)
    draft_file = store.drafts_dir / "v1.0.json"
    assert not draft_file.exists()


def test_generate_from_sample(manager):
    """AI 호출을 mock 처리하여 generate_from_sample() 검증."""
    fake_response_text = """{
  "classes": [
    {
      "name": "Person",
      "label_ko": "인물",
      "color": "#4e79a7",
      "description": "구술에 등장하는 사람",
      "examples": ["김영수", "박철호"]
    }
  ],
  "predicates": [
    {
      "name": "출생지",
      "domain": ["Person"],
      "range_": ["Place"],
      "description": "인물의 출생 장소"
    }
  ]
}"""
    mock_content = MagicMock()
    mock_content.text = fake_response_text
    mock_response = MagicMock()
    mock_response.content = [mock_content]

    with patch("anthropic.Anthropic") as MockClient:
        MockClient.return_value.messages.create.return_value = mock_response
        v = manager.generate_from_sample("김영수는 경상북도 안동에서 태어났다.")

    assert v.status == OntologyStatus.DRAFT
    assert len(v.classes) == 1
    assert v.classes[0].name == "Person"
    assert len(v.predicates) == 1
    assert v.predicates[0].name == "출생지"


def test_archive_confirmed(manager):
    manager.create("v1.0")
    manager.confirm("v1.0")
    v = manager.archive("v1.0")
    assert v.status == OntologyStatus.ARCHIVED
    assert v.archived_at is not None


def test_archive_draft_blocked(manager):
    manager.create("v1.0")
    with pytest.raises(PermissionError):
        manager.archive("v1.0")


def test_get_latest_confirmed(manager):
    manager.create("v1.0")
    manager.confirm("v1.0")
    manager.create("v2.0")
    manager.confirm("v2.0")
    latest = manager.get_latest_confirmed()
    assert latest is not None
    assert latest.version_id == "v2.0"


# ── rename 테스트 ─────────────────────────────────────────────────────────────

def test_rename_draft(manager, store):
    manager.create("old-name")
    v = manager.rename("old-name", "new-name")
    assert v.version_id == "new-name"
    assert "new-name" in [x.version_id for x in manager.list_all()]
    assert "old-name" not in [x.version_id for x in manager.list_all()]
    assert (store.drafts_dir / "new-name.json").exists()
    assert not (store.drafts_dir / "old-name.json").exists()


def test_rename_confirmed(manager, store):
    manager.create("old-confirmed")
    manager.confirm("old-confirmed")
    v = manager.rename("old-confirmed", "new-confirmed")
    assert v.version_id == "new-confirmed"
    assert v.status == OntologyStatus.CONFIRMED
    assert (store.confirmed_dir / "new-confirmed.json").exists()
    assert not (store.confirmed_dir / "old-confirmed.json").exists()


def test_rename_duplicate_raises(manager):
    manager.create("v1")
    manager.create("v2")
    with pytest.raises(ValueError, match="v2"):
        manager.rename("v1", "v2")


def test_rename_not_found_raises(manager):
    with pytest.raises(KeyError):
        manager.rename("nonexistent", "new-name")


# ── list_all status 필터 테스트 ───────────────────────────────────────────────

def test_list_all_status_draft(manager):
    manager.create("d1")
    manager.create("d2")
    manager.confirm("d2")
    result = manager.list_all(status="draft")
    ids = [v.version_id for v in result]
    assert "d1" in ids
    assert "d2" not in ids


def test_list_all_status_confirmed(manager):
    manager.create("d1")
    manager.create("d2")
    manager.confirm("d2")
    result = manager.list_all(status="confirmed")
    ids = [v.version_id for v in result]
    assert "d2" in ids
    assert "d1" not in ids


def test_list_all_status_archived(manager):
    manager.create("d1")
    manager.confirm("d1")
    manager.archive("d1")
    result = manager.list_all(status="archived")
    ids = [v.version_id for v in result]
    assert "d1" in ids


def test_list_all_invalid_status_returns_empty(manager):
    manager.create("v1")
    result = manager.list_all(status="invalid_status")
    assert result == []


def test_list_all_has_standard_tag_filter(manager):
    from ontology.ontology_manager import OntologyClass
    manager.create("tagged")
    cls_with_tag = OntologyClass(name="Person", label_ko="인물",
                                  color="#f00", standard_tag="foaf:Person")
    manager.update("tagged", classes=[cls_with_tag])

    manager.create("untagged")

    with_tag = manager.list_all(has_standard_tag=True)
    without_tag = manager.list_all(has_standard_tag=False)

    assert any(v.version_id == "tagged" for v in with_tag)
    assert any(v.version_id == "untagged" for v in without_tag)
    assert all(v.version_id != "untagged" for v in with_tag)


def test_get_latest_confirmed_none(manager):
    assert manager.get_latest_confirmed() is None


def test_delete_draft(manager):
    manager.create("v1.0")
    manager.delete("v1.0")
    with pytest.raises(KeyError):
        manager.get("v1.0")


def test_delete_confirmed_blocked(manager):
    manager.create("v1.0")
    manager.confirm("v1.0")
    with pytest.raises(PermissionError):
        manager.delete("v1.0")


def test_persistence_reload(store):
    """재초기화 시 파일에서 복원 확인."""
    m1 = OntologyManager(store=store)
    m1.create("v1.0", description="복원 테스트")
    m1.confirm("v1.0")

    m2 = OntologyManager(store=store)
    v = m2.get("v1.0")
    assert v.status == OntologyStatus.CONFIRMED
    assert v.description == "복원 테스트"
