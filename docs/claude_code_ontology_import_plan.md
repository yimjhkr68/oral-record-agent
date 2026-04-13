# 온톨로지 기능 개선 Plan

## 작업 목록

```
F1. 온톨로지 JSON/CSV 임포트
F2. 구술기록 입력 최대 길이 안내 + 경고
F3. 표준화 탭 — 매핑 추천값 + confidence 선택 UI
F4. 확정 탭 — Confirmed 상태만 표시
```

---

## F1 — 온톨로지 JSON/CSV 임포트

### 지원 형식

```
JSON: 기존 내보내기 포맷 (export_type: "ontologies")
CSV:  클래스 목록 또는 속성 목록 테이블 형식
```

### CSV 형식 규칙

```csv
# 클래스 CSV
name,label_ko,color,description,examples
Person,인물,#f59e0b,구술의 주체가 되는 사람,"구술자,면담자"
Place,장소,#10b981,구술에 등장하는 지명,""

# 속성 CSV
name,domain,range_,description
출생지,Person,Place,인물이 태어난 장소
참여함,Person,Event,인물이 사건에 참여함
```

### 백엔드 API

```python
# api/router_ontology.py 에 추가

POST /api/ontologies/import
  body: multipart/form-data
    file:         업로드 파일 (.json / .csv)
    version_id:   새 버전 ID (비워두면 자동 생성)
    import_mode:  "new" | "merge"
                  new: 새 Draft 로 생성
                  merge: 기존 Draft 에 병합

# ontology/ontology_importer.py 신규

class OntologyImporter:

    def from_json(self, data: dict,
                  version_id: str = "") -> OntologyVersion:
        """
        내보내기 JSON 또는 단일 버전 JSON 파싱.
        지원 포맷:
          A. export_type="ontologies" → items[0] 사용
          B. 단일 버전 JSON (version_id, classes, predicates 포함)
        """
        if data.get("export_type") == "ontologies":
            items = data.get("items", [])
            if not items:
                raise ValueError("임포트할 온톨로지가 없습니다.")
            source = items[0]
        else:
            source = data

        classes = [
            _safe_class({
                "name":         c.get("name", ""),
                "label_ko":     c.get("label_ko", ""),
                "color":        c.get("color", "#888888"),
                "description":  c.get("description", ""),
                "examples":     c.get("examples", []),
                "standard_tag": c.get("standard_tag", ""),
            })
            for c in source.get("classes", [])
            if isinstance(c, dict)
        ]
        predicates = [
            _safe_predicate({
                "name":         p.get("name", ""),
                "domain":       p.get("domain", []),
                "range_":       p.get("range_", []),
                "description":  p.get("description", ""),
                "standard_tag": p.get("standard_tag", ""),
            })
            for p in source.get("predicates", [])
            if isinstance(p, dict)
        ]

        new_id = version_id or self._generate_id("imported")
        return OntologyVersion(
            version_id   = new_id,
            status       = OntologyStatus.DRAFT,
            classes      = [c for c in classes if c],
            predicates   = [p for p in predicates if p],
            description  = f"임포트: {source.get('version_id', '')}",
        )

    def from_csv(self, csv_text: str,
                 csv_type: str,           # "classes" | "predicates"
                 version_id: str = "") -> OntologyVersion:
        """
        CSV 파싱.
        csv_type: "classes" → 클래스 목록
                  "predicates" → 속성 목록
        """
        import csv, io
        reader = csv.DictReader(io.StringIO(csv_text))

        if csv_type == "classes":
            classes = []
            for row in reader:
                c = _safe_class({
                    "name":        row.get("name", "").strip(),
                    "label_ko":    row.get("label_ko", "").strip(),
                    "color":       row.get("color", "#888888").strip(),
                    "description": row.get("description", "").strip(),
                    "examples":    [e.strip() for e in
                                   row.get("examples", "").split(",")
                                   if e.strip()],
                })
                if c: classes.append(c)
            new_id = version_id or self._generate_id("csv-import")
            return OntologyVersion(
                version_id = new_id,
                status     = OntologyStatus.DRAFT,
                classes    = classes,
                predicates = [],
                description = "CSV 클래스 임포트",
            )

        elif csv_type == "predicates":
            predicates = []
            for row in reader:
                p = _safe_predicate({
                    "name":        row.get("name", "").strip(),
                    "domain":      [d.strip() for d in
                                   row.get("domain", "").split(",")
                                   if d.strip()],
                    "range_":      [r.strip() for r in
                                   row.get("range_", "").split(",")
                                   if r.strip()],
                    "description": row.get("description", "").strip(),
                })
                if p: predicates.append(p)
            new_id = version_id or self._generate_id("csv-import")
            return OntologyVersion(
                version_id = new_id,
                status     = OntologyStatus.DRAFT,
                classes    = [],
                predicates = predicates,
                description = "CSV 속성 임포트",
            )

    def _generate_id(self, prefix: str) -> str:
        import time
        return f"{prefix}-{int(time.time())}"
```

