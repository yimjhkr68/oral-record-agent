# 온톨로지 관리 기능 — Plan (PDCA 1단계)

## 목표 기능 4가지

```
F1. 온톨로지 버전 관리     — 버전 목록 조회, 상태(Draft/Confirmed/Archived) 관리
F2. 드래프트 CRUDA        — 클래스·속성 직접 생성·수정·삭제·아카이브·확정
F3. 구술기록 입력          — 파일업로드 / 텍스트입력 / Hive DB API → AI 온톨로지 초안 생성
F4. 드래프트 종합          — 복수 Draft 선택 → AI 종합 → 새 Draft 생성
```

---

## 화면 구조

```
온톨로지 관리 (OntologyListScreen)
│
├── 좌측 패널: 버전 목록
│   ├── [+ 새 버전] 버튼
│   ├── [구술기록으로 생성] 버튼        ← F3
│   ├── [선택 Draft 종합] 버튼          ← F4 (Draft 2개 이상 선택 시 활성)
│   └── 버전 카드 목록
│       ├── □ 체크박스 (종합 선택용)
│       ├── 버전ID
│       ├── 상태 배지 (Draft/Confirmed/Archived)
│       └── 생성일
│
└── 우측 패널: 버전 상세 (OntologyDetailPanel)
    ├── 버전 헤더 (ID + 상태 + 설명)
    ├── [확정하기] / [아카이브] 버튼 (상태에 따라)
    ├── 클래스 섹션
    │   ├── 클래스 카드 목록 (색상 · 이름 · 설명 · 예시)
    │   └── [+ 클래스 추가] (Draft만)
    └── 속성 섹션
        ├── 속성 카드 목록 (이름 · 도메인→범위 · 설명)
        └── [+ 속성 추가] (Draft만)
```

---

## F1 — 버전 관리 상세 설계

### 상태 전환 규칙

```
Draft ──[확정하기]──▶ Confirmed ──[아카이브]──▶ Archived
  │                                                  │
  └──[삭제]──▶ (삭제됨)              (조회만 가능, 수정 불가)
```

### API 매핑

```
GET    /api/ontologies/                  → 버전 목록
GET    /api/ontologies/{version_id}      → 버전 상세
POST   /api/ontologies/                  → 새 Draft 생성
POST   /api/ontologies/{id}/confirm      → Confirmed 전환
POST   /api/ontologies/{id}/archive      → Archived 전환
DELETE /api/ontologies/{id}             → Draft 삭제
```

### UI 동작 규칙

```
Confirmed / Archived 선택 시:
  - 클래스·속성 편집 UI 숨김
  - [확정하기] 버튼 숨김
  - [아카이브] 버튼: Confirmed 만 표시
  - 전체 읽기 전용 표시

Draft 선택 시:
  - 클래스·속성 편집 UI 표시
  - [확정하기] 버튼 표시
  - 확정 클릭 → 확인 다이얼로그 ("확정 후 수정 불가합니다")
```

---

## F2 — 드래프트 CRUDA 상세 설계

### 클래스 CRUDA

```dart
// 클래스 카드 구성 요소
OntologyClassCard {
  color:       ColorPicker (원형 색상 선택)
  name:        TextField (영문 PascalCase)
  label_ko:    TextField (한국어 레이블)
  description: TextField (정의)
  examples:    ChipInput  (예: 추가/삭제)
  actions:     [수정] [삭제]
}
```

### 속성 CRUDA

```dart
// 속성 카드 구성 요소
OntologyPredicateCard {
  name:        TextField (한국어 동사형)
  domain:      MultiSelect (허용 주어 클래스 — 현재 버전의 클래스 목록에서 선택)
  range_:      MultiSelect (허용 목적어 클래스)
  description: TextField (의미 설명)
  actions:     [수정] [삭제]
}
```

### API 매핑

```
PATCH  /api/ontologies/{id}   body: {classes: [...], predicates: [...]}
  → Draft 전체 업데이트 (클래스/속성 목록 교체)
  → 개별 클래스/속성 CRUD 는 프론트에서 목록 편집 후 일괄 PATCH
```

---

## F3 — 구술기록 입력 상세 설계

### 입력 방법 3가지

#### 방법 A — 텍스트 직접 입력

```
[구술기록으로 생성] 버튼 클릭
  → BottomSheet 또는 Dialog
  → 탭: [텍스트 입력] [파일 업로드] [Hive DB]
  → [텍스트 입력] 탭:
      TextArea (구술 텍스트 붙여넣기)
      base_version_id 선택 (선택 사항 — 기존 버전 기반 확장)
      [AI 초안 생성] 버튼
        → POST /api/ontologies/generate
          body: { sample_text, base_version_id }
        → 로딩 인디케이터
        → 새 Draft 생성 → 목록에 추가 → 자동 선택
```

