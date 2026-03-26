#!/usr/bin/env python3
import whisper
import sys
import json
import argparse
import os

# Windows에서 stdout/stderr을 UTF-8로 강제 설정
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=False)
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('file', nargs='?')
    parser.add_argument('--file', dest='file_flag')
    parser.add_argument('--language', default='ko')
    parser.add_argument('--model', default='medium',
                        choices=['tiny', 'base', 'small', 'medium', 'large'])
    args = parser.parse_args()

    file_path = args.file or args.file_flag
    if not file_path:
        print(json.dumps({"error": "파일 경로가 없습니다"}, ensure_ascii=False), flush=True)
        sys.exit(1)

    if not os.path.exists(file_path):
        print(json.dumps({"error": f"파일을 찾을 수 없습니다: {file_path}"}, ensure_ascii=False), flush=True)
        sys.exit(1)

    try:
        model = whisper.load_model(args.model)
        result = model.transcribe(file_path, language=args.language)
        print(json.dumps({
            "text": result["text"],
            "language": args.language,
            "segments": [
                {"start": s["start"], "end": s["end"], "text": s["text"].strip()}
                for s in result.get("segments", [])
            ]
        }, ensure_ascii=False), flush=True)
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False), flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
