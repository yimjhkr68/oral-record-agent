import 'dart:async';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/graph_api.dart';
import '../models/triple.dart';
import '../widgets/graph/graph_node_model.dart';
import '../widgets/graph/force_layout.dart';

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
    );
  }

  static const _sentinel = Object();
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

  /// 전체 그래프 로드
  Future<void> loadGraph() async {
    _simTimer?.cancel();
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.fullGraph();

      final nodes = data.nodes.map((n) => LayoutNode(
        id: n.id,
        type: n.type,
        degree: n.degree,
        radius: 14 + min(n.degree * 2.0, 12),
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
      );

      _startSimulation();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 포스 시뮬레이션 — ~60fps, 수렴 시 정지
  void _startSimulation() {
    _simTimer?.cancel();
    state = state.copyWith(isSimulating: true);
    _simTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) { t.cancel(); return; }
      final converged = _layout.tick();
      state = state.copyWith(nodes: [..._layout.nodes]);
      if (converged) {
        t.cancel();
        state = state.copyWith(isSimulating: false);
      }
    });
  }

  /// 검색 — 매칭/이웃/나머지 투명도 설정
  void search(String query) {
    if (query.isEmpty) {
      for (final n in state.nodes) {
        n.opacity = 1.0;
        n.highlighted = false;
        n.radius = n.baseRadius;
      }
      for (final e in state.edges) {
        e.opacity = 1.0;
      }
      state = state.copyWith(searchQuery: '', nodes: [...state.nodes]);
      return;
    }

    final q = query.toLowerCase();
    final matched = state.nodes
        .where((n) => n.id.toLowerCase().contains(q))
        .map((n) => n.id)
        .toSet();

    final neighbors = <String>{};
    for (final e in state.edges) {
      if (matched.contains(e.sourceId)) neighbors.add(e.targetId);
      if (matched.contains(e.targetId)) neighbors.add(e.sourceId);
    }

    for (final n in state.nodes) {
      if (matched.contains(n.id)) {
        n.opacity = 1.0;
        n.highlighted = true;
        n.radius = n.baseRadius * 1.5;
      } else if (neighbors.contains(n.id)) {
        n.opacity = 0.7;
        n.highlighted = false;
        n.radius = n.baseRadius;
      } else {
        n.opacity = 0.2;
        n.highlighted = false;
        n.radius = n.baseRadius;
      }
    }

    for (final e in state.edges) {
      e.opacity = (matched.contains(e.sourceId) || matched.contains(e.targetId))
          ? 0.8
          : 0.1;
    }

    state = state.copyWith(searchQuery: query, nodes: [...state.nodes]);
  }

  /// 노드 드래그
  void onNodeDrag(String nodeId, Offset delta) {
    final idx = state.nodes.indexWhere((n) => n.id == nodeId);
    if (idx == -1) return;
    final node = state.nodes[idx];
    node.x += delta.dx;
    node.y += delta.dy;
    node.pinned = true;
    node.vx = 0;
    node.vy = 0;
    state = state.copyWith(nodes: [...state.nodes]);
  }

  /// 노드 선택
  void selectNode(String? nodeId) {
    for (final n in state.nodes) {
      n.selected = n.id == nodeId;
    }
    state = state.copyWith(selectedNodeId: nodeId, nodes: [...state.nodes]);
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
