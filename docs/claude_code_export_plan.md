# 일괄 내보내기(Export) 기능 Plan

## 내보내기 대상

```
온톨로지: Draft / Confirmed(활성) / Archived — 복수 선택 → JSON
트리플:   생성(pending) / 확정(active) / 아카이브(archived) — 복수 선택 → JSON
```

---

## 내보내기 JSON 포맷

### 온톨로지 내보내기 포맷

```json
{
  "export_type": "ontologies",
  "exported_at": "2026-04-10T09:00:00",
  "total": 3,
  "items": [
    {
      "version_id":   "v2.0",
      "status":       "confirmed",
      "description":  "제주 4·3 구술 종합 온톨로지",
      "created_at":   "2026-04-09T10:00:00",
      "confirmed_at": "2026-04-09T11:00:00",
      "based_on":     "draft-001",
      "classes": [
        {
          "name":         "Person",
          "label_ko":     "인물",
          "color":        "#f59e0b",
          "description":  "구술의 주체가 되는 사람",
          "examples":     ["구술자", "면담자"],
          "standard_tag": "foaf:Person · cidoc:E21_Person"
        }
      ],
      "predicates": [
        {
          "name":         "출생지",
          "domain":       ["Person"],
          "range_":       ["Place"],
          "description":  "인물이 태어난 장소",
          "standard_tag": "cidoc:P98i_was_born · schema:birthPlace"
        }
      ]
    }
  ]
}
```

### 트리플 내보내기 포맷

```json
{
  "export_type": "triples",
  "exported_at": "2026-04-10T09:00:00",
  "total": 42,
  "items": [
    {
      "id":                "a1b2c3d4",
      "subject":           "김영수",
      "subject_type":      "Person",
      "predicate":         "출생지",
      "object":            "경상북도 안동",
      "object_type":       "Place",
      "ontology_version":  "v2.0",
      "source_record_id":  "NAR-202603-0006",
      "confidence":        0.95,
      "status":            "active",
      "created_at":        "2026-04-09T12:00:00",
      "note":              ""
    }
  ]
}
```

---

## 백엔드 API

```python
# api/router_ontology.py 에 추가
POST /api/ontologies/export
  body: { "version_ids": ["v1.0", "v2.0", "draft-001"] }
  response: JSON 파일 다운로드
  → 지정 버전들의 전체 정보 포함

# api/router_triple.py 에 추가
POST /api/triples/export
  body: {
    "triple_ids": ["id1", "id2", ...],  # 특정 ID 선택 시
    "status": "active",                  # 또는 상태로 전체 선택
    "ontology_version": "v2.0"           # 또는 버전으로 필터
  }
  → triple_ids 있으면 해당 ID만
  → 없으면 status/ontology_version 필터 적용
  response: JSON 파일 다운로드
```

### 구현 코드

```python
# api/router_ontology.py

from fastapi.responses import Response
import json
from datetime import datetime

@router.post("/export")
def export_ontologies(data: dict):
    version_ids = data.get("version_ids", [])
    if not version_ids:
        raise HTTPException(status_code=400, detail="version_ids 필요")

    items = []
    for vid in version_ids:
        try:
            v = ontology_manager.get(vid)
            items.append({
                "version_id":   v.version_id,
                "status":       v.status.value,
                "description":  v.description,
                "created_at":   v.created_at,
                "confirmed_at": v.confirmed_at,
                "based_on":     v.based_on,
                "classes": [
                    {
                        "name":         c.name,
                        "label_ko":     c.label_ko,
                        "color":        c.color,
                        "description":  c.description,
                        "examples":     c.examples,
                        "standard_tag": getattr(c, 'standard_tag', ''),
                    }
                    for c in v.classes
                ],
                "predicates": [
                    {
                        "name":         p.name,
                        "domain":       p.domain,
                        "range_":       p.range_,
                        "description":  p.description,
                        "standard_tag": getattr(p, 'standard_tag', ''),
                    }
                    for p in v.predicates
                ],
            })
        except KeyError:
            pass  # 없는 버전은 건너뜀

    export_data = {
        "export_type": "ontologies",
        "exported_at": datetime.now().isoformat(),
        "total": len(items),
        "items": items,
    }
    filename = f"ontologies_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    return Response(
        content=json.dumps(export_data, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


# api/router_triple.py

@router.post("/export")
def export_triples(data: dict):
    triple_ids     = data.get("triple_ids", [])
    status_filter  = data.get("status", "")
    version_filter = data.get("ontology_version", "")

    all_triples = graph_db.all_triples(include_archived=True)

    if triple_ids:
        triples = [t for t in all_triples if t.id in triple_ids]
    else:
        triples = all_triples
        if status_filter:
            triples = [t for t in triples if t.status.value == status_filter]
        if version_filter:
            triples = [t for t in triples if t.ontology_version == version_filter]

    from dataclasses import asdict
    export_data = {
        "export_type": "triples",
        "exported_at": datetime.now().isoformat(),
        "total": len(triples),
        "items": [asdict(t) for t in triples],
    }
    filename = f"triples_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    return Response(
        content=json.dumps(export_data, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
```