#### 방법 B — 파일 업로드

```
[파일 업로드] 탭:
  file_picker 패키지로 파일 선택
  지원 형식: .txt / .pdf / .docx / .hwp
  파일 내용 추출 후 텍스트로 변환
    → txt: 직접 읽기
    → pdf: flutter_pdfview 또는 서버 파싱 API 호출
    → docx/hwp: 서버에 파일 업로드 후 텍스트 추출

  API 추가 필요:
    POST /api/ontologies/extract-text
      body: multipart/form-data (file)
      return: { text: "추출된 텍스트" }

  추출 완료 후 → 텍스트 입력 탭과 동일한 흐름으로 진행
```

#### 방법 C — Hive DB API

```
[Hive DB] 탭:
  서버 연결 설정 (v3.0 Hive DB API 엔드포인트)
  레코드 ID 또는 쿼리 입력
  [불러오기] 버튼
    → GET /api/hive/records?query={query}
      (기존 hive_pipeline.py 활용)
    → 레코드 목록 표시 (ID, narrator_name, 날짜)
    → 레코드 선택 → content 필드 추출
    → [AI 초안 생성] 버튼 → 동일 흐름

  API 추가 필요:
    GET /api/hive/records           → 레코드 목록
    GET /api/hive/records/{id}      → 단건 조회
    GET /api/hive/records/{id}/content → content 필드만 반환
```

### 입력 방법 선택 UI

```dart
// BottomSheet 구조
InputMethodBottomSheet {
  TabBar: [텍스트 입력 | 파일 업로드 | Hive DB]

  공통 하단:
    base_version_id 드롭다운 ("기존 버전 기반으로 확장" 선택 가능)
    [AI 초안 생성] 버튼 (비활성 → 입력 완료 시 활성)
    로딩: CircularProgressIndicator + "AI가 온톨로지를 분석 중입니다..."

  완료 후:
    SnackBar: "Draft {version_id} 가 생성됐습니다."
    좌측 목록 자동 갱신 + 새 Draft 자동 선택
}
```

---

## F4 — 드래프트 종합 상세 설계

### UI 흐름

```
1. 좌측 목록에서 Draft 2개 이상 체크박스 선택
   → [선택 Draft 종합] 버튼 활성

2. 버튼 클릭 → 확인 다이얼로그
   "선택한 Draft 3개를 AI로 종합합니다.
    새 버전ID: [v2.0    ] (입력 가능)
    [종합 시작]"

3. POST /api/ontologies/merge
   body: {
     version_ids: ["draft-xxx", "draft-yyy", "draft-zzz"],
     new_version_id: "v2.0",
     description: "Draft 3개 종합"
   }

4. 로딩 → 완료
   → 새 Draft 목록에 추가
   → 자동 선택 → 우측에 종합 결과 표시

5. 사용자가 결과 검토 후
   → 필요시 추가 편집 (클래스/속성 수정·삭제·추가)
   → [확정하기] 로 Confirmed 전환
```

### 백엔드 추가 API

```python
# api/router_ontology.py 에 추가
POST /api/ontologies/merge
  body: {
    version_ids: list[str],
    new_version_id: str,
    description: str = ""
  }

# ontology/ontology_manager.py 에 추가
def merge_drafts(
    version_ids: list[str],
    new_version_id: str,
    description: str = ""
) -> OntologyVersion:
    """
    1. 지정 Draft 들의 classes + predicates 수집
    2. name 기준 1차 중복 제거
    3. AI 호출 — 의미 중복 제거 + 정리 + 누락 보완
    4. 새 Draft 저장 후 반환
    """

# merge AI 프롬프트
"""
다음은 여러 구술기록 샘플에서 각각 추출된 온톨로지 초안들입니다.
이를 하나의 통합 온톨로지로 정리해주세요.

작업:
1. 동일하거나 유사한 클래스/속성 통합 (가장 적절한 이름 선택)
2. 구술기록 도메인에 불필요한 항목 제거
3. 빠진 중요 항목 보완
4. 클래스 간 관계가 속성에 반영되었는지 확인

{merged_json}

JSON 형식으로만 응답하세요.
"""
```

---

## 파일 구조 (신규 생성)

