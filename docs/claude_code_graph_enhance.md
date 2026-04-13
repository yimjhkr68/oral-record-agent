# 지식그래프 + 내보내기 개선 Plan

## 작업 목록

```
Fix 1. 트리플 내보내기 405 오류 수정
Fix 2. 노드 클릭 → 별도 상세 창
Fix 3. 속성(predicate)으로 그래프 검색
Fix 4. 클래스별 노드 색상 설정
```

---

## Fix 1 — 트리플 내보내기 405 오류

### 원인
```
405 Method Not Allowed
→ POST /api/triples/export 라우트가 없거나
  GET 으로만 등록되어 있음
```

### 확인
```bash
curl -X POST http://localhost:9000/api/triples/export \
  -H "Content-Type: application/json" \
  -d '{"status":"active"}'
# 405면 라우트 미등록

# 등록된 라우트 전체 확인
curl http://localhost:9000/openapi.json | python -m json.tool | grep "triples/export"
```

### 수정 — api/router_triple.py

```python
from fastapi.responses import Response
from datetime import datetime
import json

@router.post("/export")
def export_triples(data: dict):
    """트리플 내보내기 — 선택 ID 또는 상태/버전 필터"""
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
            triples = [t for t in triples
                       if t.ontology_version == version_filter]

    from dataclasses import asdict
    export_data = {
        "export_type": "triples",
        "exported_at": datetime.now().isoformat(),
        "total":       len(triples),
        "items":       [asdict(t) for t in triples],
    }
    filename = f"triples_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    return Response(
        content=json.dumps(export_data, ensure_ascii=False, indent=2),
        media_type="application/json",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        },
    )
```

### main.py 라우터 등록 확인
```python
# main.py 에 아래가 있는지 확인, 없으면 추가
from api.router_triple import router as triple_router
app.include_router(triple_router)
```

### 검증
```bash
curl -X POST http://localhost:9000/api/triples/export \
  -H "Content-Type: application/json" \
  -d '{"status":"active"}'
# 기대: 200 + JSON 파일 내용
```

---

## Fix 2 — 노드 클릭 → 별도 상세 창

### 현재 vs 목표
```
현재: 하단 BottomSheet (그래프와 겹침)
목표: 우측 슬라이드 패널 (그래프 옆에 나란히)
      또는 별도 Dialog (그래프 위에 띄움)
```

### 구현 — 우측 슬라이드 패널 방식

```dart
// knowledge_graph_screen.dart 수정

// 레이아웃: 그래프 | 상세 패널 (선택 시 등장)
Row(children: [

  // 그래프 캔버스
  Expanded(
    child: Stack(children: [
      InteractiveViewer(...),
      // 검색바, 범례 오버레이
    ]),
  ),

  // 우측 상세 패널 (노드 선택 시 슬라이드인)
  AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
    width: selectedNode != null ? 340 : 0,
    child: selectedNode != null
        ? NodeDetailPanel(
            node: selectedNode!,
            edges: graphState.edges,
            onClose: () => notifier.selectNode(null),
          )
        : const SizedBox.shrink(),
  ),
])
```

### NodeDetailPanel 위젯

