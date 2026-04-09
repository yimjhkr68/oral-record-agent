# 트리플 관리 기능 — Plan (PDCA 1단계)

## 전체 흐름

```
[Confirmed 온톨로지 선택]
        ↓
[구술기록 복수 선택]
  - 텍스트 직접 입력
  - 파일 업로드
  - Hive DB에서 가져오기
        ↓
[트리플 생성 실행]
  → 각 구술기록 content → AI 트리플 추출
  → 추출 결과 임시 저장 (미확정 상태)
        ↓
[관리자 검토]
  - 트리플별 수정 / 삭제 / 추가
  - 신뢰도(confidence) 조정
        ↓
[확정 저장]
  → GraphDB(data/triples/graph.json) 에 영구 저장
```

---

## 화면 구조

```
트리플 관리 (TripleScreen)
│
├── Step 1 탭: 추출 설정
│   ├── [온톨로지 선택] — Confirmed 버전만 드롭다운
│   ├── [구술기록 추가] 버튼
│   │   └── InputMethodBottomSheet (온톨로지와 동일한 3탭)
│   │       ├── 텍스트 직접 입력
│   │       ├── 파일 업로드 (.txt/.pdf/.docx)
│   │       └── Hive DB 선택
│   ├── 선택된 구술기록 목록
│   │   └── 레코드 카드 (제목/출처 · 텍스트 미리보기 · [삭제] 버튼)
│   └── [트리플 생성] 버튼 (온톨로지 + 기록 1개 이상 선택 시 활성)
│
├── Step 2 탭: 검토 및 수정  ← 생성 완료 후 자동 이동
│   ├── 상단 요약 바
│   │   └── 생성 N개 · 수정 N개 · 삭제 N개 · 추가 N개
│   ├── 트리플 목록 (미확정 상태)
│   │   └── 트리플 카드
│   │       ├── 주어 (타입 배지)
│   │       ├── 술어
│   │       ├── 목적어 (타입 배지)
│   │       ├── 신뢰도 슬라이더 (0.0 ~ 1.0)
│   │       ├── 출처 (어느 구술기록에서 나왔는지)
│   │       └── [수정] [삭제] 버튼
│   ├── [+ 트리플 직접 추가] 버튼
│   └── [전체 확정 저장] 버튼
│
└── Step 3 탭: 저장된 트리플 조회
    ├── 검색창 (주어/술어/목적어/출처)
    ├── 필터 (온톨로지 버전 · 상태 · 클래스 타입)
    ├── 트리플 테이블
    │   └── 행 클릭 → 상세/수정 패널
    └── [선택 아카이브] [선택 삭제] 버튼
```

---

## Step 1 — 추출 설정 상세 설계

### 온톨로지 선택

```dart
// Confirmed 버전만 필터링해서 드롭다운 표시
GET /api/ontologies/?status=confirmed

// 선택된 온톨로지 버전이 트리플 추출 프롬프트에 주입됨
// → 해당 버전의 클래스/속성만 사용
```

### 구술기록 입력 — 3가지 방법

#### 방법 A. 텍스트 직접 입력

```
TextArea 에 구술 텍스트 붙여넣기
제목(레코드ID) 직접 입력 (예: "2024-구술-001")
[추가] 버튼 → 선택 목록에 카드로 추가
복수 반복 가능
```

#### 방법 B. 파일 업로드

```
file_picker 로 복수 파일 선택 가능 (.txt/.pdf/.docx)
각 파일 → POST /api/triples/extract-text (텍스트 추출)
추출된 텍스트 → 선택 목록에 카드로 추가
파일명이 레코드ID로 자동 설정
```

#### 방법 C. Hive DB

```
GET /api/hive/records?query={query} → 레코드 목록
체크박스로 복수 선택
[선택 추가] → 선택 목록에 카드로 추가
record.id 가 레코드ID로 자동 설정
```

### 트리플 생성 실행

