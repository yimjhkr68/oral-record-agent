# 빌드 정리 + 이력 삭제 + 지식그래프 군집 개선 Plan

## 작업 목록

```
Task 1. 빌드 시 테스트 온톨로지 자동 삭제
Task 2. 이력 전체/선택 삭제 기능
Task 3. 지식그래프 진입 시 전체 노드 화면에 맞게 배치
Task 4. 구술자 중심 군집(Cluster) 시각화
Task 5. 구술자 노드 드래그 시 소속 노드 함께 이동
```

---

## Task 1 — 빌드 시 테스트 온톨로지 자동 삭제

### 정리 스크립트

```python
# scripts/cleanup_test_ontologies.py

"""
빌드/배포 전 테스트용 온톨로지를 자동 삭제하는 스크립트.
실행: python scripts/cleanup_test_ontologies.py
"""

import os, json, shutil
from pathlib import Path

# 테스트용 버전ID 패턴 (이 패턴에 해당하면 삭제)
TEST_PATTERNS = [
    "test-",
    "debug-",
    "temp-",
    "draft-test",
    "fix-test",
]

# 절대 삭제 안 할 버전ID 화이트리스트
WHITELIST = [
    "v1_ontology",
    "v1.0",
    "v2.0",
    "v3.0",
]

ONTOLOGY_DIRS = [
    "data/ontologies/drafts",
    "data/ontologies/confirmed",
    "data/ontologies/archived",
]

def is_test_version(version_id: str) -> bool:
    if version_id in WHITELIST:
        return False
    return any(version_id.startswith(p) for p in TEST_PATTERNS)

def cleanup():
    deleted = []
    kept = []

    for dir_path in ONTOLOGY_DIRS:
        path = Path(dir_path)
        if not path.exists():
            continue
        for f in path.glob("*.json"):
            version_id = f.stem
            if is_test_version(version_id):
                f.unlink()
                deleted.append(f"{dir_path}/{version_id}")
            else:
                kept.append(version_id)

    print(f"삭제됨 ({len(deleted)}개):")
    for d in deleted: print(f"  - {d}")
    print(f"\n유지됨 ({len(kept)}개):")
    for k in kept: print(f"  + {k}")

if __name__ == "__main__":
    cleanup()
```

### pubspec.yaml 빌드 스크립트 연동

```yaml
# flutter/pubspec.yaml 에 추가
# (flutter build windows 전에 자동 실행)
```

```bash
# build.bat — Windows 빌드 스크립트
python scripts/cleanup_test_ontologies.py
cd flutter && flutter build windows --release
```

---

## Task 2 — 이력 전체/선택 삭제

### 백엔드 API

```python
# api/router_history.py 에 추가

@router.delete("/ontology/all")
def clear_all_ontology_events():
    count = history_store.clear_all_ontology_events()
    return {"deleted": count}

@router.delete("/ontology/bulk")
def delete_ontology_events_bulk(data: dict):
    ids = data.get("event_ids", [])
    count = history_store.delete_ontology_events_bulk(ids)
    return {"deleted": count}

@router.delete("/ontology/{event_id}")
def delete_ontology_event(event_id: str):
    ok = history_store.delete_ontology_event(event_id)
    if not ok:
        raise HTTPException(404, "이벤트 없음")
    return {"deleted": event_id}

@router.delete("/extractions/all")
def clear_all_sessions():
    count = history_store.clear_all_sessions()
    return {"deleted": count}

@router.delete("/extractions/bulk")
def delete_sessions_bulk(data: dict):
    ids = data.get("session_ids", [])
    count = history_store.delete_sessions_bulk(ids)
    return {"deleted": count}

@router.delete("/extractions/{session_id}")
def delete_session(session_id: str):
    ok = history_store.delete_session(session_id)
    if not ok:
        raise HTTPException(404, "세션 없음")
    return {"deleted": session_id}

@router.delete("/all")
def clear_all_history():
    result = history_store.clear_all()
    return {"deleted": result}
```

### Flutter UI

