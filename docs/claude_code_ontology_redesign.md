# 온톨로지 관리 화면 재설계 Plan

## 변경 방향

```
제거: "공표 온톨로지" 탭 + 관련 API
교체: 3탭 구조로 전면 재설계

작업 중 탭  → Draft 온톨로지 목록 + 종합 기능
표준화 탭   → 외부 표준 온톨로지 클래스 매핑 초안
확정 탭     → Confirmed(활성) + Archived 구분 표시

공통: 모든 탭에서 온톨로지 이름 변경 가능
```

---

## 탭 구조 상세

```
온톨로지 관리
├── [작업 중]   Draft 상태 버전들
├── [표준화]    외부 표준 매핑 초안 (Draft 중 standard_tag 있는 것)
└── [확정]      Confirmed(활성) + Archived 구분
```

---

## 탭별 화면 설계

### [작업 중] 탭

```
┌────────────────┬──────────────────────────────────────────┐
│ Draft 목록     │ 상세 패널                                 │
│                │                                          │
│ [+ 새 버전]    │ draft-20260409  [이름변경✎] [확정] [삭제]│
│ [구술기록으로  │ AI 자동 생성 (샘플 기반)                  │
│  생성]         │ 생성일: 2026-04-09 · 클래스 17개 · 속성 22개│
│                ├──────────────────────────────────────────┤
│ [선택종합(2개)]│ [클래스 (17)]        [속성 (22)]         │
│                │                                          │
│ □ draft-001    │  ● Person (인물)              ✎ 🗑       │
│   Draft        │    구술의 주체가 되는 사람               │
│                │    foaf:Person · cidoc:E21_Person         │
│ ☑ draft-002    │                                          │
│   Draft        │  ● Survivor (생존자)          ✎ 🗑       │
│                │    ...                                   │
│ ☑ draft-003    │                                          │
│   Draft        │  [+ 클래스 추가]                         │
│                │                                          │
│                │  [+ 속성 추가]                           │
└────────────────┴──────────────────────────────────────────┘
```

기능:
- Draft 목록 + 체크박스 (종합 선택)
- 버전명 옆 ✎ 클릭 → 인라인 이름 편집
- [구술기록으로 생성] → 기존 InputMethodBottomSheet
- [선택 종합 (N개)] → 종합 다이얼로그 (이름 직접 입력)
- 클래스/속성 추가·수정·삭제 (Draft만)

---

### [표준화] 탭

```
┌────────────────┬──────────────────────────────────────────┐
│ 매핑 초안 목록 │ 표준화 상세                               │
│                │                                          │
│ standard-v1    │ standard-v1  [이름변경✎] [확정] [삭제]  │
│   Draft        │                                          │
│                │  클래스별 표준 태그 매핑                  │
│                │ ┌─────────────────────────────────────┐ │
│                │ │ Person  →  foaf:Person               │ │
│                │ │           cidoc:E21_Person           │ │
│                │ │           schema:Person   [편집]     │ │
│                │ ├─────────────────────────────────────┤ │
│                │ │ Place   →  cidoc:E53_Place           │ │
│                │ │           schema:Place    [편집]     │ │
│                │ └─────────────────────────────────────┘ │
│                │                                          │
│                │  [표준 태그 자동 적용]                   │
│                │  (CIDOC-CRM · FOAF · Dublin Core 기반)  │
└────────────────┴──────────────────────────────────────────┘
```

기능:
- Draft 중 standard_tag 가 있는 버전 표시
- 클래스별 표준 태그 편집 (멀티 태그)
- [표준 태그 자동 적용] → STANDARD_CLASS_TAGS 일괄 적용
- 버전명 변경 가능

---

### [확정] 탭

```
┌────────────────┬──────────────────────────────────────────┐
│                │                                          │
│ ● 활성 (2)     │ v2.0  [이름변경✎] [아카이브]            │
│ v2.0  Confirmed│ 확정일: 2026-04-09                      │
│ v1.0  Confirmed│ 클래스 19개 · 속성 24개                  │
│                │                                          │
│ ─────────────  │ [클래스 (19)]     [속성 (24)]            │
│                │                                          │
│ ○ 아카이브 (1) │  ● Person (인물)                        │
│ test  Archived │    foaf:Person · cidoc:E21_Person        │
│                │    [종합 원칙 리포트 보기 ▼]             │
└────────────────┴──────────────────────────────────────────┘
```

기능:
- 활성(Confirmed) / 아카이브(Archived) 섹션 구분
- 활성: [아카이브] 버튼 표시
- 아카이브: 읽기 전용 (버튼 없음)
- 버전명 변경 가능 (활성만)
- 종합 원칙 리포트 접기/펼치기

---

## 이름 변경 기능 (공통)

```dart
// 모든 탭의 버전 헤더에 적용

Row(children: [
  // 이름 표시 / 편집 전환
  _isEditingName
    ? SizedBox(
        width: 200,
        child: TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _saveName(),
        ),
      )
    : Text(version.versionId,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),

  // 편집 아이콘
  IconButton(
    icon: Icon(_isEditingName ? Icons.check : Icons.edit_outlined, size: 18),
    tooltip: _isEditingName ? '저장' : '이름 변경',
    onPressed: _isEditingName ? _saveName : _startEdit,
  ),
])
```

