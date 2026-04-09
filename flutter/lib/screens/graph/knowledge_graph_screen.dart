import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/graph_provider.dart';
import '../../widgets/graph/graph_painter.dart';
import 'graph_legend.dart';
import 'graph_search_bar.dart';
import 'node_detail_sheet.dart';

// ── 메인 화면 ─────────────────────────────────────────────────────────────────

class KnowledgeGraphScreen extends ConsumerStatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  ConsumerState<KnowledgeGraphScreen> createState() =>
      _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState
    extends ConsumerState<KnowledgeGraphScreen> {
  final _searchCtrl = TextEditingController();
  final _transformCtrl = TransformationController();
  String? _draggingNodeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(graphProvider.notifier).loadGraph();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _transformCtrl.dispose();
    super.dispose();
  }

  // ── 노드 탭 감지 ──────────────────────────────────────────────────────────

  void _onTapCanvas(TapUpDetails d, GraphState gs) {
    final scene = MatrixUtils.transformPoint(
      Matrix4.inverted(_transformCtrl.value),
      d.localPosition,
    );
    for (final node in gs.nodes) {
      if ((Offset(node.x, node.y) - scene).distance <= node.radius + 4) {
        ref.read(graphProvider.notifier).selectNode(node.id);
        showNodeDetailSheet(
          context,
          nodeId: node.id,
          nodeData: node,
          rawTriples: gs.rawTriples,
        );
        return;
      }
    }
    ref.read(graphProvider.notifier).selectNode(null);
  }

  // ── 노드 드래그 ───────────────────────────────────────────────────────────

  void _onPanStart(DragStartDetails d, GraphState gs) {
    final scene = MatrixUtils.transformPoint(
      Matrix4.inverted(_transformCtrl.value),
      d.localPosition,
    );
    for (final node in gs.nodes) {
      if ((Offset(node.x, node.y) - scene).distance <= node.radius + 4) {
        _draggingNodeId = node.id;
        return;
      }
    }
    _draggingNodeId = null;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggingNodeId == null) return;
    final scale = _transformCtrl.value.getMaxScaleOnAxis();
    ref.read(graphProvider.notifier).onNodeDrag(
      _draggingNodeId!,
      d.delta / scale,
    );
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _showExportDialog(GraphState gs) async {
    if (gs.rawTriples.isEmpty && gs.nodes.isEmpty) return;
    final format = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('그래프 내보내기'),
        content: const Text('저장 형식을 선택하세요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          OutlinedButton(
              onPressed: () => Navigator.pop(context, 'json'),
              child: const Text('JSON')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, 'csv'),
              child: const Text('CSV')),
        ],
      ),
    );
    if (format == null) return;
    await _exportGraph(format, gs);
  }

  Future<void> _exportGraph(String format, GraphState gs) async {
    String content;
    String defaultName;

    if (format == 'csv') {
      final buf = StringBuffer();
      buf.writeln(
          'subject,subject_type,predicate,object,object_type,'
          'confidence,ontology_version,source_record_id,created_at,note');
      String esc(String s) => '"${s.replaceAll('"', '""')}"';
      for (final t in gs.rawTriples) {
        buf.writeln(
            '${esc(t.subject)},${esc(t.subjectType)},${esc(t.predicate)},'
            '${esc(t.object)},${esc(t.objectType)},${t.confidence},'
            '${esc(t.ontologyVersion)},${esc(t.sourceRecordId)},'
            '${esc(t.createdAt)},${esc(t.note)}');
      }
      content = buf.toString();
      defaultName = 'knowledge_graph.csv';
    } else {
      content = const JsonEncoder.withIndent('  ').convert({
        'nodes': gs.nodes
            .map((n) => {'id': n.id, 'type': n.type, 'degree': n.degree})
            .toList(),
        'triples': gs.rawTriples
            .map((t) => {
                  'subject': t.subject,
                  'subject_type': t.subjectType,
                  'predicate': t.predicate,
                  'object': t.object,
                  'object_type': t.objectType,
                  'confidence': t.confidence,
                  'ontology_version': t.ontologyVersion,
                  'source_record_id': t.sourceRecordId,
                  'created_at': t.createdAt,
                  'note': t.note,
                })
            .toList(),
      });
      defaultName = 'knowledge_graph.json';
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: '그래프 내보내기',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: [format],
    );
    if (path == null) return;
    await File(path).writeAsString(content, encoding: utf8);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장됨: $path'),
          action: SnackBarAction(label: '확인', onPressed: () {}),
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(graphProvider);

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

    return Scaffold(
      body: Stack(children: [
        // ── 1. 그래프 캔버스 ─────────────────────────────────────────────
        GestureDetector(
          onTapUp: (d) => _onTapCanvas(d, gs),
          onPanStart: (d) => _onPanStart(d, gs),
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _draggingNodeId = null,
          child: InteractiveViewer(
            transformationController: _transformCtrl,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(300),
            minScale: 0.05,
            maxScale: 5.0,
            child: CustomPaint(
              size: const Size(3000, 3000),
              painter: GraphPainter(
                nodes: gs.nodes,
                edges: gs.edges,
                classColors: graphClassColors,
                selectedNodeId: gs.selectedNodeId,
              ),
            ),
          ),
        ),

        // ── 2. 시뮬레이션 인디케이터 ─────────────────────────────────────
        if (gs.isSimulating)
          const Positioned(
            top: 70,
            right: 16,
            child: _SimulatingBadge(),
          ),

        // ── 3. 상단 오버레이 ─────────────────────────────────────────────
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: GraphSearchBar(
            controller: _searchCtrl,
            onSearch: (q) => ref.read(graphProvider.notifier).search(q),
            onClear: () {
              _searchCtrl.clear();
              ref.read(graphProvider.notifier).search('');
            },
            onExport: () => _showExportDialog(gs),
            onRefresh: () => ref.read(graphProvider.notifier).loadGraph(),
            stats: gs.stats,
          ),
        ),

        // ── 4. 하단 범례 ─────────────────────────────────────────────────
        const Positioned(
          bottom: 12,
          left: 12,
          child: GraphLegend(),
        ),

        // ── 5. 줌 힌트 ───────────────────────────────────────────────────
        Positioned(
          bottom: 12,
          right: 12,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '핀치/스크롤 줌  ·  드래그 이동  ·  노드 탭으로 상세',
              style: TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ),
        ),
      ]),
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
