#!/usr/bin/env python3
"""영상 파일에서 음성 트랙을 추출해 임시 WAV 파일로 저장"""
import sys
import json
import subprocess
import os
import tempfile

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "사용법: extract_audio.py <video_path>"}, ensure_ascii=False))
        sys.exit(1)

    video_path = sys.argv[1]

    if not os.path.exists(video_path):
        print(json.dumps({"error": f"파일을 찾을 수 없습니다: {video_path}"}, ensure_ascii=False))
        sys.exit(1)

    temp_wav = tempfile.mktemp(suffix='.wav')

    try:
        result = subprocess.run(
            [
                'ffmpeg', '-i', video_path,
                '-vn', '-acodec', 'pcm_s16le',
                '-ar', '16000', '-ac', '1',
                temp_wav, '-y'
            ],
            capture_output=True,
            encoding='utf-8',
            errors='replace',
            timeout=120,
        )
        if result.returncode != 0:
            stderr_msg = result.stderr[-300:] if result.stderr else ''
            print(json.dumps({"error": f"ffmpeg 오류: {stderr_msg}"}, ensure_ascii=False))
            sys.exit(1)

        print(json.dumps({"audio_path": temp_wav}, ensure_ascii=False), flush=True)

    except FileNotFoundError:
        print(json.dumps({"error": "ffmpeg를 찾을 수 없습니다. 설치 명령: winget install ffmpeg"}, ensure_ascii=False))
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print(json.dumps({"error": "ffmpeg 타임아웃 (2분 초과)"}, ensure_ascii=False))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False))
        sys.exit(1)

if __name__ == "__main__":
    main()