```dart
// history_screen.dart

// 상단 AppBar 액션
AppBar(
  title: const Text('이력'),
  actions: [
    // 현재 탭 전체 삭제
    TextButton.icon(
      icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 18),
      label: const Text('탭 전체 삭제',
          style: TextStyle(color: Colors.red, fontSize: 13)),
      onPressed: () => _clearCurrentTab(),
    ),
    // 전체 삭제
    IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.red),
      tooltip: '모든 이력 삭제',
      onPressed: _clearAll,
    ),
  ],
)

// 각 이력 탭 — 선택 삭제 모드
// 탭 내부 상단 액션 바
Row(children: [
  // 선택 모드 토글
  TextButton.icon(
    icon: Icon(_isSelectMode ? Icons.close : Icons.checklist, size: 16),
    label: Text(_isSelectMode ? '취소' : '선택 삭제',
        style: const TextStyle(fontSize: 12)),
    onPressed: () => setState(() {
      _isSelectMode = !_isSelectMode;
      _selectedIds.clear();
    }),
  ),
  if (_isSelectMode && _selectedIds.isNotEmpty) ...[
    const Spacer(),
    ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
      icon: const Icon(Icons.delete, size: 16, color: Colors.white),
      label: Text('${_selectedIds.length}개 삭제',
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      onPressed: _deleteBulk,
    ),
  ],
])

// 이력 행 — 체크박스 + 단건 삭제
ListTile(
  leading: _isSelectMode
      ? Checkbox(
          value: _selectedIds.contains(item.id),
          onChanged: (v) => setState(() {
            if (v == true) _selectedIds.add(item.id);
            else           _selectedIds.remove(item.id);
          }),
        )
      : _iconForEvent(item),
  title: ...,
  trailing: _isSelectMode
      ? null
      : IconButton(
          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
          onPressed: () => _deleteSingle(item.id),
        ),
)
```

---

## Task 3 — 그래프 진입 시 전체 화면 맞춤 배치

### 초기 줌/패닝 자동 조정

```dart
// knowledge_graph_screen.dart

// 시뮬레이션 수렴 후 자동으로 전체 화면에 맞게 줌 조정
void _fitToScreen() {
  final state = ref.read(graphProvider);
  if (state.nodes.isEmpty) return;

  // 노드 바운딩 박스 계산
  double minX = double.infinity, maxX = double.negativeInfinity;
  double minY = double.infinity, maxY = double.negativeInfinity;
  for (final n in state.nodes) {
    minX = min(minX, n.x - n.radius);
    maxX = max(maxX, n.x + n.radius);
    minY = min(minY, n.y - n.radius);
    maxY = max(maxY, n.y + n.radius);
  }

  final graphWidth  = maxX - minX;
  final graphHeight = maxY - minY;
  final screenSize  = MediaQuery.of(context).size;
  final availableW  = screenSize.width - 80;   // 사이드바 제외
  final availableH  = screenSize.height - 120; // 상단 바 제외

  // 스케일 계산 (여백 10% 포함)
  final scaleX = availableW / (graphWidth  * 1.1);
  final scaleY = availableH / (graphHeight * 1.1);
  final scale  = min(scaleX, scaleY).clamp(0.05, 2.0);

  // 중앙 정렬
  final centerX = (minX + maxX) / 2;
  final centerY = (minY + maxY) / 2;
  final tx = availableW / 2 - centerX * scale;
  final ty = availableH / 2 - centerY * scale;

  // TransformationController 에 적용
  final matrix = Matrix4.identity()
    ..translate(tx, ty)
    ..scale(scale);

  setState(() => _transformCtrl.value = matrix);
}

// 시뮬레이션 수렴 후 자동 호출
void _startSimulation() {
  _simTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
    final converged = _layout.tick();
    state = state.copyWith(nodes: [..._layout.nodes]);
    if (converged) {
      t.cancel();
      state = state.copyWith(isSimulating: false);
      // 수렴 후 자동 fit
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitToScreen();
      });
    }
  });
}

// [전체 보기] 버튼 추가
IconButton(
  icon: const Icon(Icons.fit_screen),
  tooltip: '전체 보기',
  onPressed: _fitToScreen,
),
```

