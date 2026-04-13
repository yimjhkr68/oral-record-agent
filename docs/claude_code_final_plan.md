# v4.0 기능 검증 + 멀티 플랫폼 확장 Plan

## 전체 순서

```
Phase E: Windows 전체 기능 테스트 (지금 당장)
Phase F: 코드 정리 + 문서화
Phase G: 멀티 플랫폼 확장 (Android → iOS → Web)
Phase H: git 정리 + PR → main 머지
```

---

## Phase E — Windows 전체 기능 테스트

### 사전 준비

```bash
# 터미널 1: FastAPI 서버
cd E:/Oral-record-agent_v4.0
set ANTHROPIC_API_KEY=sk-ant-여기에키입력
python -m uvicorn main:app --port 9000

# 터미널 2: Flutter 앱
cd E:/Oral-record-agent_v4.0/flutter
flutter run -d windows
```

---

### E-1. 설정 화면

```
□ 앱 실행 시 설정 화면 자동 진입 확인
□ FastAPI 서버 주소: http://127.0.0.1:9000
□ [저장 및 연결 확인] → 녹색 "FastAPI 연결됨"
□ 재시작 후에도 설정값 유지 (shared_preferences)
```

---

### E-2. 온톨로지 관리 화면

#### E-2-1. 버전 목록 조회
```
□ 기존 Draft/Confirmed/Archived 버전 목록 표시
□ 상태 배지 색상 (Draft=주황, Confirmed=초록, Archived=회색)
□ 버전 클릭 → 우측 클래스/속성 목록 표시
□ 스크롤 가능
```

#### E-2-2. 새 버전 직접 생성
```
□ [+ 새 버전] 클릭 → 버전ID 입력 다이얼로그
□ 버전ID 입력 후 생성 → 목록에 추가 확인
□ 클래스 [+ 추가] → 이름/레이블/색상/설명 입력 → 저장
□ 속성 [+ 추가] → 이름/도메인/범위 입력 → 저장
□ [확정하기] → 확인 다이얼로그 → Confirmed 전환
□ Confirmed 후 편집 UI 사라지는지 확인
```

#### E-2-3. AI 온톨로지 생성
```
□ [구술기록으로 생성] 클릭
□ 텍스트 입력 탭 → 아래 샘플 텍스트 입력:

  "저는 1952년 경상북도 안동에서 태어났습니다.
   아버지는 독립운동가였고 어머니는 안동 고성이씨 집안 출신이었어요.
   6·25 전쟁 때 우리 가족은 부산으로 피란을 갔습니다.
   전쟁이 끝난 뒤 안동으로 돌아와 안동중학교를 다녔어요."

□ [AI 생성] 클릭 → 로딩 표시 → Draft 생성 확인
□ 생성된 Draft 클릭 → 클래스/속성 목록 표시 확인
```

#### E-2-4. Draft 종합
```
□ Draft 2개 이상 체크박스 선택
□ [선택 Draft 종합] 버튼 활성 확인
□ 클릭 → 새 버전ID 입력 → [종합 시작]
□ 새 Draft 생성 + 자동 선택 확인
□ 클래스/속성이 종합된 결과인지 확인
```

---

### E-3. 트리플 관리 화면

#### E-3-1. Step 1 — 추출 설정
```
□ Confirmed 온톨로지만 드롭다운에 표시되는지
□ [텍스트 입력] 탭 → 텍스트 입력 → [추가]
□ 선택된 구술기록 카드 목록에 추가 확인
□ [파일 업로드] 탭 → .txt 파일 선택 → 추가
□ [저장된 기록 선택] 탭 → 기록 목록 표시 → 체크박스 선택
□ [트리플 생성] 버튼 활성 확인 (온톨로지 + 기록 선택 시)
□ [트리플 생성] 클릭 → 진행 바 표시
□ 생성 완료 → Step 2 자동 이동
```

#### E-3-2. Step 2 — 검토 및 수정
```
□ 생성된 트리플 카드 목록 표시
□ 각 카드: 주어/술어/목적어/신뢰도/출처 표시
□ [수정] 클릭 → 인라인 편집 → 저장
□ [삭제] 클릭 → 해당 카드 제거
□ [+ 트리플 직접 추가] → 다이얼로그 → 추가
□ [전체 확정 저장] 클릭 → 블랙 화면 없이 Step 3 이동
```

#### E-3-3. Step 3 — 저장된 트리플 조회
```
□ 확정된 트리플 목록 표시
□ 검색창 입력 → 필터링 동작
□ 트리플 클릭 → 상세 패널 표시
□ 상세 패널에서 수정/아카이브/삭제 동작
```

---

### E-4. 지식그래프 화면

