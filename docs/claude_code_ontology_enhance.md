# 온톨로지 기능 개선 + 버그 수정 Plan

## 작업 목록

```
Bug 1. 온톨로지 종합 500 오류           → 수정
Bug 2. 트리플 확정 후 블랙 화면          → 수정 (반복 버그)

F1. 종합 결과 온톨로지 이름 직접 입력
F2. 온톨로지 JSON 다운로드 (Draft 포함)
F3. 종합 원칙 및 결과 리포트 표시
F4. 표준 온톨로지 태그 부여
    (구술 특화: FOAF, Dublin Core, Schema.org, CIDOC-CRM)
```

---

## Bug 1 — 온톨로지 종합 500 오류

### 원인 파악 순서

```
1. FastAPI 서버 터미널에서 traceback 전체 확인
   → 마지막 줄 오류 메시지를 나에게 보고

2. 아래 파일 전체 내용 나에게 보여줘:
   - ontology/ontology_manager.py → merge_drafts() 메서드
   - api/router_ontology.py → POST /api/ontologies/merge 엔드포인트
```

### 수정 — ontology_manager.py

```python
# merge_drafts() 전체 방어 코드 적용

def merge_drafts(self, version_ids: list[str],
                 new_version_id: str,
                 description: str = "") -> OntologyVersion:

    # 1. 대상 Draft 수집
    drafts = []
    for vid in version_ids:
        try:
            v = self.get(vid)
            drafts.append(v)
        except KeyError:
            raise ValueError(f"버전을 찾을 수 없습니다: {vid}")

    # 2. 클래스/속성 1차 수집 (중복 포함)
    all_classes    = [c for d in drafts for c in d.classes]
    all_predicates = [p for d in drafts for p in d.predicates]

    # 3. AI 종합 호출
    merged_classes, merged_predicates = self._ai_merge(
        all_classes, all_predicates, version_ids
    )

    # 4. 새 Draft 생성
    new_version = OntologyVersion(
        version_id=new_version_id,
        status=OntologyStatus.DRAFT,
        classes=merged_classes,
        predicates=merged_predicates,
        description=description or f"AI 종합 병합 ({', '.join(version_ids)})",
        based_on=version_ids[0] if version_ids else None,
    )
    self._store.save_draft(new_version)

    # 5. 이력 기록 (실패해도 merge 자체는 성공)
    try:
        self._history.record_ontology_event(
            event_type="merged",
            version_id=new_version_id,
            detail=f"Draft {version_ids} 종합 → 클래스 {len(merged_classes)}개, 속성 {len(merged_predicates)}개",
        )
    except Exception as e:
        import logging
        logging.getLogger(__name__).warning(f"이력 기록 실패 (무시): {e}")

    return new_version


def _ai_merge(self, classes, predicates, source_ids) -> tuple:
    """AI 종합 + 방어적 파싱"""
    prompt = self._build_merge_prompt(classes, predicates, source_ids)

    message = self.client.messages.create(
        model="claude-opus-4-6",
        max_tokens=4096,
        system=MERGE_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    text = "".join(b.text for b in message.content if hasattr(b, "text"))
    clean = text.replace("```json", "").replace("```", "").strip()

    try:
        parsed = json.loads(clean)
    except json.JSONDecodeError as e:
        raise ValueError(f"AI 응답 파싱 실패: {e}\n응답 앞부분: {clean[:300]}")

    # 알려진 필드만 필터링 (note 등 예상 외 필드 허용)
    allowed_class = {'name','label_ko','color','description','examples','note',
                     'standard_tag','merge_note'}
    allowed_pred  = {'name','domain','range_','description','note',
                     'standard_tag','merge_note'}

    merged_classes = []
    for c in parsed.get("classes", []):
        if not isinstance(c, dict): continue
        filtered = {k: v for k, v in c.items() if k in allowed_class}
        try:
            merged_classes.append(OntologyClass(**filtered))
        except TypeError:
            pass  # 필수 필드 없으면 건너뜀

    merged_predicates = []
    for p in parsed.get("predicates", []):
        if not isinstance(p, dict): continue
        filtered = {k: v for k, v in p.items() if k in allowed_pred}
        try:
            merged_predicates.append(OntologyPredicate(**filtered))
        except TypeError:
            pass

    return merged_classes, merged_predicates
```