---

## Task 4 — 구술자 중심 군집 시각화

### 군집 탐지 알고리즘

```dart
// flutter/lib/widgets/graph/cluster_detector.dart

class NarratorCluster {
  final String narratorId;    // 구술자 노드 ID
  final Set<String> nodeIds;  // 소속 노드 ID 목록
  final Color color;          // 군집 배경색

  NarratorCluster({
    required this.narratorId,
    required this.nodeIds,
    required this.color,
  });
}

class ClusterDetector {

  static const _narratorTypes = {
    'Narrator', 'OralNarrator', 'OralHistoryNarrator',
  };

  // 군집 감지: 구술자에서 2홉 이내 노드를 같은 군집으로
  static List<NarratorCluster> detect(
      List<LayoutNode> nodes, List<LayoutEdge> edges) {

    final narrators = nodes.where((n) => _narratorTypes.contains(n.type));
    final clusters = <NarratorCluster>[];

    // 군집 색상 팔레트 (반투명)
    final palette = [
      const Color(0x151565C0),  // 파랑
      const Color(0x15C62828),  // 빨강
      const Color(0x152E7D32),  // 초록
      const Color(0x156A1B9A),  // 보라
      const Color(0x15EF6C00),  // 주황
      const Color(0x15880E4F),  // 자주
    ];

    int colorIdx = 0;
    for (final narrator in narrators) {
      // 1홉 직접 연결 노드
      final directNeighbors = <String>{};
      for (final e in edges) {
        if (e.sourceId == narrator.id) directNeighbors.add(e.targetId);
        if (e.targetId == narrator.id) directNeighbors.add(e.sourceId);
      }

      // 2홉 이웃 (직접 연결 노드의 이웃)
      final twoHopNeighbors = <String>{};
      for (final e in edges) {
        if (directNeighbors.contains(e.sourceId))
          twoHopNeighbors.add(e.targetId);
        if (directNeighbors.contains(e.targetId))
          twoHopNeighbors.add(e.sourceId);
      }

      final clusterNodes = <String>{narrator.id}
          ..addAll(directNeighbors)
          ..addAll(twoHopNeighbors);

      clusters.add(NarratorCluster(
        narratorId: narrator.id,
        nodeIds: clusterNodes,
        color: palette[colorIdx % palette.length],
      ));
      colorIdx++;
    }

    return clusters;
  }
}
```

### 군집 배경 렌더링

```dart
// graph_painter.dart — paint() 에서 노드/엣지보다 먼저 그리기

void _drawClusters(Canvas canvas, List<NarratorCluster> clusters,
    List<LayoutNode> nodes) {
  for (final cluster in clusters) {
    final clusterNodes = nodes
        .where((n) => cluster.nodeIds.contains(n.id))
        .toList();
    if (clusterNodes.length < 2) continue;

    // 군집 볼록 다각형(Convex Hull) 또는 타원 그리기
    _drawClusterBackground(canvas, clusterNodes, cluster.color);
  }
}

void _drawClusterBackground(Canvas canvas, List<LayoutNode> nodes,
    Color color) {
  if (nodes.isEmpty) return;

  // 바운딩 박스 + 패딩
  double minX = nodes.map((n) => n.x).reduce(min) - 40;
  double maxX = nodes.map((n) => n.x).reduce(max) + 40;
  double minY = nodes.map((n) => n.y).reduce(min) - 40;
  double maxY = nodes.map((n) => n.y).reduce(max) + 40;

  final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
  final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(30));

  // 반투명 배경
  canvas.drawRRect(rrect, Paint()..color = color);

  // 테두리
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = color.withOpacity(color.opacity * 5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}

// GraphState 에 clusters 추가
class GraphState {
  ...
  final List<NarratorCluster> clusters;
  ...
}

// loadGraph() 완료 후 군집 계산
state = state.copyWith(
  clusters: ClusterDetector.detect(nodes, edges),
);
```

---

## Task 5 — 구술자 드래그 시 소속 노드 함께 이동

### 드래그 핸들러 수정

