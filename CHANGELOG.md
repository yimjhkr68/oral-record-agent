# Changelog

모든 주요 변경사항을 이 파일에 기록합니다.
형식은 [Keep a Changelog](https://keepachangelog.com/ko/1.0.0/)를 따르며,
버전 관리는 [Semantic Versioning](https://semver.org/lang/ko/)을 따릅니다.

---

## [2.0.0] - 2026-03-28

### 🎯 핵심 변화: 시스템 → 에이전트

v1.0이 사람이 조작하는 기록관리 시스템이었다면,
v2.0은 의도를 전달하면 스스로 판단하고 실행하는 에이전트입니다.

### ✨ 새 기능

#### 에이전트 핵심
- AgentCore PDCA 루프 (Plan→Do→Check→Act)
- IntentParser 자연어 의도 분류 (6종)
- PromptEnhancer AI 프롬프트 개선 + 편집 + 재개선
- PlanPreviewCard 실행 전 계획 확인 및 의도 수정
- SmartSearch AI 의미 기반 기록 검색
- SearchConfirmDialog 검색 결과 확인 + 산출물 유형 선택
- 멀티스텝 태스크 (이번 달 기록 전부 정리 등)
- TaskPlanner 단일/멀티 태스크 자동 판단

#### 산출물 생성
- 에이전트 페르소나: 구술기록 큐레이터·아카이비스트
- 산출물 9종: 소설·시·희곡·에세이·학술논문·보고서·생애사책·칼럼·교육자료
- 모드별 시스템 프롬프트 (creative/academic/popular/report)
- 2단계 생성 (초안→교정) 품질 향상
- 산출물 타임아웃 설정 (기본 3분)
- outputs 폴더 저장 경로 통일
- 산출물 탭 (실행계정·일시·프롬프트·파일 목록)

#### 파일 지원
- 이미지 OCR (jpg, jpeg, png, bmp, tiff, webp)
- 텍스트 파일 (txt, md, csv)
- SHA-256 중복 파일 감지 (파이프라인 1단계)
- 중복 시 3가지 선택지 (등록중단/강제등록/기존업데이트)
- 파일명 기반 제목 자동 추출

#### UI/UX
- 홈 화면 4열 레이아웃 (사이드바·이력·에이전트·대시보드)
- 실행 이력 트리 (펼침/접힘, 앱 재시작 후 유지)
- 이력 상세창 (SelectableText, 드래그 복사)
- 로그 항목 클릭 → 전체 내용 팝업
- 프롬프트 3종 로그 (원본·개선·실행)
- 기록 상세 SelectableText (드래그 복사)
- 취소 시 입력창에 실행된 프롬프트 유지
- 검색 결과 없을 때 직접 선택 + 기록없이 실행

### 🔧 개선
- 보고서 내용 미전달 버그 수정
- extract_image → summarize 체이닝 수정
- REC 식별자 누락 수정
- 빈 콘텐츠 기록 사전 필터링 (summarize 파싱 오류 방지)
- JSON 파싱 방어 처리 (OCR 특수문자 escape)
- Windows 파일 드래그앤드롭 (OleInitialize)
- 스캔 PDF OCR 자동 fallback

---

## [1.0.0] - 2026-03-24

### 최초 릴리즈: 구술기록관리 시스템
- 음성/영상/텍스트 기록 등록
- Whisper 자동 전사
- Claude API 요약 생성
- 인물사전 관리
- REC 고유 식별자
- CSV/JSON 내보내기
- 로그인/권한 관리
- 네이비 테마 UI
- 통계 대시보드