---

## Flutter UI — 내보내기 버튼 배치

### 온톨로지 화면 — 각 탭 상단

```
[작업 중] 탭:
  □ draft-001  □ draft-002  □ draft-003
  체크박스 복수 선택 → 상단 액션 바 등장
  ┌──────────────────────────────────────┐
  │ 3개 선택됨  [내보내기 ↓]  [종합]  [삭제] │
  └──────────────────────────────────────┘

[표준화] 탭:
  동일하게 체크박스 + [내보내기 ↓]

[확정] 탭:
  활성/아카이브 각 섹션에 체크박스
  혼합 선택 가능 → [내보내기 ↓]
```

### 트리플 화면 — Step 3 저장된 트리플

```
상단 필터 바 옆에:
  [전체 내보내기 ↓]  → 현재 필터 적용된 전체
  [선택 내보내기 ↓]  → 체크박스 선택 항목만

체크박스:
  각 트리플 행 왼쪽에 체크박스 추가
  헤더 체크박스로 전체 선택/해제
```

---

## Flutter 구현 코드

### 공통 ExportService

```dart
// flutter/lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

class ExportService {

  /// 온톨로지 내보내기
  static Future<void> exportOntologies({
    required ApiClient apiClient,
    required List<String> versionIds,
    required BuildContext context,
  }) async {
    if (versionIds.isEmpty) return;

    try {
      final response = await apiClient.postAI(
        '/api/ontologies/export',
        data: {'version_ids': versionIds},
      );

      await _saveFile(
        context: context,
        content: jsonEncode(response.data),
        defaultName: 'ontologies_export_${_timestamp()}.json',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  /// 트리플 내보내기
  static Future<void> exportTriples({
    required ApiClient apiClient,
    required BuildContext context,
    List<String>? tripleIds,       // 특정 선택
    String? statusFilter,           // 상태 전체
    String? ontologyVersion,        // 버전 전체
  }) async {
    try {
      final body = <String, dynamic>{};
      if (tripleIds != null && tripleIds.isNotEmpty) {
        body['triple_ids'] = tripleIds;
      } else {
        if (statusFilter != null) body['status'] = statusFilter;
        if (ontologyVersion != null) body['ontology_version'] = ontologyVersion;
      }

      final response = await apiClient.postAI(
        '/api/triples/export',
        data: body,
      );

      await _saveFile(
        context: context,
        content: jsonEncode(response.data),
        defaultName: 'triples_export_${_timestamp()}.json',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  /// 파일 저장 다이얼로그 (Windows/Android 공통)
  static Future<void> _saveFile({
    required BuildContext context,
    required String content,
    required String defaultName,
  }) async {
    // Windows: 저장 경로 선택
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'JSON 저장',
      fileName: defaultName,
      allowedExtensions: ['json'],
      type: FileType.custom,
    );
    if (savePath == null) return;

    final file = File(savePath);
    await file.writeAsString(content, encoding: utf8);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('저장 완료: $savePath')),
    );
  }

  static String _timestamp() =>
      DateTime.now().toString().replaceAll(RegExp(r'[:\s.]'), '_').substring(0, 19);
}
```

### 온톨로지 탭 — 선택 액션 바

