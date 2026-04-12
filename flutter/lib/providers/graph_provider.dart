import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/graph_api.dart';
import '../models/triple.dart';
import '../services/graph_visibility_settings.dart';
import '../widgets/graph/graph_node_model.dart';
import '../widgets/graph/force_layout.dart';
import '../widgets/graph/cluster_detector.dart';

String _graphError(Object e) {
  if (e is DioException && e.type == DioExceptionType.connectionTimeout) {
    return '서버에 연결할 수 없습니다.';
  }
  if (e is DioException && e.type == DioExceptionType.receiveTimeout) {
    return '서버 응답이 지연되고 있습니다.';
  }
  if (e is DioException) {
    return '서버 오류 (${e.response?.statusCode ?? e.type.name})';
  }
  return e.toString();
}

// ── API provider ─────────────────────────────────────────────────────────────

final graphApiProvider = Provider<GraphApi>((ref) {
  return GraphApi(ref.read(apiClientProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

class GraphState {
  final List<LayoutNode> nodes;
  final List<LayoutEdge> edges;
  final List<Triple> rawTriples;
  final String searchQuery;
  final String? selectedNodeId;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic> stats;
  final bool isSimulating;
  final List<NarratorCluster> clusters;
  final String selectedOntologyVersion;

  const GraphState({
    this.nodes = const [],
    this.edges = const [],
    this.rawTriples = const [],
    this.searchQuery = '',
    this.selectedNodeId,
    this.isLoading = false,
    this.error,
    this.stats = const {},
    this.isSimulating = false,
    this.clusters = const [],
    this.selectedOntologyVersion = '',
  });

  GraphState copyWith({
    List<LayoutNode>? nodes,
    List<LayoutEdge>? edges,
    List<Triple>? rawTriples,
    String? searchQuery,
    Object? selectedNodeId = _sentinel,
    bool? isLoading,
    Object? error = _sentinel,
    Map<String, dynamic>? stats,
    bool? isSimulating,
    List<NarratorCluster>? clusters,
    String? selectedOntologyVersion,
  }) {
    return GraphState(
      nodes: nodes ?? this.nodes,
      edges: edges ?? this.edges,
      rawTriples: rawTriples ?? this.rawTriples,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedNodeId: identical(selectedNodeId, _sentinel)
          ? this.selectedNodeId
          : selectedNodeId as String?,
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _sentinel) ? this.error : error as String?,
      stats: stats ?? this.stats,
      isSimulating: isSimulating ?? this.isSimulating,
      clusters: clusters ?? this.clusters,
      selectedOntologyVersion:
          selectedOntologyVersion ?? this.selectedOntologyVersion,
    );
  }

  static const _sentinel = Object();

  /// 현재 선택된 LayoutNode (없으면 null)
  LayoutNode? get selectedNode => selectedNodeId == null
      ? null
      : nodes.where((n) => n.id == selectedNodeId).firstOrNull;
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class GraphNotifier extends StateNotifier<GraphState> {
  final GraphApi _api;
  Size _canvasSize = const Size(3000, 3000);
  late ForceLayout _layout;
  Timer? _simTimer;

  GraphNotifier(this._api) : super(const GraphState()) {
    _layout = ForceLayout(nodes: [], edges: [], canvasSize: _canvasSize);
  }

  void setCanvasSize(Size size) {
    _canvasSize = size;
  }

  /// 전체 그래프 로드 (ontologyVersion 빈 문자열 = 전체)
  Future<void> loadGraph({String ontologyVersion = ''}) async {
    _simTimer?.cancel();
    state = state.copyWith(
      isLoading: true,
      error: null,
      selectedOntologyVersion: ontologyVersion,
    );
    try {
      final data = await _api.fullGraph(ontologyVersion: ontologyVersion);

      final nodes = data.nodes.map((n) => LayoutNode(
        id: n.id,
        type: n.type,
        degree: n.degree,
        radius: radiusForNode(n.type, n.degree),
      )).toList();

      final edges = data.triples.map((t) => LayoutEdge(
        sourceId: t.subject,
        targetId: t.object,
        predicate: t.predicate,
      )).toList();

      _layout = ForceLayout(nodes: nodes, edges: edges, canvasSize: _canvasSize);
      _layout.initPositions();

      state = state.copyWith(
        nodes: nodes,
        edges: edges,
        rawTriples: data.triples,
        isLoading: false,
        stats: {'nodes': nodes.length, 'triples': edges.length},
        searchQuery: '',
        clusters: ClusterDetector.detect(nodes, edges),
      );

      _startSimulation();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _graphError(e));
    }
  }

  /// 포스 시뮬레이션 — ~60fps, 수렴 시 정지 + 군집 박스 분리
  void _startSimulation() {
    _simTimer?.cancel();
    state = state.copyWith(isSimulating: true);
    _simTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) { t.cancel(); return; }
      final converged = _layout.tick();
      state = state.copyWith(nodes: [..._layout.nodes]);
      if (converged) {
        t.cancel();
        // 군집 박스 겹침 분리 (노드 위치 직접 조정)
        ClusterDetector.separateClusters(state.clusters, _layout.nodes);
        // 분리 후 자동 군집 멤버십 재계산
        final autoClusters =
            ClusterDetector.detect(_layout.nodes, state.edges);
        state = state.copyWith(
          nodes: [..._layout.nodes],
          clusters: autoClusters,
          isSimulating: false,
        );
        // 사용자 정의 범주 병합 (비동기, fire-and-forget)
        reloadClusters();
      }
    });
  }

  /// 검색 — 노드 ID + 엣지 술어 동시 매칭
  void search(String query) {
    if (query.isEmpty) {
      for (final n in state.nodes) {
        n.opacity = 1.0;
        n.highlighted = false;
        n.radius = n.baseRadius;
      }
      for (final e in state.edges) {
        e.opacity = 1.0;
        e.highlighted = false;
      }
      state = state.copyWith(searchQuery: '', nodes: [...state.nodes]);
      return;
    }

    final q = query.toLowerCase();

    // 1. 노드 ID 매칭
    final nodeMatched = state.nodes
        .where((n) => n.id.toLowerCase().contains(q))
        .map((n) => n.id)
        .toSet();

    // 2. 엣지 술어 매칭
    final edgeMatched = state.edges
        .where((e) => e.predicate.toLowerCase().contains(q))
        .toSet();

    // 술어 매칭 엣지의 source/target 노드도 강조 대상에 추가
    for (final e in edgeMatched) {
      nodeMatched.add(e.sourceId);
      nodeMatched.add(e.targetId);
    }

    // 3. 1홉 이웃 수집
    final neighbors = <String>{};
    for (final e in state.edges) {
      if (nodeMatched.contains(e.sourceId)) neighbors.add(e.targetId);
      if (nodeMatched.contains(e.targetId)) neighbors.add(e.sourceId);
    }
    neighbors.removeAll(nodeMatched);

    // 4. 노드 투명도/강조
    for (final n in state.nodes) {
      if (nodeMatched.contains(n.id)) {
        n.opacity = 1.0;
        n.highlighted = true;
        n.radius = n.baseRadius * 1.5;
      } else if (neighbors.contains(n.id)) {
        n.opacity = 0.65;
        n.highlighted = false;
        n.radius = n.baseRadius;
      } else {
        n.opacity = 0.12;
        n.highlighted = false;
        n.radius = n.baseRadius;
      }
    }

    // 5. 엣지 투명도/강조
    for (final e in state.edges) {
      final isEdgeMatch = edgeMatched.contains(e);
      final isNodeMatch = nodeMatched.contains(e.sourceId) ||
          nodeMatched.contains(e.targetId);
      e.highlighted = isEdgeMatch;
      e.opacity = (isEdgeMatch || isNodeMatch) ? 1.0 : 0.05;
    }

    state = state.copyWith(searchQuery: query, nodes: [...state.nodes]);
  }

  static const _narratorTypes = {
    'Narrator', 'OralNarrator', 'OralHistoryNarrator',
  };

  /// 노드 드래그 — 구술자면 소속 군집 노드 함께 이동
  void onNodeDrag(String nodeId, Offset delta) {
    final idx = state.nodes.indexWhere((n) => n.id == nodeId);
    if (idx == -1) return;
    final node = state.nodes[idx];
    node.x += delta.dx;
    node.y += delta.dy;
    node.pinned = true;
    node.vx = 0;
    node.vy = 0;

    // 구술자 드래그 시 소속 군집 노드 함께 이동
    if (_narratorTypes.contains(node.type)) {
      final cluster = state.clusters
          .where((c) => c.narratorId == nodeId)
          .firstOrNull;
      if (cluster != null) {
        for (final n in state.nodes) {
          if (n.id == nodeId) continue;
          if (!cluster.nodeIds.contains(n.id)) continue;
          n.x += delta.dx;
          n.y += delta.dy;
          // pinned 는 false 유지 — 시뮬레이션이 계속 물리 계산
        }
      }
    }

    state = state.copyWith(nodes: [...state.nodes]);
  }

  /// 노드 선택
  void selectNode(String? nodeId) {
    for (final n in state.nodes) {
      n.selected = n.id == nodeId;
    }
    state = state.copyWith(selectedNodeId: nodeId, nodes: [...state.nodes]);
  }

  /// 사용자 정의 범주 + 자동 범주 재계산 후 그래프 상태 반영
  Future<void> reloadClusters() async {
    try {
      final res = await _api.getCustomClusters();
      final overrides = Map<String, String>.from(
        (res['node_overrides'] as Map? ?? {})
            .map((k, v) => MapEntry(k.toString(), v.toString())),
      );
      final customClusters = (res['clusters'] as List? ?? [])
          .map((c) => NarratorCluster.fromCustomJson(
              c as Map<String, dynamic>))
          .toList();
      final autoClusters = ClusterDetector.detect(
          state.nodes, state.edges, nodeOverrides: overrides);

      state = state.copyWith(
          clusters: [...customClusters, ...autoClusters]);
      applyVisibility();
    } catch (_) {}
  }

  /// 색상 설정 변경 후 그래프 화면 강제 갱신
  void applyColorSettings() {
    state = state.copyWith(nodes: [...state.nodes]);
  }

  /// 범주 표시/숨김 설정 적용
  void applyVisibility() {
    final nodeMap = {for (final n in state.nodes) n.id: n};

    // 범주별 숨김 적용
    for (final cluster in state.clusters) {
      final clusterVisible =
          GraphVisibilitySettings.isVisible(cluster.narratorId);
      for (final nodeId in cluster.nodeIds) {
        final node = nodeMap[nodeId];
        if (node != null) node.hidden = !clusterVisible;
      }
    }

    // 미분류 노드 처리 (어떤 cluster에도 없는 노드 — 기본 표시)
    final clusteredIds = state.clusters
        .expand((c) => c.nodeIds)
        .toSet();
    for (final node in state.nodes) {
      if (!clusteredIds.contains(node.id)) node.hidden = false;
    }

    // 엣지: 양쪽 노드 중 하나라도 숨겨지면 숨김
    for (final edge in state.edges) {
      final srcHidden = nodeMap[edge.sourceId]?.hidden ?? false;
      final tgtHidden = nodeMap[edge.targetId]?.hidden ?? false;
      edge.hidden = srcHidden || tgtHidden;
    }

    state = state.copyWith(
      nodes: [...state.nodes],
      edges: [...state.edges],
    );
  }

  /// 저장된 레이아웃 노드 위치 적용
  void applyLayout(List<dynamic> layoutNodes) {
    final posMap = <String, (double, double)>{
      for (final n in layoutNodes)
        n['id'] as String: (
          (n['x'] as num).toDouble(),
          (n['y'] as num).toDouble(),
        ),
    };

    for (final node in state.nodes) {
      if (posMap.containsKey(node.id)) {
        final (x, y) = posMap[node.id]!;
        node.x = x;
        node.y = y;
        node.pinned = true;
        node.vx = 0;
        node.vy = 0;
      }
    }
    state = state.copyWith(nodes: [...state.nodes]);
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final graphProvider = StateNotifierProvider<GraphNotifier, GraphState>((ref) {
  final api = ref.read(graphApiProvider);
  return GraphNotifier(api);
});