### 백엔드 이름 변경 API

```python
# api/router_ontology.py 에 추가

PATCH /api/ontologies/{version_id}/rename
  body: { "new_version_id": "새이름" }
  → 파일명 변경 + 메모리 업데이트
  → 이력 기록: "renamed" 이벤트
  → 이 버전을 참조하는 트리플의 ontology_version 필드도 업데이트
```

---

## 백엔드 변경

### 제거

```
api/router_ontology.py 에서:
  GET /api/ontologies/public    ← 삭제
  POST /api/ontologies/publish  ← 삭제 (있으면)

Flutter 에서:
  "공표 온톨로지" 관련 API 호출 코드 전체 삭제
```

### 추가

```python
# api/router_ontology.py

PATCH /api/ontologies/{version_id}/rename
  body: { "new_version_id": "새이름" }

GET /api/ontologies/?status=draft     → 작업 중 탭
GET /api/ontologies/?status=confirmed → 확정 탭 (활성)
GET /api/ontologies/?status=archived  → 확정 탭 (아카이브)
GET /api/ontologies/?has_standard_tag=true → 표준화 탭

# ontology_manager.py
def rename(self, version_id: str, new_version_id: str) -> OntologyVersion:
    """
    버전 ID 변경.
    - 파일 rename
    - 메모리 업데이트
    - SQLite ontology_events 이력 기록
    - 중복 ID 시 ValueError
    """
```

---

## Flutter 파일 변경

```
수정:
  flutter/lib/screens/ontology/
    ontology_list_screen.dart     ← 3탭 구조로 전면 교체
    ontology_detail_panel.dart    ← 이름 변경 + 탭별 버튼 조건 추가

신규:
  flutter/lib/screens/ontology/
    ontology_working_tab.dart     ← [작업 중] 탭
    ontology_standard_tab.dart    ← [표준화] 탭
    ontology_confirmed_tab.dart   ← [확정] 탭

수정:
  flutter/lib/api/ontology_api.dart
    → renameOntology() 추가
    → listByStatus() 파라미터 추가

수정:
  flutter/lib/providers/ontology_provider.dart
    → 탭별 상태 분리
```

---

## 구현 순서

```
Phase 1 — 백엔드
  1-1. 공표 API 제거 (router_ontology.py)
  1-2. rename API 추가 (ontology_manager.py + router)
  1-3. status 필터 파라미터 추가
  1-4. pytest 통과 확인

Phase 2 — Flutter 기본 구조
  2-1. ontology_list_screen.dart 3탭 구조로 교체
       (TabBar: 작업 중 / 표준화 / 확정)
  2-2. 각 탭 기본 화면 뼈대 생성
  2-3. flutter run -d windows 실행 확인

Phase 3 — [작업 중] 탭 완성
  3-1. Draft 목록 + 체크박스
  3-2. 이름 변경 인라인 편집
  3-3. [구술기록으로 생성] 기존 기능 연결
  3-4. [선택 종합] 기존 기능 연결 (이름 입력 다이얼로그 포함)
  3-5. 클래스/속성 편집 기존 기능 연결

Phase 4 — [표준화] 탭 완성
  4-1. standard_tag 있는 Draft 필터링
  4-2. 클래스별 표준 태그 표시 + 편집
  4-3. [표준 태그 자동 적용] 버튼

Phase 5 — [확정] 탭 완성
  5-1. Confirmed / Archived 섹션 구분
  5-2. 활성: [아카이브] 버튼
  5-3. 종합 원칙 리포트 접기/펼치기
  5-4. 이름 변경 (활성만)

Phase 6 — 테스트
  □ 작업 중: Draft 생성 → 이름 변경 → 종합 → 확정
  □ 표준화: 표준 태그 자동 적용 → 태그 편집
  □ 확정: 활성/아카이브 구분 표시 → 아카이브 처리
  □ 모든 탭에서 이름 변경 동작
  □ pytest 101/101 통과
```

---

## 완료 기준

```
Phase 1:
  □ GET /api/ontologies/public → 404 (제거 확인)
  □ PATCH /api/ontologies/{id}/rename → 200
  □ GET /api/ontologies/?status=draft → Draft 목록

Phase 2~5:
  □ 탭 3개 전환 동작
  □ 모든 탭 이름 변경 (✎ 클릭 → 입력 → Enter → 저장)
  □ [작업 중] Draft 생성·종합·삭제 동작
  □ [표준화] 태그 자동 적용 동작
  □ [확정] 활성/아카이브 섹션 구분 표시
```

---

## 제약 조건

```
- Phase 1 완료 후 Phase 2 시작 (단계별 승인)
- 기존 Draft CRUDA 기능 유지 (작업 중 탭으로 이동)
- 이름 변경 시 해당 버전 참조 트리플의
  ontology_version 필드도 함께 업데이트
- Confirmed/Archived 는 이름 변경 외 수정 불가 유지
- 표준화 탭은 Draft 상태만 편집 가능
  (Confirmed 버전은 읽기 전용)
```