```dart
// 각 탭에 추가할 선택 상태 + 액션 바

// State 변수
final Set<String> _selected = {};

// 목록 아이템
CheckboxListTile(
  value: _selected.contains(version.versionId),
  onChanged: (v) => setState(() {
    if (v == true) _selected.add(version.versionId);
    else           _selected.remove(version.versionId);
  }),
  title: Text(version.versionId),
  subtitle: Text(version.statusLabel),
)

// 선택 시 상단 액션 바
if (_selected.isNotEmpty)
  Container(
    color: Theme.of(context).colorScheme.primaryContainer,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(children: [
      Text('${_selected.length}개 선택됨',
          style: const TextStyle(fontWeight: FontWeight.w500)),
      const Spacer(),
      // 내보내기 버튼
      TextButton.icon(
        icon: const Icon(Icons.download_outlined, size: 18),
        label: const Text('내보내기'),
        onPressed: () => ExportService.exportOntologies(
          apiClient: ref.read(apiClientProvider),
          versionIds: _selected.toList(),
          context: context,
        ),
      ),
      // 탭별 추가 버튼 (작업 중: 종합, 삭제 등)
    ]),
  ),
```

### 트리플 Step 3 — 내보내기 버튼

```dart
// triple_step3_list.dart 상단에 추가

Row(children: [
  // 전체 내보내기
  OutlinedButton.icon(
    icon: const Icon(Icons.download_outlined, size: 16),
    label: const Text('전체 내보내기'),
    onPressed: () => ExportService.exportTriples(
      apiClient: ref.read(apiClientProvider),
      context: context,
      statusFilter: 'active',
    ),
  ),
  const SizedBox(width: 8),
  // 선택 내보내기 (체크박스 선택 시 활성)
  if (_selectedTripleIds.isNotEmpty)
    OutlinedButton.icon(
      icon: const Icon(Icons.download_outlined, size: 16),
      label: Text('선택 내보내기 (${_selectedTripleIds.length})'),
      onPressed: () => ExportService.exportTriples(
        apiClient: ref.read(apiClientProvider),
        context: context,
        tripleIds: _selectedTripleIds.toList(),
      ),
    ),
]),
```

---

## 구현 순서

```
Phase 1 — 백엔드 (우선)
  1-1. router_ontology.py: POST /api/ontologies/export
  1-2. router_triple.py: POST /api/triples/export
  1-3. curl 테스트 양쪽 모두 확인

Phase 2 — Flutter 공통 서비스
  2-1. flutter/lib/services/export_service.dart 신규 생성
  2-2. ApiClient.postAI() 에 export 용 응답 처리 추가
       (binary/JSON 파일 응답 처리)

Phase 3 — 온톨로지 화면 체크박스 + 내보내기
  3-1. [작업 중] 탭: 체크박스 + 액션 바 + [내보내기]
  3-2. [표준화] 탭: 동일
  3-3. [확정] 탭: 활성/아카이브 혼합 선택 가능

Phase 4 — 트리플 Step 3 내보내기
  4-1. 트리플 행 체크박스 추가
  4-2. [전체 내보내기] / [선택 내보내기] 버튼
  4-3. 필터(status/버전) 적용된 상태에서 전체 내보내기

Phase 5 — 테스트
  □ 온톨로지 Draft 3개 선택 → 내보내기 → JSON 파일 확인
  □ 온톨로지 혼합 선택(Draft+Confirmed) → 내보내기
  □ 트리플 개별 선택 → JSON 파일 확인
  □ 트리플 전체 내보내기 → 전체 포함 확인
  □ 내보낸 JSON 파일 구조 검증
```

---

## 완료 기준

```
Phase 1:
  □ curl -X POST /api/ontologies/export
    -d '{"version_ids":["v1.0","draft-001"]}'
    → JSON 파일 응답 (Content-Disposition 헤더 포함)
  □ curl -X POST /api/triples/export
    -d '{"status":"active"}'
    → active 트리플 전체 포함 JSON

Phase 3~4:
  □ 체크박스 선택 시 상단 액션 바 표시
  □ [내보내기] 클릭 → 파일 저장 다이얼로그 → 저장 완료 스낵바
  □ 저장된 JSON 파일: export_type, exported_at, total, items 포함
  □ items 배열에 선택한 항목만 포함되는지 확인
```

---

## 제약 조건

```
- Phase 1 curl 테스트 완료 후 Phase 2 시작
- ExportService 는 별도 파일로 분리
  (온톨로지/트리플 화면 양쪽에서 재사용)
- Windows: FilePicker 저장 다이얼로그 사용
- Android/Web: 추후 대응 (현재는 Windows 우선)
- 내보내기는 읽기 전용 작업 — DB 상태 변경 없음
- 대용량 방지: 한 번에 최대 100건으로 제한
  (초과 시 "최대 100건까지 선택 가능합니다" 안내)
```
