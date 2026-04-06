"""utils/file_io.py — 원자적 파일 I/O 유틸"""

from __future__ import annotations

import json
import os
from pathlib import Path


def ensure_dir(path: str | Path) -> None:
    """디렉토리 없으면 생성 (중간 경로 포함)."""
    Path(path).mkdir(parents=True, exist_ok=True)


def atomic_write_json(path: str | Path, data: dict) -> None:
    """
    원자적 JSON 저장.
    tmp 파일에 쓰고 os.replace() → 저장 중 크래시 시 파일 손상 방지.
    """
    path = str(path)
    tmp_path = path + ".tmp"
    ensure_dir(os.path.dirname(path))
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp_path, path)


def read_json(path: str | Path) -> dict:
    """JSON 파일 읽기. 파일 없으면 빈 dict 반환."""
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
