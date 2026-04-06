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
