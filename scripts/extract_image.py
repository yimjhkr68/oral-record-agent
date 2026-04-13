#!/usr/bin/env python3
# 파일 목적: 이미지 파일에서 OCR 텍스트 추출 (pytesseract + PIL)
# 사용법: python extract_image.py <image_path>
# 필요: pip install pytesseract Pillow

import sys
import json
import os
import re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8')


def clean_ocr_text(text):
    """OCR 결과 정제: JSON 직렬화를 방해하는 제어문자 제거"""
    # 탭(\t=0x09), 줄바꿈(\n=0x0a), 캐리지리턴(\r=0x0d) 제외한 제어문자 제거
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', text)
    # 연속 공백 3개 이상 → 공백 1개
    text = re.sub(r' {3,}', ' ', text)
    return text.strip()


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


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"success": False, "error": "사용법: python extract_image.py <image_path>"}),
              file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]

    if not os.path.exists(image_path):
        print(json.dumps({"success": False, "error": f"파일 없음: {image_path}"}),
              file=sys.stderr)
        sys.exit(1)

    try:
        import pytesseract
        from PIL import Image
    except ImportError as e:
        print(json.dumps({
            "success": False,
            "error": f"필수 라이브러리 없음: {e}. pip install pytesseract Pillow 실행 후 재시도"
        }), file=sys.stderr)
        sys.exit(1)

    # Tesseract 경로 설정
    tess_path = _find_tesseract()
    if tess_path != "tesseract":
        pytesseract.pytesseract.tesseract_cmd = tess_path

    tessdata = _find_tessdata()
    if tessdata:
        os.environ["TESSDATA_PREFIX"] = tessdata

    try:
        img = Image.open(image_path)
        # 그레이스케일 이외 모드를 RGB로 변환 (OCR 정확도 향상)
        if img.mode not in ('L', 'RGB'):
            img = img.convert('RGB')

        # 한국어+영어 OCR
        text = pytesseract.image_to_string(img, lang='kor+eng', config='--oem 3 --psm 3')
        text = clean_ocr_text(text)

        # ensure_ascii=False: 한글 그대로 출력 (stdout이 UTF-8로 설정됨)
        print(json.dumps({
            "success": True,
            "text": text,
            "char_count": len(text),
            "extraction_method": "ocr",
        }, ensure_ascii=False))

    except Exception as e:
        print(json.dumps({"success": False, "error": f"OCR 실패: {e}"}), file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
