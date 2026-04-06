#!/usr/bin/env python3
# 파일 목적: PDF 텍스트 추출 (pdfplumber + pytesseract OCR fallback)
# 처리 순서:
#   1. pdfplumber로 텍스트 레이어 추출
#   2. 추출 텍스트 < MIN_TEXT_LENGTH 이면 스캔 PDF로 판단
#   3. pdf2image → pytesseract OCR (한국어+영어) 로 fallback
# 출력: JSON {"text": "...", "extraction_method": "text_layer"|"ocr", "char_count": N}

import sys
import json
import os
import glob

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# ── 상수 ──────────────────────────────────────────────────
MIN_TEXT_LENGTH = 50   # 이 미만이면 스캔 PDF로 판단, OCR fallback
MAX_PAGES = 50         # 대용량 방지용 최대 페이지 수

# ── 경로 자동 탐지 ─────────────────────────────────────────

def _find_tesseract():
    """Windows Tesseract 설치 경로 자동 탐지"""
    candidates = [
        r"C:\Program Files\Tesseract-OCR\tesseract.exe",
        r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return "tesseract"  # PATH에 있길 기대

def _find_tessdata():
    """tessdata 경로 탐지: 사용자 홈 우선 → 시스템 설치 경로"""
    home = os.environ.get("USERPROFILE") or os.environ.get("HOME", "")
    user_tessdata = os.path.join(home, "tessdata")
    if os.path.isfile(os.path.join(user_tessdata, "kor.traineddata")):
        return user_tessdata
    system_tessdata = r"C:\Program Files\Tesseract-OCR\tessdata"
    if os.path.isdir(system_tessdata):
        return system_tessdata
    return None

def _find_poppler_path():
    """Windows WinGet 설치 경로에서 poppler bin 폴더 탐지"""
    winget_base = os.path.join(
        os.environ.get("LOCALAPPDATA", ""),
        "Microsoft", "WinGet", "Packages"
    )
    pattern = os.path.join(winget_base, "oschwartz10612.Poppler*", "poppler-*", "Library", "bin")
    matches = glob.glob(pattern)
    if matches:
        return sorted(matches)[-1]  # 최신 버전
    # 다른 흔한 위치
    alt = r"C:\poppler\bin"
    if os.path.exists(alt):
        return alt
    return None  # PATH에 있길 기대

# ── 텍스트 레이어 추출 ─────────────────────────────────────

def extract_text_layer(pdf_path):
    """pdfplumber로 텍스트 레이어 추출"""
    import pdfplumber
    text = ""
    with pdfplumber.open(pdf_path) as pdf:
        pages = pdf.pages[:MAX_PAGES]
        if len(pdf.pages) > MAX_PAGES:
            sys.stderr.write(
                f"[경고] PDF가 {len(pdf.pages)}페이지입니다. 앞 {MAX_PAGES}페이지만 처리합니다.\n"
            )
        for page in pages:
            page_text = page.extract_text()
            if page_text:
                text += page_text + "\n"
    return text.strip()

# ── OCR 추출 ──────────────────────────────────────────────

def extract_ocr(pdf_path):
    """pdf2image + pytesseract로 스캔 PDF OCR"""
    try:
        import pytesseract
    except ImportError:
        raise RuntimeError(
            "pytesseract가 설치되지 않았습니다.\n"
            "설치: pip install pytesseract"
        )
    try:
        from pdf2image import convert_from_path
    except ImportError:
        raise RuntimeError(
            "pdf2image가 설치되지 않았습니다.\n"
            "설치: pip install pdf2image\n"
            "poppler도 필요합니다: winget install oschwartz10612.poppler"
        )

    # Tesseract 경로 설정
    tesseract_cmd = _find_tesseract()
    pytesseract.pytesseract.tesseract_cmd = tesseract_cmd

    # tessdata 경로 설정
    tessdata = _find_tessdata()
    if tessdata:
        os.environ["TESSDATA_PREFIX"] = tessdata

    # Tesseract 동작 확인
    try:
        langs = pytesseract.get_languages()
    except Exception as e:
        raise RuntimeError(
            f"Tesseract를 찾을 수 없습니다 ({tesseract_cmd}).\n"
            "설치: winget install UB-Mannheim.TesseractOCR\n"
            f"원인: {e}"
        )

    # 언어 선택: kor 있으면 kor+eng, 없으면 eng
    lang = "kor+eng" if "kor" in langs else "eng"
    if "kor" not in langs:
        sys.stderr.write(
            "[경고] 한국어 tessdata 없음. 영어만으로 OCR 실행합니다.\n"
            "한국어 팩: https://github.com/tesseract-ocr/tessdata/raw/main/kor.traineddata\n"
            f"저장 위치: {tessdata or 'tessdata 폴더'}\n"
        )

    # poppler 경로
    poppler_path = _find_poppler_path()

    # PDF → 이미지 변환
    try:
        convert_kwargs = {"dpi": 200, "fmt": "png"}
        if poppler_path:
            convert_kwargs["poppler_path"] = poppler_path

        images = convert_from_path(pdf_path, **convert_kwargs)
    except Exception as e:
        raise RuntimeError(
            f"PDF→이미지 변환 실패: {e}\n"
            "poppler가 필요합니다: winget install oschwartz10612.poppler"
        )

    if len(images) > MAX_PAGES:
        sys.stderr.write(
            f"[경고] PDF가 {len(images)}페이지입니다. 앞 {MAX_PAGES}페이지만 OCR 합니다.\n"
        )
        images = images[:MAX_PAGES]

    # 각 페이지 OCR
    texts = []
    for i, img in enumerate(images, 1):
        sys.stderr.write(f"[OCR] {i}/{len(images)} 페이지 처리 중...\n")
        page_text = pytesseract.image_to_string(img, lang=lang)
        if page_text.strip():
            texts.append(page_text.strip())

    return "\n\n".join(texts)

# ── 메인 추출 로직 ─────────────────────────────────────────

def extract(pdf_path):
    """텍스트 레이어 시도 → OCR fallback"""
    text_layer = extract_text_layer(pdf_path)

    if len(text_layer.strip()) >= MIN_TEXT_LENGTH:
        return {
            "text": text_layer,
            "extraction_method": "text_layer",
            "char_count": len(text_layer),
        }

    # 스캔 PDF로 판단 → OCR
    sys.stderr.write(
        f"[OCR fallback] 텍스트 레이어 {len(text_layer.strip())}자 → 스캔 PDF 감지, OCR 실행\n"
    )
    ocr_text = extract_ocr(pdf_path)
    return {
        "text": ocr_text,
        "extraction_method": "ocr",
        "char_count": len(ocr_text),
    }

# ── 진입점 ────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(json.dumps(
            {"error": "파일 경로가 필요합니다. 사용법: extract_pdf.py <파일경로>"},
            ensure_ascii=False
        ))
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(json.dumps(
            {"error": f"파일을 찾을 수 없습니다: {file_path}"},
            ensure_ascii=False
        ))
        sys.exit(1)

    try:
        import pdfplumber  # noqa: F401
    except ImportError:
        print(json.dumps(
            {"error": "pdfplumber가 설치되지 않았습니다.\n설치: pip install pdfplumber"},
            ensure_ascii=False
        ))
        sys.exit(1)

    try:
        result = extract(file_path)
        print(json.dumps(result, ensure_ascii=False))
    except RuntimeError as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": f"PDF 추출 실패: {str(e)}"}, ensure_ascii=False))
        sys.exit(1)

if __name__ == "__main__":
    main()