### Flutter 임포트 UI

```dart
// 작업 중 탭 상단에 [임포트] 버튼 추가

PopupMenuButton<String>(
  icon: const Icon(Icons.upload_file_outlined),
  tooltip: '온톨로지 임포트',
  onSelected: (v) => _showImportDialog(v),
  itemBuilder: (_) => [
    const PopupMenuItem(value: 'json',
        child: Row(children: [
          Icon(Icons.data_object, size: 16),
          SizedBox(width: 8),
          Text('JSON 임포트'),
        ])),
    const PopupMenuItem(value: 'csv_classes',
        child: Row(children: [
          Icon(Icons.table_chart_outlined, size: 16),
          SizedBox(width: 8),
          Text('CSV 임포트 (클래스)'),
        ])),
    const PopupMenuItem(value: 'csv_predicates',
        child: Row(children: [
          Icon(Icons.table_chart_outlined, size: 16),
          SizedBox(width: 8),
          Text('CSV 임포트 (속성)'),
        ])),
  ],
)

// 임포트 다이얼로그
Future<void> _showImportDialog(String type) async {
  // 파일 선택
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: type == 'json' ? ['json'] : ['csv'],
  );
  if (result == null) return;

  final file = result.files.first;
  final bytes = file.bytes ?? File(file.path!).readAsBytesSync();
  final content = utf8.decode(bytes);

  // 버전 ID 입력 다이얼로그
  final versionIdCtrl = TextEditingController();
  if (!mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('${type == "json" ? "JSON" : "CSV"} 임포트'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('파일: ${file.name}',
            style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 12),
        TextField(
          controller: versionIdCtrl,
          decoration: const InputDecoration(
            labelText: '새 버전 ID (비워두면 자동 생성)',
            hintText: '예: v2.0-imported',
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('임포트'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  // API 호출
  final formData = FormData.fromMap({
    'file':        MultipartFile.fromBytes(bytes, filename: file.name),
    'version_id':  versionIdCtrl.text.trim(),
    'import_mode': 'new',
    'csv_type':    type == 'csv_classes' ? 'classes' : 'predicates',
  });

  await ref.read(apiClientProvider)
      .post('/api/ontologies/import', data: formData);

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('임포트 완료 — 작업 중 탭 확인')),
  );
  _loadVersions();
}
```

---

## F2 — 구술기록 입력 최대 길이 안내 + 경고

### 최대 길이 기준

```
Claude API 입력 컨텍스트: 최대 200,000 토큰
한국어 1자 ≈ 1~2 토큰
프롬프트 오버헤드: 약 1,000 토큰

안전 최대값: 8,000자 (여유 있게 설정)
경고 기준:   6,000자 (노란 경고)
초과 기준:   8,000자 (빨간 경고 + 잘림 안내)
```

### Flutter UI 수정

