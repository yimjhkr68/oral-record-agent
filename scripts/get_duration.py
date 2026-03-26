#!/usr/bin/env python3
"""ffprobe로 음성/영상 파일 재생 시간(초) 측정"""
import sys
import json
import subprocess
import os

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', line_buffering=False)
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "사용법: get_duration.py <file_path>"}, ensure_ascii=False), flush=True)
        sys.exit(1)

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(json.dumps({"error": f"파일을 찾을 수 없습니다: {file_path}"}, ensure_ascii=False), flush=True)
        sys.exit(1)

    try:
        result = subprocess.run(
            [
                'ffprobe', '-v', 'quiet',
                '-print_format', 'json',
                '-show_format',
                file_path
            ],
            capture_output=True,
            encoding='utf-8',
            errors='replace',
            timeout=30,
        )
        if result.returncode != 0:
            print(json.dumps({"error": f"ffprobe 오류: {result.stderr[-200:]}"}, ensure_ascii=False), flush=True)
            sys.exit(1)

        data = json.loads(result.stdout)
        duration_str = data.get('format', {}).get('duration', None)
        if duration_str is None:
            print(json.dumps({"error": "duration 정보 없음"}, ensure_ascii=False), flush=True)
            sys.exit(1)

        duration_sec = int(float(duration_str))
        print(json.dumps({"duration": duration_sec}, ensure_ascii=False), flush=True)

    except FileNotFoundError:
        print(json.dumps({"error": "ffprobe를 찾을 수 없습니다. ffmpeg를 설치해주세요."}, ensure_ascii=False), flush=True)
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(json.dumps({"error": "타임아웃"}, ensure_ascii=False), flush=True)
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False), flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
