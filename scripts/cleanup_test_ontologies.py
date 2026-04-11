"""
scripts/cleanup_test_ontologies.py

빌드/배포 전 테스트용 온톨로지를 자동 삭제하는 스크립트.
실행: python scripts/cleanup_test_ontologies.py [--dry-run]
"""

import sys
from pathlib import Path

# 테스트용 버전ID 패턴 (이 패턴으로 시작하면 삭제 대상)
TEST_PATTERNS = [
    "test-",
    "debug-",
    "temp-",
    "draft-test",
    "fix-test",
]

# 절대 삭제 안 할 버전ID 화이트리스트
WHITELIST = {
    "v1_ontology",
    "v1.0",
    "v2.0",
    "v3.0",
}

# 탐색 디렉토리 (스크립트 위치 기준 상위 data/)
_ROOT = Path(__file__).parent.parent
ONTOLOGY_DIRS = [
    _ROOT / "data" / "ontologies" / "drafts",
    _ROOT / "data" / "ontologies" / "confirmed",
    _ROOT / "data" / "ontologies" / "archived",
]


def is_test_version(version_id: str) -> bool:
    if version_id in WHITELIST:
        return False
    return any(version_id.startswith(p) for p in TEST_PATTERNS)


def cleanup(dry_run: bool = False) -> tuple[list[str], list[str]]:
    deleted: list[str] = []
    kept:    list[str] = []

    for dir_path in ONTOLOGY_DIRS:
        if not dir_path.exists():
            continue
        for f in sorted(dir_path.glob("*.json")):
            version_id = f.stem
            if is_test_version(version_id):
                if not dry_run:
                    f.unlink()
                deleted.append(f"{dir_path.name}/{version_id}")
            else:
                kept.append(version_id)

    label = "[DRY-RUN] " if dry_run else ""
    print(f"{label}삭제됨 ({len(deleted)}개):")
    for d in deleted:
        print(f"  - {d}")
    if not deleted:
        print("  (없음)")

    print(f"\n{label}유지됨 ({len(kept)}개):")
    for k in kept:
        print(f"  + {k}")
    if not kept:
        print("  (없음)")

    return deleted, kept


if __name__ == "__main__":
    dry_run = "--dry-run" in sys.argv
    if dry_run:
        print("=== DRY-RUN 모드 (실제 삭제 안 함) ===\n")
    cleanup(dry_run=dry_run)