```
[트리플 생성] 버튼 클릭
  → 구술기록 N개를 순차 처리
  → 각 기록마다:
      POST /api/triples/extract
      body: {
        content: "구술 텍스트",
        ontology_version_id: "v1.0",
        source_record_id: "레코드ID"
      }
  → 진행 상황 표시:
      LinearProgressIndicator
      "3/5 처리 중... (구술기록 레코드ID)"
  → 전체 완료 → Step 2 탭 자동 이동
  → 생성된 트리플은 status="pending" 으로 임시 저장
     (기존 active/archived 에 pending 상태 추가)
```

---

## Step 2 — 검토 및 수정 상세 설계

### 트리플 카드 UI

```dart
TripleReviewCard {
  // 주어
  Row [
    ClassTypeBadge(color, label),  // 예: 🟡 Person
    Text(subject),
    EditIcon → 인라인 편집
  ]

  // 술어
  Center [ Text("── predicate ──▶") ]

  // 목적어
  Row [
    ClassTypeBadge(color, label),
    Text(object),
    EditIcon → 인라인 편집
  ]

  // 신뢰도
  Row [
    Text("신뢰도"),
    Slider(0.0 ~ 1.0, divisions: 10),
    Text("0.9")
  ]

  // 출처
  Text("출처: {source_record_id}", style: caption)

  // 액션
  Row [ [수정] [삭제] ]
}
```

### 트리플 직접 추가

```dart
AddTripleDialog {
  subject:      TextField + ClassTypeDropdown (현재 온톨로지 클래스 목록)
  predicate:    Dropdown (현재 온톨로지 속성 목록)
  object:       TextField + ClassTypeDropdown
  confidence:   Slider
  note:         TextField (메모)
  [추가] 버튼
}
```

### 인라인 수정

```
수정 아이콘 클릭 → 해당 카드가 편집 모드로 전환
  - subject / predicate / object TextField 활성
  - [저장] [취소] 버튼
  - 저장 클릭 → 임시 목록에서 수정 반영 (API 호출 아직 없음)
  - 확정 저장 시 일괄 처리
```

### 확정 저장

```
[전체 확정 저장] 버튼 클릭
  → 확인 다이얼로그
    "검토된 트리플 N개를 그래프 DB에 저장합니다."
    [확정]
  → pending 트리플 전체를 active 로 상태 변경
  → POST /api/triples/bulk-confirm
    body: { triple_ids: [...] }
  → data/triples/graph.json 에 자동 저장
  → Step 3 탭으로 이동
  → SnackBar: "트리플 N개가 저장됐습니다."
```

---

## Step 3 — 저장된 트리플 조회 상세 설계

### 검색 및 필터

```dart
// 검색
GET /api/triples/?q={query}&version={v}&status=active

// 필터 칩
Row [
  FilterChip("전체"),
  FilterChip("Person"),
  FilterChip("Place"),
  FilterChip("Event"),
  ...클래스별
]
```

### 트리플 테이블

```
컬럼: 주어(타입) | 술어 | 목적어(타입) | 신뢰도 | 온톨로지 버전 | 출처 | 상태
행 탭 → 우측 상세 패널 슬라이드인
  - 전체 필드 표시
  - [수정] → PATCH /api/triples/{id}
  - [아카이브] → POST /api/triples/{id}/archive
  - [삭제] → DELETE /api/triples/{id}
```

### 일괄 처리

```
체크박스 선택 → 하단 액션 바 등장
  [선택 아카이브] → 일괄 아카이브
  [선택 삭제] → 확인 후 삭제
  선택 N개 표시
```

---

## 백엔드 추가 API

```python
# api/router_triple.py 에 추가

POST /api/triples/bulk-confirm
  body: { triple_ids: list[str] }
  → pending → active 상태 변경
  → GraphDB 저장

GET /api/triples/?q=&version=&status=
  → status 파라미터에 "pending" 추가 지원

# graph/triple_manager.py 에 추가
def bulk_confirm(triple_ids: list[str]) -> dict:
    """pending → active 일괄 전환 + GraphDB 저장"""
```

### TripleStatus 확장

```python
# graph/triple_manager.py
class TripleStatus(str, Enum):
    PENDING  = "pending"   # ← 신규: 검토 대기 중
    ACTIVE   = "active"    # 확정 저장됨
    ARCHIVED = "archived"  # 아카이브
```

---

