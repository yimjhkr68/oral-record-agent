# 🏛 구술기록관리 에이전트

> 구술 기록을 수집·분석·창작으로 연결하는 AI 에이전트

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python)](https://python.org)
[![Claude API](https://img.shields.io/badge/Claude-API-D4730A?logo=anthropic)](https://console.anthropic.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 버전

| 버전 | 설명 | 태그 |
|------|------|------|
| **v2.0** (현재) | 에이전트 시스템 — 자연어 프롬프트로 모든 작업 수행 | `v2.0` |
| v1.0 | 기록관리 시스템 — 수동 조작 기반 | `v1.0` |

---

## ✨ 주요 기능

### 에이전트 핵심
- 🤖 **자연어 프롬프트** — 의도를 말하면 스스로 판단·실행
- 🔄 **PDCA 루프** — Plan→Do→Check→Act 자율 실행
- 💡 **프롬프트 개선** — AI가 프롬프트를 다듬고 실행 전 계획 미리보기
- 🔍 **의미 기반 검색** — 키워드가 아닌 의미로 기록 검색
- 📋 **멀티스텝 태스크** — "이번 달 기록 전부 정리" 같은 복합 작업 자동 처리

### 산출물 생성
- 📝 **9종 산출물** — 소설·시·희곡·에세이·학술논문·보고서·생애사책·칼럼·교육자료
- 🎭 **페르소나** — 구술기록 큐레이터·아카이비스트 역할의 AI
- ✅ **2단계 품질** — 초안 생성 후 교정까지 자동 수행

### 파일 지원
- 🎤 **음성/영상** — mp3, wav, mp4, mov 등 (Whisper 로컬 전사)
- 📄 **문서** — pdf, docx, txt, md, csv
- 🖼 **이미지 OCR** — jpg, png, bmp, tiff, webp
- 🔒 **중복 방지** — SHA-256 해시 기반 자동 감지

### UI/UX
- 🏠 **홈 4열 레이아웃** — 사이드바·이력·에이전트·대시보드
- 📜 **실행 이력 트리** — 펼침/접힘, 재시작 후에도 유지
- 📋 **드래그 복사** — 이력·산출물·기록 상세 모두 SelectableText
- 🔔 **Windows 토스트 알림** — 단계 완료 및 오류 시 알림

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
pip install openai-whisper pdfplumber python-docx pydub pytesseract pillow
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
| UI / 앱 | Flutter / Dart (Windows 데스크탑) |
| 로컬 DB | Hive |
| 상태관리 | Riverpod |
| 음성 전사 | OpenAI Whisper (로컬) |
| AI 기능 | Anthropic Claude API |
| 문서 처리 | Python (pdfplumber, python-docx) |
| OCR | Tesseract + pytesseract |

---

## 📁 프로젝트 구조

```
lib/
├── agents/
│   ├── core/         # AgentCore, IntentParser, PromptEnhancer
│   ├── check/        # PDCA Check 서브에이전트
│   └── tools/        # 14개 툴 (전사·OCR·요약·검색·생성 등)
└── src/
    ├── data/         # 데이터 모델 / Hive 저장소
    ├── domain/       # 비즈니스 로직 / AI 툴
    └── presentation/ # UI 화면 / Riverpod 프로바이더

scripts/
├── transcribe.py     # 음성 전사 (Whisper)
├── extract_pdf.py    # PDF 텍스트 추출 (OCR fallback 포함)
├── extract_audio.py  # 영상 음성 추출
├── extract_image.py  # 이미지 OCR (Tesseract)
└── create_docx.py    # Word 문서 생성
```

---

## 🗺 로드맵

| 버전 | 목표 |
|------|------|
| v2.0 ✅ | 에이전트 시스템 완성 |
| v3.0 | RAG 적용 (벡터 검색) |
| v4.0 | 온톨로지 적용 (지식 그래프) |

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