```dart
// flutter/lib/screens/graph/node_detail_panel.dart

class NodeDetailPanel extends StatelessWidget {
  final LayoutNode node;
  final List<LayoutEdge> edges;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final outgoing = edges.where((e) => e.sourceId == node.id).toList();
    final incoming = edges.where((e) => e.targetId == node.id).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(children: [

        // ── 헤더 ──────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Row(children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: node.color,
              child: Text(node.id[0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.id,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(node.type,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClose,
            ),
          ]),
        ),

        // ── 연결 통계 ──────────────────────────────
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _statChip('나가는 관계', outgoing.length, Colors.blue),
            const SizedBox(width: 8),
            _statChip('들어오는 관계', incoming.length, Colors.green),
          ]),
        ),

        const Divider(height: 1),

        // ── 트리플 목록 ────────────────────────────
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(children: [
              TabBar(
                tabs: [
                  Tab(text: '나가는 (${outgoing.length})'),
                  Tab(text: '들어오는 (${incoming.length})'),
                ],
                labelStyle: const TextStyle(fontSize: 12),
              ),
              Expanded(
                child: TabBarView(children: [
                  _tripleList(outgoing, isOutgoing: true),
                  _tripleList(incoming, isOutgoing: false),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _tripleList(List<LayoutEdge> edges, {required bool isOutgoing}) {
    if (edges.isEmpty) {
      return const Center(
          child: Text('없음', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: edges.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = edges[i];
        return ListTile(
          dense: true,
          title: Text(
            isOutgoing
                ? '→ ${e.predicate} → ${e.targetId}'
                : '${e.sourceId} → ${e.predicate} →',
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: isOutgoing
              ? Text(e.targetId,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey))
              : Text(e.sourceId,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey)),
        );
      },
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Text('$count',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ]),
    );
  }
}
```

---

## Fix 3 — 속성(predicate)으로 그래프 검색

### 현재 검색 동작
```
노드 ID 에서만 검색
→ "경험하다" 입력 시 일치 노드 없음 → 전체 희미해짐
```

### 목표 동작
```
검색 대상: 노드 ID + 엣지 술어(predicate) 동시 검색

"경험하다" 입력 시:
  → predicate == "경험하다" 인 엣지 모두 찾기
  → 해당 엣지의 source + target 노드 강조
  → 나머지 노드 희미화
```

### 수정 — graph_provider.dart search()

```dart
void search(String query) {
  if (query.isEmpty) {
    _resetOpacity();
    state = state.copyWith(searchQuery: '');
    return;
  }

  final q = query.toLowerCase();

  // 1. 노드 ID 매칭
  final nodeMatched = state.nodes
      .where((n) => n.id.toLowerCase().contains(q))
      .map((n) => n.id)
      .toSet();

  // 2. 엣지 술어 매칭 (신규)
  final edgeMatched = state.edges
      .where((e) => e.predicate.toLowerCase().contains(q))
      .toSet();

  // 술어 매칭된 엣지의 source/target 노드도 강조
  for (final e in edgeMatched) {
    nodeMatched.add(e.sourceId);
    nodeMatched.add(e.targetId);
  }

  // 3. 1홉 이웃 수집 (노드 매칭 기준)
  final neighbors = <String>{};
  for (final e in state.edges) {
    if (nodeMatched.contains(e.sourceId)) neighbors.add(e.targetId);
    if (nodeMatched.contains(e.targetId)) neighbors.add(e.sourceId);
  }
  neighbors.removeAll(nodeMatched);

  // 4. 투명도 적용
  for (final n in state.nodes) {
    if (nodeMatched.contains(n.id)) {
      n.opacity     = 1.0;
      n.highlighted = true;
      n.radius      = (14 + min(n.degree * 2.0, 12)) * 1.5;
    } else if (neighbors.contains(n.id)) {
      n.opacity     = 0.7;
      n.highlighted = false;
      n.radius      = 14 + min(n.degree * 2.0, 12);
    } else {
      n.opacity     = 0.15;
      n.highlighted = false;
      n.radius      = 14 + min(n.degree * 2.0, 12);
    }
  }

  // 5. 엣지 투명도
  for (final e in state.edges) {
    final isEdgeMatch = edgeMatched.contains(e);
    final isNodeMatch = nodeMatched.contains(e.sourceId) ||
                        nodeMatched.contains(e.targetId);
    e.opacity = (isEdgeMatch || isNodeMatch) ? 1.0 : 0.05;
    // 술어 매칭 엣지는 강조색
    e.highlighted = isEdgeMatch;
  }

  state = state.copyWith(
    searchQuery: query,
    nodes: [...state.nodes],
  );
}
```

### LayoutEdge 에 highlighted 필드 추가

