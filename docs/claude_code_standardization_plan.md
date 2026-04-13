# 표준화 탭 — 자동 매핑 + 관리자 확정 Plan

## 목표

```
현재: 표준 태그 입력란이 비어 있음 (수동 입력만 가능)
목표: AI가 클래스/속성별로 가장 적절한 외부 온톨로지 URI를 자동 제안
      → 관리자가 검토 후 수정 또는 확정
      → 확정된 매핑은 해당 온톨로지에 저장
```

---

## 적용할 외부 온톨로지 (우선순위 순)

```
1. CIDOC-CRM   cidoc:   — 문화유산·구술 아카이브 국제 표준
2. FOAF        foaf:    — 인물·관계 기술
3. Dublin Core dc:      — 메타데이터 표준
4. Schema.org  schema:  — 범용 웹 시맨틱
5. OWL/RDF     owl:/rdf: — 온톨로지 기반 표준
6. ORG         org:     — 조직 기술

구술기록 도메인에서 CIDOC-CRM이 가장 중요:
  E21 Person, E53 Place, E5 Event, E52 Time-Span,
  E65 Creation (구술 행위), E78 Curated Holding 등
```

---

## 자동 매핑 데이터베이스

### 클래스 매핑 (ontology/standard_mappings.py)

```python
# 클래스명 → 추천 매핑 목록 (우선순위 순)
CLASS_MAPPINGS: dict[str, list[dict]] = {

    # ── 인물 관련 ──────────────────────────────────────
    "Person": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물", "priority": 1},
        {"uri": "foaf:Person",         "label": "FOAF 인물",      "priority": 2},
        {"uri": "schema:Person",       "label": "Schema.org 인물","priority": 3},
    ],
    "Narrator": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물", "priority": 1},
        {"uri": "foaf:Person",         "label": "FOAF 인물",      "priority": 2},
        {"uri": "schema:Person",       "label": "Schema.org 인물","priority": 3},
    ],
    "Survivor": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물", "priority": 1},
        {"uri": "schema:Person",       "label": "Schema.org 인물","priority": 2},
    ],
    "Witness": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물", "priority": 1},
        {"uri": "foaf:Person",         "label": "FOAF 인물",      "priority": 2},
    ],
    "Victim": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물", "priority": 1},
        {"uri": "schema:Person",       "label": "Schema.org 인물","priority": 2},
    ],
    "Interviewer": [
        {"uri": "cidoc:E21_Person",   "label": "CIDOC-CRM 인물", "priority": 1},
        {"uri": "foaf:Person",         "label": "FOAF 인물",      "priority": 2},
    ],

    # ── 집단/조직 관련 ─────────────────────────────────
    "FamilyGroup": [
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단", "priority": 1},
        {"uri": "foaf:Group",          "label": "FOAF 집단",      "priority": 2},
        {"uri": "schema:Organization","label": "Schema.org 조직","priority": 3},
    ],
    "Organization": [
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단", "priority": 1},
        {"uri": "org:Organization",    "label": "ORG 조직",       "priority": 2},
        {"uri": "foaf:Organization",   "label": "FOAF 조직",      "priority": 3},
        {"uri": "schema:Organization","label": "Schema.org 조직","priority": 4},
    ],
    "Community": [
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단", "priority": 1},
        {"uri": "schema:Organization","label": "Schema.org 조직","priority": 2},
    ],
    "HistoricalActor": [
        {"uri": "cidoc:E39_Actor",    "label": "CIDOC-CRM 행위자","priority": 1},
        {"uri": "cidoc:E74_Group",    "label": "CIDOC-CRM 집단",  "priority": 2},
    ],

    # ── 장소 관련 ──────────────────────────────────────
    "Place": [
        {"uri": "cidoc:E53_Place",    "label": "CIDOC-CRM 장소", "priority": 1},
        {"uri": "schema:Place",        "label": "Schema.org 장소","priority": 2},
    ],
    "Location": [
        {"uri": "cidoc:E53_Place",    "label": "CIDOC-CRM 장소", "priority": 1},
        {"uri": "schema:Place",        "label": "Schema.org 장소","priority": 2},
    ],
    "BodyOfWater": [
        {"uri": "cidoc:E53_Place",    "label": "CIDOC-CRM 장소", "priority": 1},
        {"uri": "schema:LakeBodyOfWater","label": "Schema.org 수역","priority": 2},
    ],
    "AdministrativeRegion": [
        {"uri": "cidoc:E53_Place",      "label": "CIDOC-CRM 장소","priority": 1},
        {"uri": "schema:AdministrativeArea","label": "Schema.org 행정구역","priority": 2},
    ],

    # ── 사건 관련 ──────────────────────────────────────
    "Event": [
        {"uri": "cidoc:E5_Event",     "label": "CIDOC-CRM 사건", "priority": 1},
        {"uri": "schema:Event",        "label": "Schema.org 사건","priority": 2},
    ],
    "HistoricalEvent": [
        {"uri": "cidoc:E5_Event",     "label": "CIDOC-CRM 사건", "priority": 1},
        {"uri": "cidoc:E7_Activity",  "label": "CIDOC-CRM 활동", "priority": 2},
        {"uri": "schema:Event",        "label": "Schema.org 사건","priority": 3},
    ],
    "ColonialViolence": [
        {"uri": "cidoc:E5_Event",     "label": "CIDOC-CRM 사건", "priority": 1},
        {"uri": "cidoc:E7_Activity",  "label": "CIDOC-CRM 활동", "priority": 2},
    ],
    "Trauma": [
        {"uri": "cidoc:E28_Conceptual_Object","label": "CIDOC-CRM 개념 객체","priority": 1},
        {"uri": "schema:MedicalCondition","label": "Schema.org 의학 상태","priority": 2},
    ],

    # ── 시간 관련 ──────────────────────────────────────
    "Time": [
        {"uri": "cidoc:E52_Time-Span","label": "CIDOC-CRM 시간 범위","priority": 1},
        {"uri": "schema:DateTime",     "label": "Schema.org 날짜시간","priority": 2},
    ],
    "Date": [
        {"uri": "cidoc:E52_Time-Span","label": "CIDOC-CRM 시간 범위","priority": 1},
        {"uri": "schema:Date",         "label": "Schema.org 날짜",   "priority": 2},
        {"uri": "dc:date",             "label": "Dublin Core 날짜",  "priority": 3},
    ],

    # ── 구술 관련 ──────────────────────────────────────
    "NarrativeSession": [
        {"uri": "cidoc:E65_Creation", "label": "CIDOC-CRM 창작 행위","priority": 1},
        {"uri": "dc:description",      "label": "Dublin Core 설명",  "priority": 2},
        {"uri": "schema:CreativeWork", "label": "Schema.org 창작물", "priority": 3},
    ],
    "Collection": [
        {"uri": "cidoc:E78_Curated_Holding","label": "CIDOC-CRM 큐레이션 컬렉션","priority": 1},
        {"uri": "dc:Collection",        "label": "Dublin Core 컬렉션","priority": 2},
        {"uri": "schema:Collection",    "label": "Schema.org 컬렉션","priority": 3},
    ],

    # ── 기타 ───────────────────────────────────────────
    "Object": [
        {"uri": "cidoc:E22_Human-Made_Object","label": "CIDOC-CRM 인공물","priority": 1},
        {"uri": "schema:Thing",          "label": "Schema.org 사물","priority": 2},
    ],
    "Topic": [
        {"uri": "dc:subject",           "label": "Dublin Core 주제","priority": 1},
        {"uri": "schema:DefinedTerm",   "label": "Schema.org 정의 용어","priority": 2},
    ],
    "Policy": [
        {"uri": "cidoc:E73_Information_Object","label": "CIDOC-CRM 정보 객체","priority": 1},
        {"uri": "schema:Legislation",   "label": "Schema.org 법령","priority": 2},
    ],
    "Emotion": [
        {"uri": "schema:Thing",         "label": "Schema.org 사물 (커스텀 확장)","priority": 1},
    ],
}

# 속성 매핑
PREDICATE_MAPPINGS: dict[str, list[dict]] = {
    "출생지":     [
        {"uri": "cidoc:P98i_was_born",  "label": "CIDOC 출생", "priority": 1},
        {"uri": "schema:birthPlace",    "label": "Schema 출생지","priority": 2},
    ],
    "거주지":     [
        {"uri": "cidoc:P74_has_current_or_former_residence",
                                         "label": "CIDOC 거주지", "priority": 1},
        {"uri": "schema:homeLocation",  "label": "Schema 거주지","priority": 2},
    ],
    "참여함":     [
        {"uri": "cidoc:P11i_participated_in","label": "CIDOC 참여","priority": 1},
        {"uri": "schema:participant",   "label": "Schema 참여자","priority": 2},
    ],
    "경험함":     [
        {"uri": "cidoc:P12i_was_present_at","label": "CIDOC 현장","priority": 1},
    ],
    "발생장소":   [
        {"uri": "cidoc:P7_took_place_at","label": "CIDOC 발생장소","priority": 1},
        {"uri": "schema:location",      "label": "Schema 장소",   "priority": 2},
    ],
    "발생시기":   [
        {"uri": "cidoc:P4_has_time-span","label": "CIDOC 시간범위","priority": 1},
        {"uri": "schema:startDate",     "label": "Schema 시작일", "priority": 2},
    ],
    "소속":       [
        {"uri": "org:memberOf",         "label": "ORG 소속",      "priority": 1},
        {"uri": "schema:memberOf",      "label": "Schema 소속",   "priority": 2},
    ],
    "증언함":     [
        {"uri": "cidoc:P67i_is_referred_to_by","label": "CIDOC 참조","priority": 1},
    ],
    "이주함":     [
        {"uri": "schema:fromLocation",  "label": "Schema 출발지", "priority": 1},
    ],
    "자녀":       [
        {"uri": "schema:children",      "label": "Schema 자녀",   "priority": 1},
        {"uri": "foaf:made",            "label": "FOAF 자녀",     "priority": 2},
    ],
    "부모":       [
        {"uri": "schema:parent",        "label": "Schema 부모",   "priority": 1},
        {"uri": "foaf:maker",           "label": "FOAF 제작자",   "priority": 2},
    ],
    "배우자":     [
        {"uri": "schema:spouse",        "label": "Schema 배우자", "priority": 1},
    ],
    "면담자":     [
        {"uri": "cidoc:P14_carried_out_by","label": "CIDOC 수행자","priority": 1},
    ],
    "구술자":     [
        {"uri": "cidoc:P14_carried_out_by","label": "CIDOC 수행자","priority": 1},
        {"uri": "dc:creator",           "label": "DC 창작자",     "priority": 2},
    ],
    "수록됨":     [
        {"uri": "dc:isPartOf",          "label": "DC 일부",       "priority": 1},
        {"uri": "cidoc:P46i_forms_part_of","label": "CIDOC 부분", "priority": 2},
    ],
    "관련됨":     [
        {"uri": "dc:relation",          "label": "DC 관련",       "priority": 1},
        {"uri": "schema:relatedTo",     "label": "Schema 관련",   "priority": 2},
    ],
    "이산됨":     [
        {"uri": "schema:fromLocation",  "label": "Schema 출발지", "priority": 1},
    ],
    "피해입음":   [
        {"uri": "cidoc:P12i_was_present_at","label": "CIDOC 현장","priority": 1},
    ],
    "저항함":     [
        {"uri": "cidoc:P11i_participated_in","label": "CIDOC 참여","priority": 1},
    ],
    "언급함":     [
        {"uri": "cidoc:P67_refers_to",  "label": "CIDOC 참조",    "priority": 1},
    ],
    "기억함":     [
        {"uri": "cidoc:P67_refers_to",  "label": "CIDOC 참조",    "priority": 1},
    ],
}

def get_class_suggestions(class_name: str) -> list[dict]:
    """클래스명으로 매핑 후보 반환 (없으면 빈 목록)"""
    return CLASS_MAPPINGS.get(class_name, [])

def get_predicate_suggestions(pred_name: str) -> list[dict]:
    """속성명으로 매핑 후보 반환"""
    return PREDICATE_MAPPINGS.get(pred_name, [])
```