---

## Bug 2 — 트리플 확정 후 블랙 화면 (반복 버그)

### 원인

```
flutter/lib/screens/triple/triple_step2_review.dart 의
[전체 확정 저장] onPressed 콜백에서:
  - async 완료 후 mounted 체크 없이 setState() 호출
  - 또는 dispose된 위젯에서 context 접근
```

### 수정 — triple_step2_review.dart

```dart
Future<void> _confirmAndSave() async {
  // 1. 로딩 상태 (mounted 체크)
  if (!mounted) return;
  setState(() => _isSaving = true);

  try {
    // 2. pending 트리플 ID 목록을 async 전에 로컬 변수로 복사
    final ids = List<String>.from(
        ref.read(tripleProvider).pendingTriples.map((t) => t.id));
    final rejected = _rejectedCount;
    final modified = _modifiedCount;

    // 3. API 호출
    await ref.read(tripleApiProvider).bulkConfirm(
      tripleIds: ids,
      rejectedCount: rejected,
      modifiedCount: modified,
      sessionId: _sessionId,
    );

    // 4. async gap 이후 반드시 mounted 체크
    if (!mounted) return;

    // 5. provider 상태 초기화
    ref.read(tripleProvider.notifier).clearPending();

    // 6. Step 3 이동 — setState 후 build 주기에서 처리
    setState(() {
      _isSaving = false;
      _currentStep = 2;   // Step 3 (0-index)
    });

  } catch (e) {
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('저장 실패: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
```

### triple_step3_list.dart 안전 처리

```dart
@override
void initState() {
  super.initState();
  // build 완료 후 로드 (initState에서 직접 setState 금지)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _loadTriples();
  });
}

Future<void> _loadTriples() async {
  if (!mounted) return;
  setState(() => _isLoading = true);
  try {
    final result = await ref.read(tripleApiProvider).searchTriples();
    if (!mounted) return;
    setState(() { _triples = result; _isLoading = false; });
  } catch (e) {
    if (!mounted) return;
    setState(() { _triples = []; _isLoading = false; _error = '$e'; });
  }
}
```

---

## F1 — 종합 결과 온톨로지 이름 직접 입력

### 현재 문제

```
종합 버튼 클릭 시 version_id 가 자동 생성됨 (merged-타임스탬프)
→ 사용자가 의미 있는 이름을 붙일 수 없음
```

### 수정 — Flutter MergeDialog

```dart
// ui 변경: _showMergeDialog() 에 이름 입력 필드 추가

showDialog(
  child: AlertDialog(
    title: const Text('Draft 종합'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 선택된 Draft 목록 표시
        Text('선택된 Draft: ${_selectedIds.join(", ")}'),
        const SizedBox(height: 16),

        // 버전 ID 직접 입력 (필수)
        TextField(
          controller: _versionIdCtrl,
          decoration: const InputDecoration(
            labelText: '새 버전 ID (필수)',
            hintText: '예: v2.0, oral-history-v2, 제주4·3-v1',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),

        // 설명 입력 (선택)
        TextField(
          controller: _descCtrl,
          decoration: const InputDecoration(
            labelText: '설명 (선택)',
            hintText: '예: 제주 4·3 구술 샘플 3개 종합',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),

        // 빈 값일 때 자동 생성 안내
        const Text(
          '* 버전 ID를 비워두면 자동으로 생성됩니다.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _executeMerge(
            versionId: _versionIdCtrl.text.trim(),
            description: _descCtrl.text.trim(),
          );
        },
        child: const Text('종합 시작'),
      ),
    ],
  ),
);
```

---

## F2 — 온톨로지 JSON 다운로드

### 백엔드 추가 API

