"""utils/file_extractor.py — 파일 텍스트 추출 (txt / pdf / docx)"""

from __future__ import annotations

import logging
from pathlib import Path

logger = logging.getLogger(__name__)

MAX_CHARS = 8000  # AI 컨텍스트 초과 방지 상한


def extract_text_from_file(file_path: str, filename: str) -> str:
    """
    파일에서 텍스트 추출 후 MAX_CHARS 이하로 반환.
    지원: .txt / .pdf / .docx
    실패 시 ValueError 발생 (HTTP 400 처리용)
    """
    ext = Path(filename).suffix.lower()

    # ── .txt ──────────────────────────────────────────────────────────────────
    if ext == ".txt":
        try:
            with open(file_path, encoding="utf-8") as f:
                text = f.read()
        except UnicodeDecodeError:
            with open(file_path, encoding="cp949", errors="replace") as f:
                text = f.read()

    # ── .docx ─────────────────────────────────────────────────────────────────
    elif ext == ".docx":
        try:
            from docx import Document  # type: ignore[import-untyped]
        except ImportError:
            raise ValueError(
                "python-docx 패키지가 설치되지 않았습니다. "
                "pip install python-docx 실행 후 서버를 재시작하세요."
            )
        try:
            doc = Document(file_path)
            paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
            text = "\n".join(paragraphs)
            if not text.strip():
                raise ValueError("docx 파일에서 텍스트를 추출할 수 없습니다.")
        except ValueError:
            raise
        except Exception as e:
            raise ValueError(f"docx 파싱 오류: {e}") from e

    # ── .pdf ──────────────────────────────────────────────────────────────────
    elif ext == ".pdf":
        try:
            import pdfplumber  # type: ignore[import-untyped]
        except ImportError:
            raise ValueError(
                "pdfplumber 패키지가 설치되지 않았습니다. "
                "pip install pdfplumber 실행 후 서버를 재시작하세요."
            )
        try:
            with pdfplumber.open(file_path) as pdf:
                pages = [page.extract_text() or "" for page in pdf.pages]
            text = "\n".join(pages).strip()
            if not text:
                raise ValueError(
                    "PDF에서 텍스트를 추출할 수 없습니다. (스캔 이미지 PDF일 가능성)"
                )
        except ValueError:
            raise
        except Exception as e:
            raise ValueError(f"PDF 파싱 오류: {e}") from e

    else:
        raise ValueError(
            f"지원하지 않는 파일 형식: {ext!r}. 지원 형식: .txt / .pdf / .docx"
        )

    # ── 길이 제한 ─────────────────────────────────────────────────────────────
    text = text.strip()
    if len(text) > MAX_CHARS:
        logger.warning(
            "텍스트 %d자 → %d자로 잘림 (파일: %s)", len(text), MAX_CHARS, filename
        )
        text = text[:MAX_CHARS]

    if not text:
        raise ValueError("파일에서 유효한 텍스트를 추출할 수 없습니다.")

    return text