---

## 백엔드 API 추가

```python
# api/router_ontology.py

GET /api/ontologies/{version_id}/mappings
  → 해당 버전 클래스/속성별 추천 매핑 + 현재 저장된 값 반환
  response: {
    "classes": [
      {
        "name": "Narrator",
        "label_ko": "구술자",
        "current_tag": "foaf:Person",        # 현재 저장값
        "suggestions": [                      # 추천 후보
          {"uri": "cidoc:E21_Person", "label": "CIDOC-CRM 인물", "priority": 1},
          {"uri": "foaf:Person",       "label": "FOAF 인물",     "priority": 2},
        ],
        "is_confirmed": false                 # 관리자 확정 여부
      }
    ],
    "predicates": [...]
  }

PATCH /api/ontologies/{version_id}/mappings
  body: {
    "classes": [
      {"name": "Narrator", "tag": "cidoc:E21_Person", "confirmed": true}
    ],
    "predicates": [
      {"name": "출생지", "tag": "cidoc:P98i_was_born", "confirmed": true}
    ]
  }
  → standard_tag 업데이트 + mapping_confirmed 필드 저장
  → 이력 기록: "mapping_confirmed" 이벤트
```

---

## Flutter 표준화 탭 UI 상세

```
┌────────────────┬──────────────────────────────────────────────────────┐
│ 목록           │ debug-merge-fixed  ✎  [전체 확정] [내보내기]         │
│                │                                                      │
│ □ draft-fix    │ 클래스 매핑 (19개 · 확정 4 / 미확정 15)              │
│   표준 4/19    │ 속성 매핑  (24개 · 확정 2 / 미확정 22)              │
│                │                                                      │
│                │ [클래스 매핑] [속성 매핑]  ← 내부 탭                 │
│                │                                                      │
│                │ 클래스 매핑 탭:                                      │
│                │ ┌──────────────────────────────────────────────┐    │
│                │ │  ● Narrator  구술자                           │    │
│                │ │    추천 1순위: cidoc:E21_Person ← [적용]      │    │
│                │ │    추천 2순위: foaf:Person      ← [적용]      │    │
│                │ │    추천 3순위: schema:Person    ← [적용]      │    │
│                │ │    직접입력: [__________________] [저장]       │    │
│                │ │    현재값: foaf:Person          ✓ [확정 취소] │    │
│                │ ├──────────────────────────────────────────────┤    │
│                │ │  ● Survivor  생존자      [미확정]             │    │
│                │ │    추천 1순위: cidoc:E21_Person ← [적용]      │    │
│                │ │    직접입력: [__________________] [저장]       │    │
│                │ │    현재값: ─                    [확정]        │    │
│                │ └──────────────────────────────────────────────┘    │
└────────────────┴──────────────────────────────────────────────────────┘
```