```
□ 탭 진입 → 노드/엣지 그래프 표시
□ 포스 레이아웃 → 수렴 후 정지
□ 노드 크기가 연결수에 비례하는지 확인
□ 검색창 입력 → 매칭 노드 강조 (1.5배 + 노란 테두리)
□ 비매칭 노드 투명도 20% 확인
□ ✕ 클릭 → 전체 복원
□ 노드 클릭 → 상세 BottomSheet 표시
□ 노드 드래그 → 위치 고정
□ 마우스 스크롤 → 줌 인/아웃
□ 하단 범례 클래스 색상 표시
□ 우상단 통계 (노드 N · 트리플 N) 표시
```

---

### E-5. 기록 화면

```
□ 텍스트로 등록한 구술기록 목록 표시
□ 파일 업로드로 등록한 구술기록 표시
□ [T]/[F] 타입 배지 표시
□ 기록 카드 클릭 → 상세 화면
□ 상세 화면: 내용 미리보기 탭 + 트리플 생성 이력 탭
□ [수정] → 제목/메모 수정
□ [삭제] → 소프트 삭제 (목록에서 사라짐)
□ 검색창 → 제목/내용 검색 동작
```

---

### E-6. 이력 화면

```
□ [온톨로지 이력] 탭
  - 온톨로지 생성/수정/확정 이벤트 타임라인 표시
  - 이벤트 클릭 → 상세 정보

□ [트리플 생성 이력] 탭
  - ExtractionSession 카드 목록
  - 세션 클릭 → 처리한 기록 목록 + 추출/확정/삭제 통계

□ GET /api/history/summary 통계 표시
  - 등록된 기록 수
  - 온톨로지 버전 수
  - 확정된 트리플 수
```

---

### E-7. 전체 플로우 통합 테스트

아래 시나리오를 처음부터 끝까지 실행:

```
시나리오: "구술기록 → 온톨로지 → 트리플 → 그래프"

1. [기록] 탭 → [+ 텍스트 입력] → 샘플 텍스트 등록
2. [온톨로지] 탭 → [구술기록으로 생성] → 등록한 기록 선택 → AI 생성
3. 생성된 Draft 검토 → [확정하기]
4. [트리플] 탭 → Step 1
   → Confirmed 온톨로지 선택
   → [저장된 기록 선택] 탭 → 등록한 기록 선택
   → [트리플 생성]
5. Step 2: 검토 → [전체 확정 저장]
6. [지식그래프] 탭 → [↺ 새로고침] → 그래프 표시 확인
7. 검색창에 구술자명 입력 → 해당 노드 강조 확인
8. [이력] 탭 → 온톨로지 이벤트 + 트리플 세션 표시 확인
```

---

### E 결과 보고 형식

```
[E-1 설정]        □□□□  N/4 통과
[E-2 온톨로지]    □□□□  N/12 통과
[E-3 트리플]      □□□□  N/11 통과
[E-4 지식그래프]  □□□□  N/10 통과
[E-5 기록]        □□□□  N/7 통과
[E-6 이력]        □□□□  N/6 통과
[E-7 통합]        □□□□  N/8 통과

발견된 버그:
  1. [화면명] 증상:
  2. [화면명] 증상:
```

---

## Phase F — 코드 정리 + 문서화

E에서 발견된 버그를 수정한 후 진행.

### F-1. 불필요한 파일 제거

```bash
# Hive 관련 잔재 확인
grep -r "hive" E:/Oral-record-agent_v4.0 \
  --include="*.py" --include="*.dart" -l

# Web UI 잔재 (JSX, index.html) 처리 여부 결정
ls E:/Oral-record-agent_v4.0/ui/
ls E:/Oral-record-agent_v4.0/static/
# → Flutter로 전환 완료됐으므로 삭제 또는 legacy/ 폴더로 이동
```

### F-2. README.md 작성

```markdown
# 구술기록 지식그래프 에이전트 v4.0

## 개요
구술기록의 온톨로지 기반 지식그래프 생성·관리·시각화 시스템

## 기술 스택
- 백엔드: FastAPI (Python) · SQLite · JSON 파일 DB
- 프론트엔드: Flutter (Windows · Android · iOS · Web)
- AI: Anthropic Claude API

## 실행 방법
### 백엔드
set ANTHROPIC_API_KEY=sk-ant-...
python -m uvicorn main:app --port 9000

### Flutter (Windows)
cd flutter && flutter run -d windows

## 기능
- 온톨로지 버전 관리 (Draft → Confirmed → Archived)
- AI 온톨로지 자동 생성 + Draft 종합
- 구술기록 입력 (텍스트 직접 입력 / 파일 업로드)
- 트리플 추출 → 검토 → 확정 저장
- 지식그래프 시각화 + 검색 노드 강조
- 전체 이력 관리 (SQLite)

## 테스트
pytest tests/ -v   # Python: 101개
flutter test       # Flutter: 5개
```

### F-3. docs/ 정리

