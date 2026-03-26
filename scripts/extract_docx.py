#!/usr/bin/env python3
# 파일 목적: DOCX 텍스트 추출 (python-docx 사용)
# 사용법: python extract_docx.py <파일경로>
# 출력:   JSON {"text": "..."} 또는 {"error": "..."}

import sys
import json
import os

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "파일 경로가 필요합니다. 사용법: extract_docx.py <파일경로>"}, ensure_ascii=False))
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(json.dumps({"error": f"파일을 찾을 수 없습니다: {file_path}"}, ensure_ascii=False))
        sys.exit(1)

    try:
        from docx import Document
    except ImportError:
        print(json.dumps({
            "error": "python-docx가 설치되지 않았습니다. 다음 명령을 실행하세요:\npip install python-docx"
        }, ensure_ascii=False))
        sys.exit(1)

    try:
        doc = Document(file_path)
        paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
        text = "\n".join(paragraphs)
        print(json.dumps({"text": text}, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"error": f"DOCX 추출 실패: {str(e)}"}, ensure_ascii=False))
        sys.exit(1)

if __name__ == "__main__":
    main()