```python
# api/router_ontology.py 에 추가

from fastapi.responses import JSONResponse
import json

@router.get("/{version_id}/download")
def download_ontology(version_id: str):
    """온톨로지 JSON 파일 다운로드 (Draft 포함 전체)"""
    version = ontology_manager.get(version_id)
    data = {
        "version_id":   version.version_id,
        "status":       version.status.value,
        "description":  version.description,
        "created_at":   version.created_at,
        "confirmed_at": version.confirmed_at,
        "based_on":     version.based_on,
        "classes": [
            {
                "name":         c.name,
                "label_ko":     c.label_ko,
                "color":        c.color,
                "description":  c.description,
                "examples":     c.examples,
                "standard_tag": getattr(c, 'standard_tag', ''),
            }
            for c in version.classes
        ],
        "predicates": [
            {
                "name":         p.name,
                "domain":       p.domain,
                "range_":       p.range_,
                "description":  p.description,
                "standard_tag": getattr(p, 'standard_tag', ''),
            }
            for p in version.predicates
        ],
    }
    return JSONResponse(
        content=data,
        headers={
            "Content-Disposition":
                f'attachment; filename="{version_id}.json"',
            "Content-Type": "application/json; charset=utf-8",
        }
    )
```

### Flutter 다운로드 버튼

```dart
// OntologyDetailPanel 상단 버튼 영역에 추가

IconButton(
  icon: const Icon(Icons.download_outlined),
  tooltip: 'JSON 다운로드',
  onPressed: () async {
    final url = '${apiClient.baseUrl}/api/ontologies'
                '/${version.versionId}/download';
    // Windows: 파일 저장 다이얼로그
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'JSON 저장',
      fileName: '${version.versionId}.json',
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    if (savePath == null) return;

    final response = await apiClient.get(
        '/api/ontologies/${version.versionId}/download');
    final file = File(savePath);
    await file.writeAsString(
        jsonEncode(response.data), encoding: utf8);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저장됨: $savePath')),
    );
  },
),
```

---

## F3 — 종합 원칙 및 결과 리포트

### 종합 원칙 표시 UI

종합 결과 Draft 선택 시 상단에 종합 리포트 카드 표시:

```
┌──────────────────────────────────────────────────────────────┐
│  종합 리포트                                    [접기 ▲]     │
│                                                              │
│  원본: draft-A (클래스 17개) + draft-B (클래스 5개)         │
│  결과: 클래스 19개 · 속성 24개                               │
│                                                              │
│  [통합된 클래스]  유사 의미로 하나로 합쳐진 것               │
│    Person ← Person + Person (중복 제거)                     │
│    Victim ← Victim + ColonialViolenceVictim (의미 통합)     │
│                                                              │
│  [신규 추가 클래스]  한쪽에만 있던 것 (합집합)               │
│    NarrativeSession, Emotion, Policy ...                    │
│                                                              │
│  [제거된 클래스]  구술 도메인에 부적합하여 제거              │
│    FoodAvoidance (도메인 범위 초과)                         │
└──────────────────────────────────────────────────────────────┘
```

### 백엔드 — 종합 원칙 AI 프롬프트에 포함

```python
MERGE_SYSTEM_PROMPT = """당신은 구술기록 아카이브 온톨로지 전문가입니다.
여러 Draft 온톨로지를 하나로 통합해주세요.

종합 원칙:
1. 동일/유사 클래스 통합: 같은 개념을 다르게 표현한 클래스는 하나로 합침
   예) Person + Person → Person (중복 제거)
   예) Victim + ColonialViolenceVictim → Victim (상위 개념으로 통일)
2. 독자 클래스 보존: 한쪽에만 있는 클래스는 합집합으로 포함
3. 구술 도메인 부적합 클래스 제거: 구술기록과 무관한 지나치게 구체적 클래스 제거
   예) FoodAvoidance (특정 증상), RecipeIngredient 등
4. 속성(predicate) 도메인/범위 재정의: 통합된 클래스 기준으로 재설정

반드시 다음 JSON 형식으로만 응답하세요:
{
  "merge_report": {
    "merged": [{"result": "클래스명", "sources": ["원본1", "원본2"], "reason": "이유"}],
    "added":   [{"name": "클래스명", "from": "draft-xxx", "reason": "이유"}],
    "removed": [{"name": "클래스명", "reason": "이유"}]
  },
  "classes": [...],
  "predicates": [...]
}"""
```

