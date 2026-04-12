import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:screenshot/screenshot.dart';

import '../../api/api_client.dart';
import '../../providers/graph_provider.dart';
import '../../services/graph_color_settings.dart';
import '../../services/graph_export_service.dart';
import '../../widgets/graph/graph_painter.dart';
import 'cluster_panel.dart';
import 'graph_legend.dart';
import 'graph_search_bar.dart';
import 'node_detail_panel.dart';

// ── 메인 화면 ─────────────────────────────────────────────────────────────────

class KnowledgeGraphScreen extends ConsumerStatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  ConsumerState<KnowledgeGraphScreen> createState() =>
      _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState
    extends ConsumerState<KnowledgeGraphScreen>
    with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  final _transformCtrl = TransformationController();
  final _screenshotCtrl = ScreenshotController();
  String _selectedOntology = '';
  List<Map<String, String>> _ontologies = const [
    {'id': '', 'label': '전체 (모든 트리플)'},
  ];
  bool _isDraggingNode = false;
  String? _draggingNodeId;
  Offset? _lastDragPos;
  bool _isOverNode = false;
  Size _viewportSize = Size.zero;
  bool _showClusterPanel = false;
  AnimationController? _fitAnimCtrl;
  Animation<Matrix4>? _fitAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadOntologies();
      // 노드가 없을 때만 로드 — 탭 재진입 시 기존 상태(위치, 검색어) 유지
      if (ref.read(graphProvider).nodes.isEmpty) {
        ref.read(graphProvider.notifier).loadGraph();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _transformCtrl.dispose();
    _fitAnimCtrl?.dispose();
    super.dispose();
  }

  // ── 온톨로지 목록 로드 ────────────────────────────────────────────────────

  Future<void> _loadOntologies() async {
    try {
      final res = await ref.read(apiClientProvider).get(
        '/api/ontologies/',
        params: {'status': 'confirmed'},
      );
      if (!mounted) return;
      final items = (res.data['items'] ?? res.data['versions'] ?? []) as List;
      setState(() {
        _ontologies = [
          {'id': '', 'label': '전체 (모든 트리플)'},
          ...items.map((v) => {
                'id': v['version_id'] as String,
                'label':
                    '${v['version_id']} (클래스 ${v['class_count'] ?? '?'}개)',
              }),
        ];
      });
    } catch (_) {
      // 로드 실패 시 기본값(전체) 유지
    }
  }

  // ── 좌표 변환 헬퍼 ───────────────────────────────────────────────────────

  Offset _toCanvas(Offset local) => MatrixUtils.transformPoint(
        Matrix4.inverted(_transformCtrl.value),
        local,
      );

  // ── 노드 탭 감지 ──────────────────────────────────────────────────────────

  void _onTapCanvas(TapUpDetails d, GraphState gs) {
    final pos = _toCanvas(d.localPosition);
    for (final node in gs.nodes) {
      if ((Offset(node.x, node.y) - pos).distance <= node.radius + 4) {
        ref.read(graphProvider.notifier).selectNode(node.id);
        return;
      }
    }
    ref.read(graphProvider.notifier).selectNode(null);
  }

  // ── 노드 드래그 (LongPress) ───────────────────────────────────────────────

  void _onLongPressStart(LongPressStartDetails d, GraphState gs) {
    final pos = _toCanvas(d.localPosition);
    for (final node in gs.nodes) {
      if ((Offset(node.x, node.y) - pos).distance <= node.radius + 8) {
        setState(() {
          _isDraggingNode = true;
          _draggingNodeId = node.id;
          _lastDragPos = pos;
        });
        ref.read(graphProvider.notifier).selectNode(node.id);
        return;
      }
    }
  }

  void _onLongPressDrag(LongPressMoveUpdateDetails d) {
    if (!_isDraggingNode || _draggingNodeId == null) return;
    final pos = _toCanvas(d.localPosition);
    if (_lastDragPos == null) {
      _lastDragPos = pos;
      return;
    }
    final delta = pos - _lastDragPos!;
    _lastDragPos = pos;
    ref.read(graphProvider.notifier).onNodeDrag(_draggingNodeId!, delta);
  }

  void _onLongPressEnd() {
    setState(() {
      _isDraggingNode = false;
      _draggingNodeId = null;
      _lastDragPos = null;
    });
  }

  // ── 전체 보기 (fit-to-screen) ─────────────────────────────────────────────

  void _fitToScreen() {
    final gs = ref.read(graphProvider);
    final visibleNodes = gs.nodes.where((n) => !n.hidden).toList();
    if (visibleNodes.isEmpty || _viewportSize == Size.zero) return;

    double minX = double.infinity,  minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final node in visibleNodes) {
      if (node.x - node.radius < minX) minX = node.x - node.radius;
      if (node.y - node.radius < minY) minY = node.y - node.radius;
      if (node.x + node.radius > maxX) maxX = node.x + node.radius;
      if (node.y + node.radius > maxY) maxY = node.y + node.radius;
    }

    const padding = 48.0;
    minX -= padding; minY -= padding;
    maxX += padding; maxY += padding;

    final contentW = maxX - minX;
    final contentH = maxY - minY;
    if (contentW <= 0 || contentH <= 0) return;

    final scale = min(
      _viewportSize.width  / contentW,
      _viewportSize.height / contentH,
    ).clamp(0.05, 5.0);

    final tx = (_viewportSize.width  - contentW * scale) / 2 - minX * scale;
    final ty = (_viewportSize.height - contentH * scale) / 2 - minY * scale;

    _animateToMatrix(Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty));
  }

  void _animateToMatrix(Matrix4 target) {
    _fitAnimCtrl?.dispose();
    _fitAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fitAnim = Matrix4Tween(
      begin: _transformCtrl.value,
      end: target,
    ).animate(CurvedAnimation(parent: _fitAnimCtrl!, curve: Curves.easeInOut));
    _fitAnim!.addListener(() {
      if (mounted) _transformCtrl.value = _fitAnim!.value;
    });
    _fitAnimCtrl!.forward();
  }

  // ── 레이아웃 저장/불러오기 ─────────────────────────────────────────────────

  void _onLayout(String action) {
    if (action == 'save') {
      _showSaveLayoutDialog();
    } else if (action == 'load') {
      _showLoadLayoutDialog();
    }
  }

  void _showSaveLayoutDialog() {
    final now = DateTime.now();
    final defaultName =
        '레이아웃_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final ctrl = TextEditingController(text: defaultName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('레이아웃 저장'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '레이아웃 이름',
                hintText: '예: 2026-04-12 작업본',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              Navigator.of(ctx).pop();
              if (name.isNotEmpty) await _saveLayout(name);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLayout(String name) async {
    final gs = ref.read(graphProvider);
    if (gs.nodes.isEmpty) return;

    final nodes = gs.nodes.map((n) => {
      'id':     n.id,
      'x':      n.x,
      'y':      n.y,
      'pinned': n.pinned,
    }).toList();

    try {
      await ref.read(apiClientProvider).post('/api/graph/layouts', data: {
        'name': name,
        'ontology_version': gs.selectedOntologyVersion,
        'nodes': nodes,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레이아웃 저장됨: $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLoadLayoutDialog() async {
    List<dynamic> layouts = [];
    try {
      final res = await ref.read(apiClientProvider).get('/api/graph/layouts');
      layouts = (res.data['layouts'] as List? ?? []);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('목록 로드 실패: $e'), backgroundColor: Colors.red),
      );
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => _LoadLayoutDialog(
        layouts: layouts,
        onLoad: (filename) async {
          Navigator.of(ctx).pop();
          await _loadLayout(filename);
        },
        onDelete: (filename) async {
          try {
            await ref.read(apiClientProvider)
                .delete('/api/graph/layouts/$filename');
          } catch (_) {}
          if (ctx.mounted) Navigator.of(ctx).pop();
          // 다이얼로그 닫고 다시 열기
          if (mounted) _showLoadLayoutDialog();
        },
      ),
    );
  }

  Future<void> _loadLayout(String filename) async {
    try {
      final res = await ref.read(apiClientProvider)
          .get('/api/graph/layouts/$filename');
      final layoutNodes =
          (res.data['nodes'] ?? res.data['node_positions'] ?? []) as List;
      ref.read(graphProvider.notifier).applyLayout(layoutNodes);
      // 위치 복원 후 전체 보기 (postFrame — 레이아웃 확정 후 실행)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fitToScreen();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('레이아웃 불러옴: ${res.data["name"]}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('불러오기 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Print (PNG / PDF) ─────────────────────────────────────────────────────

  Future<void> _onPrint(String fmt, GraphState gs) async {
    if (fmt == 'png') {
      await GraphExportService.exportPng(_screenshotCtrl, context);
    } else {
      await GraphExportService.exportPdf(
        _screenshotCtrl,
        context,
        nodeCount: gs.nodes.length,
        edgeCount: gs.edges.length,
      );
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _showExportDialog() async {
    // 1. async 시작 전 현재 상태를 로컬 변수로 복사 (stale 참조 방지)
    final gs = ref.read(graphProvider);
    if (gs.nodes.isEmpty && gs.rawTriples.isEmpty) return;

    final hasSearch = gs.searchQuery.isNotEmpty;
    final searchQuery = gs.searchQuery;

    // 숨겨진 노드 제외 + 검색 시 opacity > 0.5 필터 (강조 + 1홉 이웃)
    final exportNodes = gs.nodes
        .where((n) => !n.hidden && (!hasSearch || n.opacity > 0.5))
        .toList();
    final exportEdges = gs.edges
        .where((e) => !e.hidden && (!hasSearch || e.opacity > 0.5))
        .toList();

    final isFiltered = exportNodes.length < gs.nodes.length;

    // rawTriples: 내보낼 노드에 포함된 subject/object 쌍만 필터
    final exportNodeIds = exportNodes.map((n) => n.id).toSet();
    final exportRawTriples = isFiltered
        ? gs.rawTriples
            .where((t) =>
                exportNodeIds.contains(t.subject) &&
                exportNodeIds.contains(t.object))
            .toList()
        : List.from(gs.rawTriples);

    // 2. 형식 선택 다이얼로그 — builder ctx 사용 (outer context 사용 금지)
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(hasSearch ? '서브그래프 내보내기'
            : isFiltered ? '부분 그래프 내보내기' : '전체 그래프 내보내기'),
        content: Text(hasSearch
            ? '검색어 "$searchQuery" 기준\n노드 ${exportNodes.length}개 · 엣지 ${exportEdges.length}개'
            : isFiltered
                ? '표시 중인 범주 기준\n노드 ${exportNodes.length} / ${gs.nodes.length}개 · 엣지 ${exportEdges.length} / ${gs.edges.length}개'
                : '노드 ${exportNodes.length}개 · 엣지 ${exportEdges.length}개'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'json'),
              child: const Text('JSON')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'csv'),
              child: const Text('CSV')),
        ],
      ),
    );
    if (format == null || !mounted) return;

    await _exportGraph(
      format: format,
      exportNodes: exportNodes,
      exportEdges: exportEdges,
      exportRawTriples: exportRawTriples,
      hasSearch: hasSearch,
      isFiltered: isFiltered,
      searchQuery: searchQuery,
    );
  }

  Future<void> _exportGraph({
    required String format,
    required List<dynamic> exportNodes,
    required List<dynamic> exportEdges,
    required List<dynamic> exportRawTriples,
    required bool hasSearch,
    required bool isFiltered,
    required String searchQuery,
  }) async {
    // 3. JSON/CSV 생성 (동기 — provider 접근 없음, 로컬 변수만 사용)
    String content;
    String defaultName;

    final ts = DateTime.now().millisecondsSinceEpoch;

    try {
      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln(
            'subject,subject_type,predicate,object,object_type,'
            'confidence,ontology_version,source_record_id,created_at,note');
        String esc(String s) => '"${s.replaceAll('"', '""')}"';
        for (final t in exportRawTriples) {
          buf.writeln(
              '${esc(t.subject)},${esc(t.subjectType)},${esc(t.predicate)},'
              '${esc(t.object)},${esc(t.objectType)},${t.confidence},'
              '${esc(t.ontologyVersion)},${esc(t.sourceRecordId)},'
              '${esc(t.createdAt)},${esc(t.note)}');
        }
        content = buf.toString();
        defaultName = hasSearch
            ? 'subgraph_${searchQuery}_$ts.csv'
            : isFiltered
                ? 'partial_graph_$ts.csv'
                : 'knowledge_graph_$ts.csv';
      } else {
        content = const JsonEncoder.withIndent('  ').convert({
          'export_type': hasSearch ? 'subgraph' : isFiltered ? 'partial' : 'graph',
          if (hasSearch) 'search_query': searchQuery,
          'exported_at': DateTime.now().toIso8601String(),
          'stats': {
            'nodes': exportNodes.length,
            'edges': exportEdges.length,
          },
          'nodes': exportNodes
              .map((n) => {'id': n.id, 'type': n.type, 'degree': n.degree})
              .toList(),
          'edges': exportEdges
              .map((e) => {
                    'source': e.sourceId,
                    'predicate': e.predicate,
                    'target': e.targetId,
                  })
              .toList(),
        });
        defaultName = hasSearch
            ? 'subgraph_${searchQuery}_$ts.json'
            : isFiltered
                ? 'partial_graph_$ts.json'
                : 'knowledge_graph_$ts.json';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터 변환 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 4. 파일 경로 선택 (native dialog — provider 상태 변경 없음)
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: hasSearch
            ? '서브그래프 내보내기 (노드 ${exportNodes.length}개)'
            : '전체 그래프 내보내기 (노드 ${exportNodes.length}개)',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: [format],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('파일 선택 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (path == null || !mounted) return;

    // 5. 파일 저장
    try {
      await File(path).writeAsString(content, encoding: utf8);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 6. 완료 알림
    if (!mounted) return;
    final msg = hasSearch
        ? '서브그래프 저장 완료 (노드 ${exportNodes.length}개, 엣지 ${exportEdges.length}개)'
        : '전체 그래프 저장 완료 (노드 ${exportNodes.length}개, 엣지 ${exportEdges.length}개)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        action: SnackBarAction(label: '확인', onPressed: () {}),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(graphProvider);
    final visibleNodeCount = gs.nodes.where((n) => !n.hidden).length;
    final visibleEdgeCount = gs.edges.where((e) => !e.hidden).length;
    final hasHiddenNodes = visibleNodeCount < gs.nodes.length;

    // 시뮬레이션 수렴 후 자동 fit
    ref.listen<GraphState>(graphProvider, (prev, next) {
      if (prev != null && prev.isSimulating && !next.isSimulating &&
          next.nodes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fitToScreen();
        });
      }
    });

    if (gs.isLoading && gs.nodes.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (gs.error != null && gs.nodes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('오류: ${gs.error}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(graphProvider.notifier).loadGraph(),
              child: const Text('다시 시도'),
            ),
          ]),
        ),
      );
    }

    if (gs.nodes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.hub_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              gs.searchQuery.isEmpty
                  ? '그래프 데이터가 없습니다.\n트리플을 추출하면 그래프가 생성됩니다.'
                  : '"${gs.searchQuery}" 검색 결과가 없습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (gs.searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _searchCtrl.clear();
                  ref.read(graphProvider.notifier).search('');
                },
                child: const Text('전체 그래프 보기'),
              ),
            ],
          ]),
        ),
      );
    }

    final selectedNode = gs.selectedNode;

    return Scaffold(
      body: Row(
        children: [
          // ── 그래프 캔버스 영역 ─────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                _viewportSize = constraints.biggest;
                return Stack(
                  children: [
                // 1. 그래프 캔버스
                Screenshot(
                  controller: _screenshotCtrl,
                  child: MouseRegion(
                  cursor: _isOverNode
                      ? SystemMouseCursors.grab
                      : SystemMouseCursors.basic,
                  onHover: (e) {
                    final pos = _toCanvas(e.localPosition);
                    final over = gs.nodes.any((n) =>
                        (Offset(n.x, n.y) - pos).distance <= n.radius + 4);
                    if (over != _isOverNode) {
                      setState(() => _isOverNode = over);
                    }
                  },
                  child: GestureDetector(
                    onTapUp: (d) => _onTapCanvas(d, gs),
                    onLongPressStart: (d) => _onLongPressStart(d, gs),
                    onLongPressMoveUpdate: _onLongPressDrag,
                    onLongPressEnd: (_) => _onLongPressEnd(),
                    child: InteractiveViewer(
                      transformationController: _transformCtrl,
                      constrained: false,
                      panEnabled: !_isDraggingNode,
                      boundaryMargin: const EdgeInsets.all(300),
                      minScale: 0.05,
                      maxScale: 5.0,
                      child: CustomPaint(
                        size: const Size(3000, 3000),
                        painter: GraphPainter(
                          nodes: gs.nodes,
                          edges: gs.edges,
                          clusters: gs.clusters,
                          classColors: GraphColorSettings.currentColors,
                          selectedNodeId: gs.selectedNodeId,
                        ),
                      ),
                    ),
                  ),
                  ),  // MouseRegion
                ),  // Screenshot

                // 2. 시뮬레이션 인디케이터
                if (gs.isSimulating)
                  const Positioned(
                    top: 70,
                    right: 16,
                    child: _SimulatingBadge(),
                  ),

                // 3. 상단 오버레이 — 온톨로지 드롭다운 + 검색바
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 온톨로지 선택 드롭다운
                      if (_ontologies.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            elevation: 2,
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedOntology,
                                  isDense: true,
                                  icon: const Icon(Icons.arrow_drop_down,
                                      size: 18),
                                  items: _ontologies
                                      .map((o) => DropdownMenuItem(
                                            value: o['id'],
                                            child: Text(o['label']!,
                                                style: const TextStyle(
                                                    fontSize: 13)),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    final version = v ?? '';
                                    setState(() =>
                                        _selectedOntology = version);
                                    _searchCtrl.clear();
                                    ref
                                        .read(graphProvider.notifier)
                                        .loadGraph(
                                            ontologyVersion: version);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 검색바
                      GraphSearchBar(
                        controller: _searchCtrl,
                        onSearch: (q) =>
                            ref.read(graphProvider.notifier).search(q),
                        onClear: () {
                          _searchCtrl.clear();
                          ref.read(graphProvider.notifier).search('');
                        },
                        onExport: () => _showExportDialog(),
                        onFitScreen: _fitToScreen,
                        onPrint: (fmt) => _onPrint(fmt, gs),
                        onLayout: _onLayout,
                        onToggleClusterPanel: () => setState(
                            () => _showClusterPanel = !_showClusterPanel),
                        clusterPanelActive: _showClusterPanel,
                        onRefresh: () => ref
                            .read(graphProvider.notifier)
                            .loadGraph(
                                ontologyVersion: _selectedOntology),
                        stats: {
                          ...gs.stats,
                          'visible_nodes': visibleNodeCount,
                          'visible_edges': visibleEdgeCount,
                        },
                        exportTooltip: gs.searchQuery.isNotEmpty
                            ? '현재 서브그래프 내보내기'
                            : hasHiddenNodes
                                ? '필터 그래프 내보내기 ($visibleNodeCount개 노드)'
                                : '그래프 내보내기',
                      ),
                    ],
                  ),
                ),

                // 4. 하단 범례
                const Positioned(
                  bottom: 12,
                  left: 12,
                  child: GraphLegend(),
                ),

                // 5. 줌 힌트
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '탭: 상세보기  ·  길게 누르기: 노드 이동  ·  핀치/스크롤: 줌',
                      style:
                          TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ),
                ),
                  ],
                );
              },
            ),
          ),

          // ── 우측 범주 패널 (⚙ 토글) ─────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: _showClusterPanel ? 280 : 0,
            child: _showClusterPanel
                ? ClusterPanel(
                    onClose: () =>
                        setState(() => _showClusterPanel = false),
                  )
                : const SizedBox.shrink(),
          ),

          // ── 우측 노드 상세 패널 (선택 시 슬라이드인) ────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: selectedNode != null ? 340 : 0,
            child: selectedNode != null
                ? NodeDetailPanel(
                    node: selectedNode,
                    rawTriples: gs.rawTriples,
                    onClose: () =>
                        ref.read(graphProvider.notifier).selectNode(null),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── 시뮬레이션 배지 ───────────────────────────────────────────────────────────

class _SimulatingBadge extends StatelessWidget {
  const _SimulatingBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
              strokeWidth: 1.5, color: Colors.white70),
        ),
        SizedBox(width: 6),
        Text('레이아웃 계산 중',
            style: TextStyle(fontSize: 10, color: Colors.white70)),
      ]),
    );
  }
}