```
flutter/lib/
├── screens/ontology/
│   ├── ontology_list_screen.dart      ← 좌우 분할 레이아웃
│   ├── ontology_detail_panel.dart     ← 우측 상세/편집 패널
│   ├── ontology_class_card.dart       ← 클래스 카드 위젯
│   ├── ontology_predicate_card.dart   ← 속성 카드 위젯
│   └── input_method_bottom_sheet.dart ← 구술기록 입력 (F3)
│
├── providers/
│   └── ontology_provider.dart         ← 상태관리
│       StateNotifier:
│         - versions: List<OntologyVersion>
│         - selectedVersion: OntologyVersion?
│         - selectedForMerge: Set<String>  ← 종합 선택 목록
│         - isLoading: bool
│         - error: String?
│
└── api/
    └── ontology_api.dart              ← API 호출 메서드
        - listVersions()
        - getVersion(id)
        - createDraft(versionId, description)
        - updateDraft(id, classes, predicates)
        - deleteDraft(id)
        - confirm(id)
        - archive(id)
        - generateFromInput(text, baseVersionId)  ← F3
        - mergeDrafts(ids, newVersionId)           ← F4
        - extractTextFromFile(file)                ← F3-B
        - getHiveRecords(query)                    ← F3-C
        - getHiveContent(recordId)                 ← F3-C
```

---

## 구현 순서 (Do 단계)

```
Phase A-1: 버전 목록 + 상세 읽기 (F1 조회)
  - GET /api/ontologies/ → 목록 표시
  - 버전 클릭 → GET /api/ontologies/{id} → 우측 상세
  - 상태 배지 색상: Draft=주황, Confirmed=초록, Archived=회색

Phase A-2: Draft CRUDA (F2)
  - [+ 새 버전] → 버전ID 입력 다이얼로그 → POST
  - 클래스 추가/수정/삭제 → PATCH
  - 속성 추가/수정/삭제 → PATCH
  - [확정하기] → 확인 다이얼로그 → POST /confirm
  - [아카이브] → POST /archive
  - [삭제] → DELETE (Draft만)

Phase A-3: 구술기록 입력 (F3)
  - 텍스트 입력 탭 먼저 구현
  - 파일 업로드 탭 (txt → pdf → docx 순)
  - Hive DB 탭 마지막

Phase A-4: 드래프트 종합 (F4)
  - 체크박스 선택 UI
  - [선택 Draft 종합] 버튼 + 다이얼로그
  - POST /api/ontologies/merge 백엔드 구현 포함

Phase A-5: 통합 테스트
  - 전체 플로우: 구술기록 입력 → Draft 생성 → 편집 → 종합 → 확정
```

---

## 완료 기준 (Check 기준)

```
Phase A-1:
  □ 온톨로지 목록이 FastAPI 에서 불러와서 표시되는가
  □ 버전 클릭 시 클래스/속성 목록이 우측에 표시되는가
  □ 상태 배지가 올바른 색상으로 표시되는가

Phase A-2:
  □ 새 Draft 생성 후 목록에 즉시 반영되는가
  □ 클래스 추가 → 저장 → 다시 불러올 때 유지되는가
  □ Confirmed 선택 시 편집 UI가 숨겨지는가
  □ 확정 후 Draft 수정 시도 → PermissionError 응답 처리

Phase A-3:
  □ 텍스트 입력 → AI 생성 → 새 Draft 목록 추가
  □ 파일 업로드 → 텍스트 추출 → AI 생성 동작
  □ Hive DB 연결 → 레코드 선택 → AI 생성 동작

Phase A-4:
  □ Draft 2개 이상 선택 시 [종합] 버튼 활성
  □ 종합 완료 후 새 Draft 생성 + 자동 선택
  □ 종합 결과에 선택한 Draft들의 클래스/속성이 통합되어 있는가
```

---

## 제약 조건

```
- Phase A-1 완료 확인 후 A-2 시작 (단계별 승인)
- F3 파일 업로드: txt 먼저, pdf/docx 는 별도 확인 후 진행
- F3 Hive DB: v3.0 저장소 접근 방식 별도 확인 필요
  (API 엔드포인트 / 인증 방식 / 컬럼명)
- F4 종합 기능은 백엔드 merge API 와 동시 구현
  (프론트만 만들어도 동작 안 됨)
- Flutter 코드는 flutter/ 폴더 안에만 작성
- FastAPI 백엔드 수정은 api/ 폴더와 ontology/ 폴더만
```

---

## Plan 검토 후 보고 요청

```
1. Hive DB 연결 방식 확인
   → v3.0 API 엔드포인트 주소와 인증 방식
   → content 필드 컬럼명

2. 파일 업로드 지원 형식 우선순위 확인
   → txt / pdf / docx / hwp 중 먼저 지원할 순서

3. 위 Plan 중 변경이 필요한 부분

보고 후 승인하면 Phase A-1 부터 시작.
```
