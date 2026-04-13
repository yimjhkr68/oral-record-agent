"""api/router_graph_layout.py — 지식그래프 레이아웃 저장/불러오기"""

import json
import re
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/api/graph", tags=["graph-layout"])

LAYOUTS_DIR = Path(__file__).resolve().parent.parent / "data" / "graph_layouts"


def _ensure_dir():
    LAYOUTS_DIR.mkdir(parents=True, exist_ok=True)


# ── 목록 ──────────────────────────────────────────────────────────────────────

@router.get("/layouts")
def list_layouts():
    """저장된 레이아웃 목록 (최신순)"""
    _ensure_dir()
    layouts = []
    for f in sorted(LAYOUTS_DIR.glob("*.json"),
                    key=lambda x: x.stat().st_mtime, reverse=True):
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
            layouts.append({
                "name":              data.get("name", f.stem),
                "filename":          f.stem,
                "saved_at":          data.get("saved_at", ""),
                "node_count":        len(data.get("nodes", [])),
                "ontology_version":  data.get("ontology_version", ""),
            })
        except Exception:
            pass
    return {"layouts": layouts}


# ── 저장 ──────────────────────────────────────────────────────────────────────

@router.post("/layouts")
def save_layout(data: dict):
    """레이아웃 저장"""
    _ensure_dir()

    name = data.get("name", "").strip()
    if not name:
        raise HTTPException(status_code=400, detail="레이아웃 이름 필요")

    # 파일명: 한글·영숫자·하이픈만 허용, 나머지 → _
    filename = re.sub(r"[^\w가-힣\-]", "_", name)
    filepath = LAYOUTS_DIR / f"{filename}.json"

    payload = {
        "name":             name,
        "ontology_version": data.get("ontology_version", ""),
        "saved_at":         datetime.now().isoformat(timespec="seconds"),
        "nodes":            data.get("nodes", []),
    }
    filepath.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return {"saved": filename, "name": name}


# ── 불러오기 ──────────────────────────────────────────────────────────────────

@router.get("/layouts/{filename}")
def load_layout(filename: str):
    """레이아웃 불러오기"""
    _ensure_dir()
    filepath = LAYOUTS_DIR / f"{filename}.json"
    if not filepath.exists():
        raise HTTPException(status_code=404, detail="레이아웃 없음")
    return json.loads(filepath.read_text(encoding="utf-8"))


# ── 삭제 ──────────────────────────────────────────────────────────────────────

@router.delete("/layouts/{filename}")
def delete_layout(filename: str):
    """레이아웃 삭제"""
    filepath = LAYOUTS_DIR / f"{filename}.json"
    if filepath.exists():
        filepath.unlink()
    return {"deleted": filename}
