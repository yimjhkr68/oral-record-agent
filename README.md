# 🏛 구술기록관리 에이전트

> AI 기반 구술 면담 기록 관리 Windows 데스크탑 앱

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)](https://python.org)
[![Claude API](https://img.shields.io/badge/Claude-API-D4730A?logo=anthropic)](https://console.anthropic.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## ✨ 주요 기능

- 🎤 **음성/영상 자동 전사** — 로컬 Whisper 모델로 인터넷 없이 전사
- 🤖 **AI 요약 및 분석** — Claude API 기반 자동 요약·분류·PII 감지
- 👥 **구술자/면담자 인물사전 관리** — 등록·검색·연결
- 🔍 **전문 검색 및 필터링** — 날짜·구술자·키워드 복합 검색
- 📖 **AI 기반 책/보고서 자동 생성** — 챕터별 순차 생성 + Word 내보내기
- 🔐 **계정별 권한 관리** — 관리자/일반 사용자 역할 분리
- 📤 **CSV/JSON 내보내기/들여오기** — 데이터 이식성 보장

---

## 🖥 시스템 요구사항

| 항목 | 최소 사양 |
|------|-----------|
| OS | Windows 10/11 64비트 |
| RAM | 8GB 이상 |
| Python | 3.10 이상 |
| 네트워크 | 인터넷 연결 (AI 기능 사용 시) |

---

## 🚀 설치 및 실행

### 1. 저장소 Fork

GitHub 상단의 **Fork** 버튼을 클릭해 본인 계정으로 복사하세요.

### 2. 코드 받기

```bash
git clone https://github.com/{본인계정}/oral-record-agent.git
cd oral-record-agent
```

### 3. Flutter 패키지 설치

```bash
flutter pub get
```

### 4. Python 패키지 설치

```bash
pip install openai-whisper pdfplumber python-docx pydub
```

### 5. ffmpeg 설치

```bash
winget install Gyan.FFmpeg
```

> 설치 후 터미널을 재시작하세요.

### 6. API 키 설정

```bash
copy .env.example .env
```

`.env` 파일을 열어 발급받은 키를 입력합니다:

```env
ANTHROPIC_API_KEY=발급받은_키_입력
```

> API 키 발급: https://console.anthropic.com

### 7. 실행

```bash
flutter run -d windows
```

---

## 🏗 기술 스택

| 영역 | 기술 |
|------|------|
| UI / 앱 | Flutter / Dart |
| 로컬 DB | Hive |
| 상태관리 | Riverpod |
| 음성 전사 | OpenAI Whisper (로컬) |
| AI 기능 | Anthropic Claude API |
| 문서 처리 | Python (pdfplumber, python-docx) |

---

## 📁 프로젝트 구조

```
lib/
├── agents/           # PDCA 서브에이전트
└── src/
    ├── data/         # 데이터 모델 / 저장소
    ├── domain/       # 비즈니스 로직 / AI 툴
    └── presentation/ # UI 화면 / 프로바이더

scripts/
├── transcribe.py     # 음성 전사 (Whisper)
├── extract_pdf.py    # PDF 텍스트 추출
├── extract_audio.py  # 영상 음성 추출
└── create_docx.py    # Word 문서 생성
```

---

## 🔑 최초 로그인

| 항목 | 값 |
|------|----|
| 이메일 | admin@oral.kr |
| 비밀번호 | Admin1234! |

> ⚠️ 로그인 후 즉시 비밀번호를 변경하세요.

---

## 🛠 개발 배경

이 프로젝트는 **[Claude.ai](https://claude.ai)** 와 **[Claude Code](https://claude.ai/claude-code)** 를 활용해
**PDCA 서브에이전트 방식**으로 개발한 프로젝트입니다.

별도의 코딩 없이 AI와 대화만으로 Flutter Windows 앱을 완성했습니다.
설계(Plan) → 구현(Do) → 검증(Check) → 개선(Act) 사이클을 자율 반복하며
품질 기준을 달성할 때까지 스스로 수정·보완합니다.

---

## 📄 라이선스

[MIT License](LICENSE) — 자유롭게 복사 / 수정 / 배포 가능합니다.

---

## 🤝 기여 방법

1. 이 저장소를 **Fork** 하세요.
2. 기능 추가 또는 버그 수정을 진행하세요.
3. **Pull Request** 를 보내주세요.

---

<p align="center">
  Made with ❤️ using Claude Code
</p>