```dart
// graph_node_model.dart
class LayoutEdge {
  final String sourceId;
  final String targetId;
  final String predicate;
  double opacity;
  bool highlighted;  // ← 신규: 술어 매칭 강조

  LayoutEdge({
    required this.sourceId,
    required this.targetId,
    required this.predicate,
    this.opacity = 1.0,
    this.highlighted = false,
  });
}
```

### GraphPainter 에 강조 엣지 색상 추가

```dart
// graph_painter.dart _drawEdge()
void _drawEdge(Canvas canvas, LayoutEdge edge) {
  // 술어 매칭 엣지: 파란색 + 두꺼운 선
  final color = edge.highlighted
      ? Colors.blue.withOpacity(edge.opacity)
      : Colors.grey.withOpacity(edge.opacity * 0.6);
  final strokeWidth = edge.highlighted ? 2.5 : 1.2;

  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..style = PaintingStyle.stroke;

  // 강조 엣지는 술어 레이블 항상 표시
  if (edge.highlighted || edge.opacity > 0.5) {
    _drawEdgeLabel(canvas, s, t, edge.predicate, edge.opacity);
  }
}
```

### 검색창 힌트 텍스트 변경

```dart
// graph_search_bar.dart
TextField(
  decoration: const InputDecoration(
    hintText: '노드 또는 관계(속성)로 검색...',
    prefixIcon: Icon(Icons.search, size: 18),
  ),
)
```

---

## Fix 4 — 클래스별 노드 색상 설정

### 구조
```
기본값: 온톨로지 정의의 color 필드
설정 화면: 지식그래프 탭 하단 범례의 색상 점 클릭 → 색상 선택
저장: shared_preferences (로컬 영속)
```

### 색상 설정 흐름

```
범례에서 색상 점 클릭
  → ColorPickerDialog
  → 새 색상 선택
  → GraphColorSettings 에 저장 (shared_preferences)
  → 그래프 즉시 갱신
```

### GraphColorSettings 서비스

```dart
// flutter/lib/services/graph_color_settings.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 기본 클래스 색상 (온톨로지 정의 기반)
const Map<String, Color> kDefaultClassColors = {
  'Person':           Color(0xFFf59e0b),
  'Place':            Color(0xFF10b981),
  'Event':            Color(0xFFef4444),
  'Time':             Color(0xFF8b5cf6),
  'Organization':     Color(0xFF3b82f6),
  'Object':           Color(0xFFf97316),
  'Topic':            Color(0xFFec4899),
  'NarrativeSession': Color(0xFF14b8a6),
  'Community':        Color(0xFF06b6d4),
  'Policy':           Color(0xFF7c3aed),
  'Emotion':          Color(0xFFf43f5e),
  'Collection':       Color(0xFF64748b),
  // 구술기록 특화 클래스 (AI 생성 온톨로지에서 자주 등장)
  'Narrator':         Color(0xFFf59e0b),
  'OralNarrator':     Color(0xFFf59e0b),
  'Survivor':         Color(0xFFef4444),
  'Witness':          Color(0xFF3b82f6),
  'Victim':           Color(0xFFe11d48),
  'Interviewer':      Color(0xFF0ea5e9),
  'OralHistoryRecord':Color(0xFF14b8a6),
  'HistoricalEvent':  Color(0xFFef4444),
};

class GraphColorSettings {
  static const String _prefix = 'graph_color_';
  static final Map<String, Color> _cache = {};

  /// 앱 시작 시 저장된 색상 로드
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final className = key.replaceFirst(_prefix, '');
        final colorValue = prefs.getInt(key);
        if (colorValue != null) {
          _cache[className] = Color(colorValue);
        }
      }
    }
  }

  /// 클래스 색상 반환 (커스텀 → 기본값 순)
  static Color colorFor(String className) {
    return _cache[className]
        ?? kDefaultClassColors[className]
        ?? const Color(0xFF888888);
  }

  /// 클래스 색상 저장
  static Future<void> setColor(String className, Color color) async {
    _cache[className] = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix$className', color.value);
  }

  /// 특정 클래스 색상 초기화 (기본값으로)
  static Future<void> resetColor(String className) async {
    _cache.remove(className);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$className');
  }

  /// 전체 색상 초기화
  static Future<void> resetAll() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
  }

  /// 현재 사용 중인 전체 색상 맵 반환
  static Map<String, Color> get currentColors {
    final result = Map<String, Color>.from(kDefaultClassColors);
    result.addAll(_cache);
    return result;
  }
}
```