```dart
// input_method_bottom_sheet.dart — 텍스트 입력 탭

const int _MAX_CHARS     = 8000;  // 최대 허용
const int _WARN_CHARS    = 6000;  // 경고 시작
const int _OPTIMAL_CHARS = 3000;  // 권장 길이

// 텍스트 입력창 아래 안내 + 카운터
Column(children: [

  // 안내 텍스트 (항상 표시)
  Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.secondaryFaint,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline, size: 14,
          color: AppColors.secondary),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          '권장: 3,000자 이하  ·  최대: 8,000자\n'
          '너무 긴 텍스트는 AI가 중요 내용을 놓칠 수 있습니다.',
          style: TextStyle(fontSize: 11,
              color: AppColors.secondary),
        ),
      ),
    ]),
  ),
  const SizedBox(height: 8),

  // 텍스트 입력창
  TextField(
    controller: _textCtrl,
    maxLines: 8,
    onChanged: (v) => setState(() => _charCount = v.length),
    decoration: InputDecoration(
      hintText: '구술 텍스트를 붙여넣으세요...',
      border: OutlineInputBorder(
        borderSide: BorderSide(
          color: _charCount > _MAX_CHARS
              ? AppColors.error
              : _charCount > _WARN_CHARS
                  ? AppColors.warning
                  : AppColors.border,
          width: _charCount > _WARN_CHARS ? 1.5 : 1.0,
        ),
      ),
    ),
  ),
  const SizedBox(height: 6),

  // 글자 수 카운터 + 경고
  Row(children: [
    // 글자 수
    Text(
      '$_charCount / $_MAX_CHARS 자',
      style: TextStyle(
        fontSize: 12,
        color: _charCount > _MAX_CHARS
            ? AppColors.error
            : _charCount > _WARN_CHARS
                ? AppColors.warning
                : AppColors.textMuted,
        fontWeight: _charCount > _WARN_CHARS
            ? FontWeight.w600 : FontWeight.normal,
      ),
    ),

    // 경고 메시지
    if (_charCount > _MAX_CHARS) ...[
      const SizedBox(width: 8),
      const Icon(Icons.warning_amber, size: 14, color: AppColors.error),
      const SizedBox(width: 4),
      const Text('최대 길이 초과 — 8,000자까지 잘려서 처리됩니다',
          style: TextStyle(fontSize: 11, color: AppColors.error)),
    ] else if (_charCount > _WARN_CHARS) ...[
      const SizedBox(width: 8),
      const Icon(Icons.info_outline, size: 14, color: AppColors.warning),
      const SizedBox(width: 4),
      const Text('긴 텍스트 — AI 품질이 저하될 수 있습니다',
          style: TextStyle(fontSize: 11, color: AppColors.warning)),
    ],
  ]),
])

// 파일 업로드 탭 — 추출 완료 후 글자 수 경고
if (_extractedText.isNotEmpty) ...[
  // 기존 "추출 완료 — N자" 표시 유지
  if (_extractedText.length > _MAX_CHARS)
    Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber, size: 14,
            color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '파일이 ${_extractedText.length}자로 최대 길이(8,000자)를 초과합니다.\n'
            '앞부분 8,000자만 AI 분석에 사용됩니다.',
            style: const TextStyle(
                fontSize: 11, color: AppColors.error),
          ),
        ),
      ]),
    ),
]
```

---

## F3 — 표준화 탭 매핑 confidence 표시 + 선택 UI

### 현재 문제

```
현재: 추천 1순위 URI 목록만 표시
목표: 추천 후보별 confidence(신뢰도) 값 표시 +
      라디오 버튼으로 선택 또는 직접 입력
```

### 백엔드 — confidence 값 포함

```python
# ontology/standard_mappings.py — confidence 추가

CLASS_MAPPINGS = {
    "Person": [
        {"uri": "cidoc:E21_Person",
         "label": "CIDOC-CRM 인물",
         "confidence": 0.95,
         "priority": 1},
        {"uri": "foaf:Person",
         "label": "FOAF 인물",
         "confidence": 0.90,
         "priority": 2},
        {"uri": "schema:Person",
         "label": "Schema.org 인물",
         "confidence": 0.80,
         "priority": 3},
    ],
    "Narrator": [
        {"uri": "cidoc:E21_Person",
         "label": "CIDOC-CRM 인물",
         "confidence": 0.92,
         "priority": 1},
        {"uri": "foaf:Person",
         "label": "FOAF 인물",
         "confidence": 0.88,
         "priority": 2},
    ],
    # ... 나머지도 동일 패턴
}
```

### Flutter 매핑 카드 UI