```
docs/
├── claude_code_ontology_plan.md
├── claude_code_triple_plan.md
├── claude_code_graph_plan.md
├── claude_code_history_sqlite_plan.md
├── claude_code_debug_plan.md
└── session_log.md  ← 최종 상태 업데이트
```

---

## Phase G — 멀티 플랫폼 확장

Phase E·F 완료 후 진행.

### G-1. Android

```
G-1-1. 환경 확인
  flutter doctor -v → Android SDK, 에뮬레이터 확인

G-1-2. 설정 변경
  android/app/build.gradle: minSdkVersion 21
  AndroidManifest.xml: INTERNET 권한 추가

G-1-3. 반응형 UI
  화면 너비 < 600: NavigationRail → BottomNavigationBar
  app.dart AppShell 수정

G-1-4. 빌드 + 테스트
  flutter build apk --release
  에뮬레이터 또는 실기기 테스트
  설정 화면: http://PC의IP:9000 입력 → 연결 확인

G-1-5. 전체 기능 E-7 시나리오 반복 (Android)
```

### G-2. iOS

```
G-2-1. 환경 조건
  macOS + Xcode 필요 → Windows 환경에서는 불가
  → 추후 macOS 환경 확보 시 진행

G-2-2. 준비 사항 (미리 해둘 것)
  ios/Runner/Info.plist: NSPhotoLibraryUsageDescription 추가
  최소 버전: iOS 12.0+
```

### G-3. Web

```
G-3-1. 빌드 확인
  flutter build web
  → build/web/ 생성 확인

G-3-2. Web 특이사항
  - file_picker: Web에서 제한적 동작 (드래그앤드롭 필요)
  - 서버 주소: Web은 CORS 설정 필요
  - InteractiveViewer 터치 vs 마우스 동작 차이

G-3-3. FastAPI CORS 설정 추가
  main.py:
    from fastapi.middleware.cors import CORSMiddleware
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
    )

G-3-4. 빌드 + 로컬 서버로 테스트
  cd build/web && python -m http.server 8080
  브라우저: http://localhost:8080
```

---

## Phase H — git 정리 + PR

### H-1. 최종 테스트 통과 확인

```bash
cd E:/Oral-record-agent_v4.0
pytest tests/ -v          # 101/101 확인

cd flutter
flutter test              # 5/5 확인
flutter analyze           # No issues 확인
```

### H-2. 최종 커밋

```bash
cd E:/Oral-record-agent_v4.0
git add .
git commit -m "feat(v4.0): 전체 기능 구현 완료

백엔드:
  - 온톨로지 CRUDA + AI 생성 + 버전 확정
  - 트리플 추출 + 검토 + 확정 저장 (GraphDB)
  - SQLite 이력 관리 (구술기록 + 온톨로지 이벤트 + 세션)
  - FastAPI REST API 전체

Flutter:
  - 6탭 UI (온톨로지/트리플/지식그래프/기록/이력/설정)
  - Spring-Embedder 포스 레이아웃 지식그래프
  - 검색 노드 강조 (1.5배 + 노란 테두리)
  - Windows 빌드 확인

테스트: Python 101/101 · Flutter 5/5"
```

### H-3. PR 생성

```bash
git push origin feature/v4.0-knowledge-graph

# GitHub/GitLab 에서 PR 생성
제목: feat: v4.0 지식그래프 기능 전체 구현
베이스: main ← feature/v4.0-knowledge-graph

PR 설명:
  ## 주요 변경사항
  - 온톨로지 버전 관리 (Draft/Confirmed/Archived)
  - AI 온톨로지 자동 생성 + Draft 종합
  - 트리플 추출·검토·확정 파이프라인
  - 지식그래프 시각화 (ForceLayout + CustomPainter)
  - SQLite 기반 이력 관리
  - Flutter 6탭 UI (Windows 빌드 완료)

  ## 테스트
  - Python: 101/101 통과
  - Flutter: 5/5 통과
```

---

## 구현 우선순위 및 순서

```
지금 당장:
  E-1 ~ E-7  Windows 전체 기능 테스트
  (버그 발견 시 즉시 수정 → 재테스트)

E 완료 후:
  F-1  불필요 파일 제거
  F-2  README.md 작성
  F-3  docs/ 정리

F 완료 후:
  G-3  Web 빌드 + CORS 설정 (가장 빠름 — 추가 환경 불필요)
  G-1  Android 빌드 (Android Studio 필요)
  G-2  iOS (macOS 필요 — 나중에)

최종:
  H    git 정리 + PR
```

---

## 제약 조건

```
- Phase E 테스트 결과를 화면별로 보고 후 진행
- 버그 발견 시 해당 화면 수정 완료 후 다음 화면으로
- Phase F는 E 전체 통과 후 진행
- iOS는 macOS 환경 확보 후 별도 진행
- Web 빌드는 G-3-3 CORS 설정 없이는 API 호출 불가
```