### 범례 위젯 — 색상 클릭 편집

```dart
// graph_legend.dart 수정

class GraphLegend extends ConsumerStatefulWidget { ... }

class _GraphLegendState extends ConsumerState<GraphLegend> {

  void _editColor(String className) async {
    final current = GraphColorSettings.colorFor(className);

    // flutter_colorpicker 패키지 사용
    Color picked = current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$className 색상 변경'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            onColorChanged: (c) => picked = c,
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await GraphColorSettings.resetColor(className);
              Navigator.pop(context, true);
            },
            child: const Text('기본값으로'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await GraphColorSettings.setColor(className, picked);
      ref.read(graphProvider.notifier).applyColorSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = GraphColorSettings.currentColors;
    final classes = colors.entries
        .where((e) => ref.watch(graphProvider).usedClasses.contains(e.key))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: classes.map((e) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => _editColor(e.key),
              child: Row(children: [
                // 색상 점 (클릭 가능)
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: e.value,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.grey.withOpacity(0.3), width: 1),
                  ),
                ),
                const SizedBox(width: 4),
                Text(e.key, style: const TextStyle(fontSize: 11)),
              ]),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
```

### pubspec.yaml 패키지 추가

```yaml
dependencies:
  flutter_colorpicker: ^1.1.0   # 색상 선택기
```

---

## 구현 순서

```
Phase 1 — 백엔드 (Fix 1)
  1-1. router_triple.py: POST /export 추가
  1-2. main.py 라우터 등록 확인
  1-3. curl 200 확인

Phase 2 — 노드 상세 패널 (Fix 2)
  2-1. node_detail_panel.dart 신규 생성
  2-2. knowledge_graph_screen.dart: Row 레이아웃으로 변경
  2-3. AnimatedContainer 슬라이드인 적용

Phase 3 — 속성 검색 (Fix 3)
  3-1. graph_node_model.dart: LayoutEdge.highlighted 추가
  3-2. graph_provider.dart: search() 술어 매칭 추가
  3-3. graph_painter.dart: 강조 엣지 색상/굵기 추가
  3-4. graph_search_bar.dart: 힌트 텍스트 변경

Phase 4 — 색상 설정 (Fix 4)
  4-1. flutter pub add flutter_colorpicker
  4-2. graph_color_settings.dart 신규 생성
  4-3. main.dart: GraphColorSettings.init() 호출
  4-4. graph_legend.dart: 탭 → 색상 편집 다이얼로그
  4-5. graph_provider.dart: applyColorSettings() 추가
```

---

## 완료 기준

```
Fix 1: [전체 내보내기] 클릭 → 파일 저장 다이얼로그 → JSON 저장

Fix 2: 노드 클릭 → 우측 패널 슬라이드인
       나가는/들어오는 관계 탭 표시
       ✕ 클릭 → 패널 닫힘

Fix 3: "경험하다" 검색 → 경험하다 엣지 파란색 강조
       관련 노드 강조 + 나머지 희미화
       노드 ID 검색도 기존대로 동작

Fix 4: 범례 색상 점 클릭 → 색상 선택기
       변경 → 그래프 즉시 갱신
       [기본값으로] 클릭 → 원래 색상 복원
       앱 재시작 후에도 커스텀 색상 유지
```

---

## 제약

```
- Phase 1 → 2 → 3 → 4 순서 유지
- 각 Phase 완료 후 보고
- flutter_colorpicker: pub.dev 최신 버전 사용
- 색상 저장: shared_preferences (별도 서버 API 불필요)
- 우측 패널 너비: 340px 고정
  (화면 너비 < 800px 이면 패널 대신 BottomSheet 대안)
```
