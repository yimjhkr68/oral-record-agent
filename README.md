# 구술기록관리 에이전트

## 소개

구술 면담 기록을 AI로 관리하는 Windows 데스크탑 앱

- 음성/영상 파일 전사 (Whisper)
- 기록 메타데이터 관리
- AI 기반 콘텐츠 생성 (보고서, 책 원고, 기사 등)
- Word / TXT 내보내기

## 개발 환경 설정

### 필수 설치

- Flutter SDK (https://flutter.dev)
- Python 3.10 이상 (https://www.python.org)
- Claude Code

### Python 패키지 설치

```bash
pip install openai-whisper pdfplumber python-docx pydub
```

### 실행 방법

```bash
# 1. 의존성 설치
flutter pub get

# 2. 환경 변수 설정
cp .env.example .env
# .env 파일을 열어 API 키 입력

# 3. 앱 실행
flutter run -d windows
```

## API 키 발급

Anthropic API 키: https://console.anthropic.com

## 기술 스택

| 영역 | 기술 |
|------|------|
| UI | Flutter / Dart |
| 로컬 DB | Hive |
| 상태관리 | Riverpod |
| 음성전사 | Python + Whisper |
| 문서처리 | Python + python-docx |
| AI | Anthropic Claude API |

## 라이선스

사내 전용 소프트웨어입니다.