## 파일 구조 (신규 생성)

```
flutter/lib/
├── screens/triple/
│   ├── triple_screen.dart              ← Step 1/2/3 탭 컨테이너
│   ├── triple_step1_extract.dart       ← 추출 설정 (F1)
│   ├── triple_step2_review.dart        ← 검토 및 수정 (F2)
│   ├── triple_step3_list.dart          ← 저장된 트리플 조회 (F3)
│   ├── triple_review_card.dart         ← 검토 카드 위젯
│   └── add_triple_dialog.dart          ← 트리플 직접 추가 다이얼로그
│
├── providers/
│   └── triple_provider.dart            ← 상태관리
│       TripleNotifier:
│         - selectedOntologyVersion
│         - sourceRecords: List<SourceRecord>   ← 입력된 구술기록
│         - pendingTriples: List<Triple>         ← 검토 대기
│         - isExtracting: bool
│         - extractProgress: (current, total)
│
└── api/
    └── triple_api.dart                 ← API 호출
        - extractTriples(content, versionId, sourceId)
        - bulkConfirm(tripleIds)
        - searchTriples(query, version, status)
        - updateTriple(id, fields)
        - archiveTriple(id)
        - deleteTriple(id)
```

---

## 구현 순서 (Do 단계)

```
Phase B-1: Step 1 — 추출 설정 화면
  - Confirmed 온톨로지 드롭다운
  - 텍스트 직접 입력 탭 (3탭 중 먼저)
  - 선택된 구술기록 카드 목록
  - [트리플 생성] 버튼 + 진행 상황 표시

Phase B-2: Step 2 — 검토 및 수정
  - 트리플 카드 목록
  - 인라인 수정
  - 트리플 직접 추가 다이얼로그
  - 신뢰도 슬라이더
  - [전체 확정 저장]

Phase B-3: 백엔드 — pending 상태 + bulk-confirm API
  - TripleStatus.PENDING 추가
  - POST /api/triples/bulk-confirm 구현

Phase B-4: Step 3 — 저장된 트리플 조회
  - 검색 + 필터
  - 트리플 테이블
  - 상세 패널 + 수정/아카이브/삭제

Phase B-5: 파일 업로드 + Hive DB 탭 추가 (Phase A-3 패턴 재사용)
```

---

## 완료 기준 (Check 기준)

```
Phase B-1:
  □ Confirmed 온톨로지 드롭다운에 v1.0 표시
  □ 텍스트 입력 후 [트리플 생성] 클릭 → 진행 바 표시
  □ 생성 완료 후 Step 2로 자동 이동

Phase B-2:
  □ 생성된 트리플 카드 목록 표시
  □ 인라인 수정 후 임시 반영
  □ [전체 확정 저장] → GraphDB 저장 확인
     (data/triples/graph.json 파일 변경 확인)

Phase B-3:
  □ pending 상태 트리플이 graph.json 에 저장되지 않음
  □ bulk-confirm 후 active 로 전환 + graph.json 반영

Phase B-4:
  □ 저장된 트리플 목록 표시
  □ 검색어 입력 → 필터링 동작
  □ 수정/아카이브/삭제 동작
```

---

## 제약 조건

```
- Phase B-1 완료 확인 후 B-2 시작 (단계별 승인)
- pending 트리플은 graph.json 에 저장하지 않음
  (확정 저장 시에만 graph.json 기록)
- 파일 업로드/Hive DB 탭은 Phase B-5 에서 별도 진행
- 백엔드 기존 파일 최소 수정
  (TripleStatus enum 확장 + bulk-confirm API 추가만)
```

---

## Plan 검토 후 보고 요청

```
1. pending 트리플 임시 저장 위치 확인
   → 메모리(Flutter state)만으로 충분한지
   → 앱 종료 후에도 유지해야 하는지 (shared_preferences 사용 여부)

2. 트리플 검토 화면에서 온톨로지 클래스/속성 드롭다운 제공 여부
   → 수정 시 자유 텍스트 입력 vs 온톨로지 기반 선택

3. 위 Plan 중 변경이 필요한 부분

보고 후 승인하면 Phase B-1부터 시작.
```