---

## F4 — 표준 온톨로지 태그

### 구술기록 적합 표준 온톨로지

```
우선순위 1: 구술 특화
  CIDOC-CRM   — 문화유산 개념 참조 모델 (E21 Person, E5 Event 등)
  Dublin Core — 메타데이터 표준 (dc:title, dc:creator, dc:date)
  FOAF        — 인물 기술 (foaf:Person, foaf:name)

우선순위 2: 범용
  Schema.org  — 웹 시맨틱 표준 (schema:Person, schema:Place, schema:Event)
  OWL/RDF     — 온톨로지 기반 표준

클래스별 태그 매핑:
  Person           → foaf:Person, cidoc:E21_Person, schema:Person
  Place            → cidoc:E53_Place, schema:Place
  Event            → cidoc:E5_Event, schema:Event
  Time             → cidoc:E52_Time-Span, schema:DateTime
  Organization     → foaf:Organization, cidoc:E74_Group, schema:Organization
  Object           → cidoc:E22_Human-Made_Object, schema:Thing
  Topic            → dc:subject, schema:DefinedTerm
  NarrativeSession → cidoc:E65_Creation (구술행위), schema:CreativeWork
  Community        → cidoc:E74_Group, schema:SocialEvent
  Policy           → cidoc:E73_Information_Object, schema:Legislation
  Emotion          → (구술 특화 — 표준 없음, 커스텀)
  Collection       → dc:Collection, cidoc:E78_Curated_Holding
```

### 데이터클래스 확장

```python
# ontology/ontology_manager.py

@dataclass
class OntologyClass:
    name:         str
    label_ko:     str
    color:        str
    description:  str = ""
    examples:     list[str] = field(default_factory=list)
    note:         str = ""
    standard_tag: str = ""   # ← 신규: "foaf:Person, cidoc:E21_Person"
    merge_note:   str = ""   # ← 신규: 종합 시 처리 내역

@dataclass
class OntologyPredicate:
    name:         str
    domain:       list[str] = field(default_factory=list)
    range_:       list[str] = field(default_factory=list)
    description:  str = ""
    note:         str = ""
    standard_tag: str = ""   # ← 신규: "dc:relation, schema:relatedTo"
    merge_note:   str = ""   # ← 신규
```

### 기본 온톨로지 자동 태그 적용

```python
# ontology/standard_tags.py

STANDARD_CLASS_TAGS = {
    "Person":           "foaf:Person · cidoc:E21_Person · schema:Person",
    "Place":            "cidoc:E53_Place · schema:Place",
    "Event":            "cidoc:E5_Event · schema:Event",
    "Time":             "cidoc:E52_Time-Span · schema:DateTime",
    "Organization":     "foaf:Organization · cidoc:E74_Group · schema:Organization",
    "Object":           "cidoc:E22_Human-Made_Object · schema:Thing",
    "Topic":            "dc:subject · schema:DefinedTerm",
    "NarrativeSession": "cidoc:E65_Creation · dc:description",
    "Community":        "cidoc:E74_Group · schema:SocialEvent",
    "Policy":           "cidoc:E73_Information_Object · schema:Legislation",
    "Emotion":          "(구술 특화 커스텀 클래스)",
    "Collection":       "dc:Collection · cidoc:E78_Curated_Holding",
}

STANDARD_PREDICATE_TAGS = {
    "출생지":   "cidoc:P98i_was_born · schema:birthPlace",
    "거주지":   "schema:homeLocation",
    "참여함":   "cidoc:P11i_participated_in · schema:participant",
    "경험함":   "cidoc:P12i_was_present_at",
    "발생장소": "cidoc:P7_took_place_at · schema:location",
    "발생시기": "cidoc:P4_has_time-span · schema:startDate",
    "소속":     "org:memberOf · schema:memberOf",
    "증언함":   "cidoc:P67i_is_referred_to_by",
    "이주함":   "schema:fromLocation · schema:toLocation",
    "자녀":     "foaf:made · schema:children",
    "부모":     "foaf:maker · schema:parent",
    "배우자":   "schema:spouse",
    "면담자":   "cidoc:P14_carried_out_by (면담자 역할)",
    "구술자":   "cidoc:P14_carried_out_by (구술자 역할)",
    "수록됨":   "dc:isPartOf · cidoc:P46i_forms_part_of",
}

def apply_standard_tags(version: OntologyVersion) -> OntologyVersion:
    """버전의 클래스/속성에 표준 태그 자동 부여"""
    for c in version.classes:
        if not c.standard_tag and c.name in STANDARD_CLASS_TAGS:
            c.standard_tag = STANDARD_CLASS_TAGS[c.name]
    for p in version.predicates:
        if not p.standard_tag and p.name in STANDARD_PREDICATE_TAGS:
            p.standard_tag = STANDARD_PREDICATE_TAGS[p.name]
    return version
```

