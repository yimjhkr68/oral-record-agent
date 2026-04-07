"""ontology/ontology_store.py — OntologyVersion ↔ JSON 파일 변환 담당"""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

import os

from utils.file_io import atomic_write_json, ensure_dir, read_json

if TYPE_CHECKING:
    from ontology.ontology_manager import OntologyVersion

# DATA_DIR 환경변수 → 없으면 프로젝트 루트 data/
_DATA_ROOT    = Path(os.environ["DATA_DIR"]) if os.environ.get("DATA_DIR") else Path(__file__).parent.parent / "data"
DRAFTS_DIR    = _DATA_ROOT / "ontologies" / "drafts"
CONFIRMED_DIR = _DATA_ROOT / "ontologies" / "confirmed"


def _to_dict(version: "OntologyVersion") -> dict:
    """OntologyVersion → JSON 직렬화용 dict."""
    from dataclasses import asdict
    return asdict(version)


def _from_dict(data: dict) -> "OntologyVersion":
    """dict → OntologyVersion 역직렬화."""
    from ontology.ontology_manager import (
        OntologyClass, OntologyPredicate, OntologyStatus, OntologyVersion,
    )
    data = dict(data)
    data["status"] = OntologyStatus(data["status"])
    data["classes"] = [OntologyClass(**c) for c in data.get("classes", [])]
    data["predicates"] = [OntologyPredicate(**p) for p in data.get("predicates", [])]
    return OntologyVersion(**data)


class OntologyStore:
    """OntologyVersion ↔ JSON 파일 변환 담당."""

    def __init__(self,
                 drafts_dir: Path | None = None,
                 confirmed_dir: Path | None = None) -> None:
        self.drafts_dir    = Path(drafts_dir)    if drafts_dir    else DRAFTS_DIR
        self.confirmed_dir = Path(confirmed_dir) if confirmed_dir else CONFIRMED_DIR
        ensure_dir(self.drafts_dir)
        ensure_dir(self.confirmed_dir)

    # ── 저장 ──────────────────────────────────────────────────────────

    def save_draft(self, version: "OntologyVersion") -> None:
        """data/ontologies/drafts/{version_id}.json 저장."""
        path = self.drafts_dir / f"{version.version_id}.json"
        atomic_write_json(path, _to_dict(version))

    def save_confirmed(self, version: "OntologyVersion") -> None:
        """
        data/ontologies/confirmed/{version_id}.json 저장 (읽기 전용 복사본).
        기존 draft 파일은 삭제한다 (confirm() 후 중복 방지).
        """
        path = self.confirmed_dir / f"{version.version_id}.json"
        atomic_write_json(path, _to_dict(version))
        # draft 파일 제거 (confirmed 우선 탐색 규칙 — 보고 [4-2] 반영)
        draft_path = self.drafts_dir / f"{version.version_id}.json"
        if draft_path.exists():
            draft_path.unlink()

    # ── 로드 ──────────────────────────────────────────────────────────

    def load(self, version_id: str) -> "OntologyVersion":
        """
        confirmed → drafts 순서로 탐색하여 로드.
        없으면 KeyError.
        """
        confirmed_path = self.confirmed_dir / f"{version_id}.json"
        draft_path     = self.drafts_dir    / f"{version_id}.json"

        if confirmed_path.exists():
            data = read_json(confirmed_path)
        elif draft_path.exists():
            data = read_json(draft_path)
        else:
            raise KeyError(f"온톨로지 버전을 찾을 수 없습니다: {version_id!r}")

        return _from_dict(data)

    def load_all(self) -> list["OntologyVersion"]:
        """전체 버전 목록 로드 (confirmed + drafts, 중복 없음)."""
        versions: dict[str, "OntologyVersion"] = {}

        # confirmed 먼저 로드
        for path in self.confirmed_dir.glob("*.json"):
            try:
                v = _from_dict(read_json(path))
                versions[v.version_id] = v
            except Exception:
                pass

        # drafts 로드 (confirmed에 없는 것만)
        for path in self.drafts_dir.glob("*.json"):
            try:
                v = _from_dict(read_json(path))
                if v.version_id not in versions:
                    versions[v.version_id] = v
            except Exception:
                pass

        return list(versions.values())

    # ── 삭제 ──────────────────────────────────────────────────────────

    def delete_draft(self, version_id: str) -> None:
        """drafts/{version_id}.json 삭제. 없으면 KeyError."""
        path = self.drafts_dir / f"{version_id}.json"
        if not path.exists():
            raise KeyError(f"Draft 파일 없음: {version_id!r}")
        path.unlink()