### 상태 표시 규칙

```
미확정 + 값 없음:  회색 배경 · [확정] 버튼 비활성
미확정 + 값 있음:  노란 배경 · [확정] 버튼 활성
확정됨:           초록 배경 · 체크 아이콘 · [확정 취소] 버튼
```

---

## Flutter 구현 코드

### MappingItem 모델

```dart
// flutter/lib/models/ontology.dart 에 추가

class MappingItem {
  final String name;
  final String labelKo;
  final String currentTag;
  final List<MappingSuggestion> suggestions;
  final bool isConfirmed;

  MappingItem({
    required this.name,
    required this.labelKo,
    required this.currentTag,
    required this.suggestions,
    required this.isConfirmed,
  });

  factory MappingItem.fromJson(Map<String, dynamic> json) => MappingItem(
    name:        json['name'] ?? '',
    labelKo:     json['label_ko'] ?? '',
    currentTag:  json['current_tag'] ?? '',
    suggestions: (json['suggestions'] as List? ?? [])
        .map((s) => MappingSuggestion.fromJson(s)).toList(),
    isConfirmed: json['is_confirmed'] ?? false,
  );
}

class MappingSuggestion {
  final String uri;
  final String label;
  final int priority;

  MappingSuggestion({
    required this.uri,
    required this.label,
    required this.priority,
  });

  factory MappingSuggestion.fromJson(Map<String, dynamic> json) =>
      MappingSuggestion(
        uri:      json['uri'] ?? '',
        label:    json['label'] ?? '',
        priority: json['priority'] ?? 99,
      );
}
```

