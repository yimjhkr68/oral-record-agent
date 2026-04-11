"""api/router_settings.py — 런타임 설정 관리 (API 키 등)"""

import os
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/api/settings", tags=["settings"])

ENV_PATH = Path(__file__).resolve().parent.parent / ".env"


class ApiKeyRequest(BaseModel):
    api_key: str


@router.post("/api-key")
def set_api_key(data: ApiKeyRequest):
    """런타임에 ANTHROPIC_API_KEY 환경변수 변경 — 서버 재시작 없이 즉시 적용."""
    key = data.api_key.strip()

    if key and not key.startswith("sk-ant-"):
        raise HTTPException(status_code=400, detail="올바르지 않은 API 키 형식 (sk-ant-... 로 시작해야 합니다)")

    if key:
        os.environ["ANTHROPIC_API_KEY"] = key
    else:
        os.environ.pop("ANTHROPIC_API_KEY", None)

    _update_env_file(key)

    return {
        "success": True,
        "has_key": bool(key),
        "key_prefix": key[:12] + "..." if key else "",
    }


@router.get("/api-key/status")
def get_api_key_status():
    """현재 API 키 설정 상태 확인 (키 값은 반환하지 않음)."""
    key = os.environ.get("ANTHROPIC_API_KEY", "")
    return {
        "has_key": bool(key),
        "key_prefix": key[:12] + "..." if key else "",
        "is_valid_format": key.startswith("sk-ant-") if key else False,
    }


def _update_env_file(key: str) -> None:
    """.env 파일에 ANTHROPIC_API_KEY 저장 — 서버 재시작 후에도 유지."""
    lines: list[str] = []
    if ENV_PATH.exists():
        lines = ENV_PATH.read_text(encoding="utf-8").splitlines()

    found = False
    for i, line in enumerate(lines):
        if line.startswith("ANTHROPIC_API_KEY="):
            lines[i] = f"ANTHROPIC_API_KEY={key}" if key else ""
            found = True
            break

    if not found and key:
        lines.append(f"ANTHROPIC_API_KEY={key}")

    # 빈 줄 제거 후 저장
    ENV_PATH.write_text(
        "\n".join(l for l in lines if l) + "\n",
        encoding="utf-8",
    )