### Flutter 표준 태그 표시 UI

```dart
// OntologyClassCard 에 standard_tag 표시

if (ontologyClass.standardTag.isNotEmpty) ...[
  const SizedBox(height: 6),
  Wrap(
    spacing: 4,
    children: ontologyClass.standardTag.split('·').map((tag) =>
      Chip(
        label: Text(tag.trim(),
            style: const TextStyle(fontSize: 10)),
        backgroundColor: Colors.blue.withOpacity(0.08),
        side: BorderSide(color: Colors.blue.withOpacity(0.2)),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      )
    ).toList(),
  ),
],
```

---

## 구현 순서

```
Phase 1 — 버그 수정 (최우선)
  1-1. Bug 1: merge 500 오류
       → 서버 로그 확인 → ontology_manager.py 수정
  1-2. Bug 2: 트리플 블랙 화면
       → triple_step2_review.dart mounted 체크
       → triple_step3_list.dart 안전 처리

Phase 2 — 신규 기능
  2-1. F1: 종합 이름 직접 입력 (MergeDialog 수정)
  2-2. F2: JSON 다운로드 API + Flutter 버튼
  2-3. F4: 표준 태그 데이터클래스 확장
       → standard_tags.py 신규 생성
       → OntologyClass/Predicate standard_tag 필드 추가
       → apply_standard_tags() 자동 적용

Phase 3 — 종합 리포트
  3-1. F3: MERGE_SYSTEM_PROMPT merge_report 포함
  3-2. MergeReportCard 위젯 생성
  3-3. 종합 결과 Draft 선택 시 리포트 표시

Phase 4 — 테스트 + 커밋
  4-1. pytest tests/ → 101/101 유지
  4-2. Flutter 수동 테스트:
       □ 종합 이름 입력 → 생성 확인
       □ JSON 다운로드 → 파일 내용 확인
       □ 표준 태그 칩 표시 확인
       □ 트리플 확정 → 블랙 화면 없음 확인
  4-3. git commit
```

---

## 완료 기준

```
Phase 1:
  □ [선택 Draft 종합] → 500 오류 없이 새 Draft 생성
  □ 트리플 [전체 확정 저장] → 블랙 화면 없이 Step 3 이동

Phase 2:
  □ 종합 다이얼로그에 버전 ID 입력 필드 표시
  □ 버전 상세 화면 우상단 다운로드 버튼 표시
  □ 클릭 시 {version_id}.json 파일 저장
  □ 클래스 카드에 표준 태그 칩 표시 (있는 경우)

Phase 3:
  □ 종합된 Draft 선택 시 종합 리포트 카드 표시
  □ 통합/추가/제거 클래스 목록 정확히 표시
```

---

## 제약 조건

```
- Phase 1 완료 확인 후 Phase 2 시작
- Bug 1은 서버 로그 traceback 확인 후 수정
  (추측 수정 금지)
- JSON 다운로드: Windows 경로 처리 (역슬래시)
- standard_tags.py 는 별도 파일로 분리
  (ontology_manager.py 비대화 방지)
- apply_standard_tags() 는 Draft 생성/종합 완료 시 자동 호출
  (사용자 직접 호출 불필요)
- 기존 테스트 101개 통과 유지
```