### MappingCard 위젯

```dart
// flutter/lib/screens/ontology/mapping_card.dart

class MappingCard extends StatefulWidget {
  final MappingItem item;
  final Function(String tag, bool confirmed) onSave;

  const MappingCard({required this.item, required this.onSave, super.key});

  @override
  State<MappingCard> createState() => _MappingCardState();
}

class _MappingCardState extends State<MappingCard> {
  late TextEditingController _ctrl;
  late bool _confirmed;
  late String _currentTag;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _currentTag = widget.item.currentTag;
    _confirmed  = widget.item.isConfirmed;
    _ctrl       = TextEditingController(text: _currentTag);
  }

  Color get _bgColor {
    if (_confirmed) return Colors.green.withOpacity(0.08);
    if (_currentTag.isNotEmpty) return Colors.amber.withOpacity(0.06);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: _bgColor,
      child: Column(children: [

        // ── 헤더 행 ───────────────────────────────────
        ListTile(
          leading: CircleAvatar(
            radius: 8,
            backgroundColor: Color(
                int.parse('0xFF${widget.item.color?.replaceAll('#','') ?? '888888'}')
            ),
          ),
          title: Text('${widget.item.name}  '
              '(${widget.item.labelKo})',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: _currentTag.isEmpty
              ? const Text('매핑 없음', style: TextStyle(color: Colors.grey))
              : Text(_currentTag,
                  style: TextStyle(
                    color: _confirmed ? Colors.green.shade700 : Colors.orange.shade700,
                    fontFamily: 'monospace',
                  )),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // 확정 상태 배지
            if (_confirmed)
              const Icon(Icons.check_circle, color: Colors.green, size: 20)
            else if (_currentTag.isNotEmpty)
              const Icon(Icons.pending, color: Colors.orange, size: 20),

            // 펼치기
            IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ]),
        ),

        // ── 펼침: 추천 + 직접입력 ────────────────────
        if (_expanded) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 추천 후보 목록
                if (widget.item.suggestions.isNotEmpty) ...[
                  const Text('추천 매핑',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  ...widget.item.suggestions.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Container(
                        width: 20, height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${s.priority}',
                            style: const TextStyle(fontSize: 10)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${s.uri}  (${s.label})',
                            style: const TextStyle(
                                fontSize: 12, fontFamily: 'monospace')),
                      ),
                      TextButton(
                        onPressed: () => _applyTag(s.uri),
                        child: const Text('적용', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                  )),
                  const SizedBox(height: 8),
                ],

                // 직접 입력
                const Text('직접 입력',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: '예: cidoc:E21_Person',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _applyTag(_ctrl.text.trim()),
                    child: const Text('저장'),
                  ),
                ]),

                const SizedBox(height: 10),

                // 확정 / 확정 취소
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (_confirmed)
                    OutlinedButton(
                      onPressed: _unconfirm,
                      child: const Text('확정 취소'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _currentTag.isEmpty ? null : _confirm,
                      child: const Text('확정'),
                    ),
                ]),
              ],
            ),
          ),
        ],

        const Divider(height: 1),
      ]),
    );
  }

  void _applyTag(String tag) {
    if (tag.isEmpty) return;
    setState(() {
      _currentTag = tag;
      _ctrl.text  = tag;
      _confirmed  = false;
    });
    widget.onSave(tag, false);
  }

  void _confirm() {
    setState(() => _confirmed = true);
    widget.onSave(_currentTag, true);
  }

  void _unconfirm() {
    setState(() => _confirmed = false);
    widget.onSave(_currentTag, false);
  }
}
```