```dart
// mapping_card.dart 수정 — 라디오 버튼 + confidence

Widget _buildSuggestionsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('추천 매핑',
          style: TextStyle(fontSize: 12,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 8),

      // 추천 후보 목록 — 라디오 버튼
      ...widget.item.suggestions.map((s) => InkWell(
        onTap: () => _selectSuggestion(s.uri),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _selectedUri == s.uri
                ? AppColors.primaryFaint
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _selectedUri == s.uri
                  ? AppColors.primary
                  : AppColors.border,
            ),
          ),
          child: Row(children: [
            // 라디오 버튼
            Radio<String>(
              value: s.uri,
              groupValue: _selectedUri,
              onChanged: (v) => _selectSuggestion(v!),
              activeColor: AppColors.primary,
              materialTapTargetSize:
                  MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),

            // URI
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.uri,
                      style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary)),
                  Text(s.label,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted)),
                ],
              ),
            ),

            // Confidence 바
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${(s.confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.confidence >= 0.9
                          ? AppColors.success
                          : s.confidence >= 0.7
                              ? AppColors.warning
                              : AppColors.textMuted,
                    )),
                const SizedBox(height: 3),
                // 신뢰도 바
                SizedBox(
                  width: 50,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: s.confidence,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(
                        s.confidence >= 0.9
                            ? AppColors.success
                            : s.confidence >= 0.7
                                ? AppColors.warning
                                : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]),
        ),
      )),

      const SizedBox(height: 10),

      // 직접 입력 옵션
      InkWell(
        onTap: () => setState(() => _selectedUri = 'custom'),
        child: Row(children: [
          Radio<String>(
            value: 'custom',
            groupValue: _selectedUri,
            onChanged: (v) => setState(() => _selectedUri = 'custom'),
            activeColor: AppColors.primary,
          ),
          const Text('직접 입력',
              style: TextStyle(fontSize: 12)),
        ]),
      ),

      if (_selectedUri == 'custom') ...[
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _customCtrl,
              style: const TextStyle(
                  fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '예: cidoc:E21_Person',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _applyTag(_customCtrl.text.trim()),
            child: const Text('적용'),
          ),
        ]),
      ],

      const SizedBox(height: 12),

      // 확정 버튼
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (_confirmed)
          OutlinedButton(
            onPressed: _unconfirm,
            child: const Text('확정 취소'),
          )
        else
          ElevatedButton(
            onPressed: _selectedUri != null &&
                _selectedUri != 'custom'
                ? _confirm
                : (_customCtrl.text.isNotEmpty ? _confirm : null),
            child: const Text('확정'),
          ),
      ]),
    ],
  );
}
```

---

## F4 — 확정 탭 Confirmed 상태만 표시

### 현재 문제

```
현재: Confirmed + Archived 모두 표시
목표: 활성 섹션 = Confirmed 만
      아카이브 섹션 = Archived 만 (기존 유지)
```

### Flutter 수정

```dart
// ontology_confirmed_tab.dart

// 활성 섹션 — Confirmed 만
final activeVersions = _versions
    .where((v) => v.status == 'confirmed')  // archived 제외
    .toList();

// 아카이브 섹션 — Archived 만
final archivedVersions = _versions
    .where((v) => v.status == 'archived')
    .toList();
```

### 백엔드 API 파라미터 명확화

```python
# GET /api/ontologies/?status=confirmed → Confirmed 만
# GET /api/ontologies/?status=archived  → Archived 만
# GET /api/ontologies/                  → 전체 (기존)
```

---

## 구현 순서

```
Phase 1: F4 (가장 간단)
  1-1. ontology_confirmed_tab.dart 필터 수정

Phase 2: F2 글자 수 경고
  2-1. input_method_bottom_sheet.dart 안내 + 카운터
  2-2. 파일 업로드 탭도 동일 적용

Phase 3: F3 표준화 confidence UI
  3-1. standard_mappings.py confidence 값 추가
  3-2. mapping_card.dart 라디오 버튼 + confidence 바

Phase 4: F1 임포트
  4-1. ontology/ontology_importer.py 신규
  4-2. POST /api/ontologies/import 엔드포인트
  4-3. Flutter 임포트 버튼 + 파일 선택 다이얼로그
```

---

## 완료 기준

```
F4: □ 확정 탭 활성 섹션에 Confirmed 만 표시
    □ Archived 는 아카이브 섹션에만 표시

F2: □ 입력창 아래 "권장 3,000자 · 최대 8,000자" 안내 표시
    □ 6,000자 초과: 노란 경고
    □ 8,000자 초과: 빨간 경고 + "잘려서 처리됩니다" 안내
    □ 파일 업로드 추출 후에도 동일 경고

F3: □ 추천 후보마다 confidence % 바 표시
    □ 라디오 버튼으로 선택
    □ 직접 입력 옵션 선택 시 텍스트 입력란 표시
    □ 선택 후 [확정] 클릭 시 저장

F1: □ [임포트] 팝업: JSON / CSV(클래스) / CSV(속성)
    □ JSON 임포트 → 작업 중 탭에 새 Draft 추가
    □ CSV 임포트 → 클래스 또는 속성만 가져오기
    □ 잘못된 형식 → 명확한 오류 메시지
```