```dart
// graph_provider.dart

// 현재 드래그 중인 노드가 구술자인지 확인
void onNodeDrag(String nodeId, Offset delta) {
  final node = state.nodes.firstWhere((n) => n.id == nodeId);
  node.x += delta.dx;
  node.y += delta.dy;
  node.pinned = true;
  node.vx = 0;
  node.vy = 0;

  // 구술자면 소속 군집 노드도 함께 이동
  const narratorTypes = {'Narrator','OralNarrator','OralHistoryNarrator'};
  if (narratorTypes.contains(node.type)) {
    // 이 구술자의 군집 찾기
    final cluster = state.clusters
        .cast<NarratorCluster?>()
        .firstWhere((c) => c?.narratorId == nodeId, orElse: () => null);

    if (cluster != null) {
      for (final n in state.nodes) {
        if (n.id == nodeId) continue;         // 구술자 자신 제외
        if (!cluster.nodeIds.contains(n.id)) continue; // 군집 외 제외
        // 소속 노드도 같은 delta 만큼 이동
        n.x += delta.dx;
        n.y += delta.dy;
        // pinned 는 false 유지 (시뮬레이션 계속 받음)
      }
    }
  }

  state = state.copyWith(nodes: [...state.nodes]);
}
```

---

## 구현 순서

```
Phase 1 — 백엔드 정리
  1-1. scripts/cleanup_test_ontologies.py 생성
  1-2. 테스트 온톨로지 즉시 실행해서 정리
  1-3. history API DELETE 엔드포인트 추가

Phase 2 — 이력 삭제 UI
  2-1. history_store.py 삭제 메서드 추가
  2-2. history_screen.dart 전체/선택 삭제 UI

Phase 3 — 그래프 전체 보기
  3-1. _fitToScreen() 구현
  3-2. 시뮬레이션 수렴 후 자동 호출
  3-3. [전체 보기] 버튼 추가

Phase 4 — 군집 시각화
  4-1. cluster_detector.dart 신규 생성
  4-2. GraphState 에 clusters 필드 추가
  4-3. graph_painter.dart 군집 배경 렌더링
  4-4. GraphNotifier.loadGraph() 완료 후 군집 계산

Phase 5 — 군집 드래그
  5-1. onNodeDrag() 구술자 감지 + 소속 노드 함께 이동
  5-2. 드래그 후 군집 배경 재계산
```

---

## 완료 기준

```
Phase 1:
  □ python scripts/cleanup_test_ontologies.py 실행
    → 테스트 온톨로지 삭제, v1_ontology 유지
  □ DELETE /api/history/all → 200

Phase 2:
  □ 이력 탭 → [모든 이력 삭제] → 전체 삭제
  □ [선택 삭제] 모드 → 체크박스 → N개 삭제
  □ 각 행 휴지통 → 단건 삭제

Phase 3:
  □ 지식그래프 탭 진입 → 포스 레이아웃 수렴 후
    전체 노드가 화면 안에 맞게 자동 배치
  □ [전체 보기] 버튼 → 언제든 재조정

Phase 4:
  □ 구술자별 반투명 배경 군집 표시
  □ 구술자 수만큼 다른 색상
  □ 군집 경계가 소속 노드를 감싸는 형태

Phase 5:
  □ 구술자 노드 드래그 → 소속 노드 전체 함께 이동
  □ 일반 노드 드래그 → 해당 노드만 이동
  □ 드래그 후 군집 배경 자동 업데이트
```

---

## 제약 조건

```
- Phase 1 완료 후 Phase 2 시작 (단계별 승인)
- cleanup 스크립트는 WHITELIST 에 있는 버전은 절대 삭제 안 함
- 군집 배경: 완전 불투명 금지 (노드/엣지 가려짐)
  → rgba 알파값 0.08~0.15 유지
- 구술자 드래그 시 소속 노드의 pinned 는 false 유지
  (시뮬레이션이 계속 물리 계산)
- _fitToScreen() 은 시뮬레이션 완전 수렴 후에만 호출
  (수렴 전 호출 시 레이아웃이 불안정)
```