---

## 구현 순서

```
Phase 1 — 백엔드
  1-1. ontology/standard_mappings.py 신규 생성
       (CLASS_MAPPINGS + PREDICATE_MAPPINGS 전체)
  1-2. router_ontology.py:
       GET  /api/ontologies/{id}/mappings
       PATCH /api/ontologies/{id}/mappings
  1-3. OntologyClass/Predicate 에 mapping_confirmed 필드 추가
  1-4. curl 테스트:
       GET /api/ontologies/test-phase1-fix/mappings
       → 클래스별 추천 목록 + current_tag + is_confirmed 반환

Phase 2 — Flutter 표준화 탭 완성
  2-1. models/ontology.dart: MappingItem, MappingSuggestion 추가
  2-2. api/ontology_api.dart:
       getMappings(versionId)
       saveMappings(versionId, classes, predicates)
  2-3. screens/ontology/mapping_card.dart 신규 생성
  2-4. ontology_standard_tab.dart 완성:
       - 매핑 로드 (GET /mappings)
       - 클래스/속성 내부 탭
       - MappingCard 목록
       - [전체 자동 적용] → 모든 항목에 1순위 추천값 적용
       - [전체 확정] → 값 있는 항목 전체 confirmed=true

Phase 3 — 테스트
  □ 표준화 탭 진입 → 클래스별 추천 목록 표시
  □ [적용] 클릭 → current_tag 업데이트
  □ 직접 입력 → 저장
  □ [확정] → 초록 배경 + 체크 아이콘
  □ [전체 자동 적용] → 모든 항목 1순위값으로 채워짐
  □ [전체 확정] → 전체 초록 배경
  □ PATCH /api/ontologies/{id}/mappings → DB 저장 확인
  □ 화면 새로고침 후에도 확정 상태 유지
```

---

## 완료 기준

```
Phase 1:
  □ GET /api/ontologies/{id}/mappings
    → suggestions 목록에 CIDOC-CRM 1순위 포함
  □ PATCH /api/ontologies/{id}/mappings
    → standard_tag 업데이트 + mapping_confirmed 저장

Phase 2:
  □ 표준화 탭: 클래스 카드마다 추천 후보 1~3개 표시
  □ [적용] → 현재값 변경 + 노란 배경
  □ [확정] → 초록 배경 + 체크
  □ [전체 자동 적용] → 모든 항목 1순위 적용
  □ 확정 진행률 표시 (예: 확정 4/19)
```

---

## 제약 조건

```
- Phase 1 curl 통과 후 Phase 2 시작
- standard_mappings.py 는 별도 파일로 분리
  (새 클래스 추가 시 이 파일만 수정)
- 클래스명 대소문자 구분 없이 매핑 조회
  (Narrator == narrator 동일 처리)
- 매핑 없는 클래스: 직접 입력란만 표시 (추천 섹션 숨김)
- 확정(confirmed=true) 항목만 표준화 완료로 집계
- 기존 54→101개 테스트 통과 유지
```