// ── 레이아웃 불러오기 다이얼로그 ──────────────────────────────────────────────

class _LoadLayoutDialog extends StatelessWidget {
  final List<dynamic> layouts;
  final ValueChanged<String> onLoad;
  final ValueChanged<String> onDelete;

  const _LoadLayoutDialog({
    required this.layouts,
    required this.onLoad,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('레이아웃 불러오기'),
      content: SizedBox(
        width: 400,
        child: layouts.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('저장된 레이아웃이 없습니다.',
                    style: TextStyle(color: Colors.grey)),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: layouts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final layout = layouts[i] as Map<String, dynamic>;
                  final savedAt = (layout['saved_at'] as String? ?? '');
                  final dateStr = savedAt.length >= 16
                      ? savedAt.substring(0, 16).replaceFirst('T', ' ')
                      : savedAt;
                  return ListTile(
                    dense: true,
                    title: Text(layout['name'] as String? ?? '',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '$dateStr  ·  노드 ${layout['node_count'] ?? 0}개',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.folder_open_outlined,
                              size: 18, color: Colors.blue),
                          tooltip: '불러오기',
                          onPressed: () =>
                              onLoad(layout['filename'] as String),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          tooltip: '삭제',
                          onPressed: () =>
                              onDelete(layout['filename'] as String),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
