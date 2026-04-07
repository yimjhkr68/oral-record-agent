import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphview/GraphView.dart';

import '../../models/triple.dart';
import '../../providers/graph_provider.dart';
import '../../widgets/graph_painter.dart';

class KnowledgeGraphScreen extends ConsumerStatefulWidget {
  const KnowledgeGraphScreen({super.key});

  @override
  ConsumerState<KnowledgeGraphScreen> createState() =>
      _KnowledgeGraphScreenState();
}

class _KnowledgeGraphScreenState extends ConsumerState<KnowledgeGraphScreen> {
  final _searchCtrl = TextEditingController();
  final _algorithm = FruchtermanReingoldAlgorithm(
      FruchtermanReingoldConfiguration()..iterations = 1000);

  // 현재 그래프 데이터
  GraphData? _graphData;
  // 노드 ID → GraphNode 빠른 검색
  Map<String, GraphNode> _nodeMap = {};
  // graphview Graph 객체 (데이터 변경 시만 재생성)
  Graph? _gvGraph;
  // 선택된 노드 ID
  String? _selectedNodeId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── GraphData → graphview Graph 변환 ────────────────────────────────────────
  void _rebuildGraph(GraphData data) {
    final gvGraph = Graph()..isTree = false;
    final gvNodeMap = <String, Node>{};

    for (final n in data.nodes) {
      final gvNode = Node.Id(n.id);
      gvNodeMap[n.id] = gvNode;
      gvGraph.addNode(gvNode);
    }

    for (final triple in data.triples) {
      final src = gvNodeMap[triple.subject];
      final dst = gvNodeMap[triple.object];
      if (src != null && dst != null) {
        gvGraph.addEdge(
          src,
          dst,
          paint: Paint()
            ..color = Colors.blueGrey.shade300
            ..strokeWidth = 1.2
            ..style = PaintingStyle.stroke,
        );
      }
    }

    setState(() {
      _graphData = data;
      _nodeMap = {for (final n in data.nodes) n.id: n};
      _gvGraph = gvGraph;
      // 선택 초기화 (새 그래프 로드 시)
      _selectedNodeId = null;
    });
  }

  void _submitSearch() {
    ref.read(graphQueryProvider.notifier).state = _searchCtrl.text.trim();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    ref.read(graphQueryProvider.notifier).state = '';
  }

  // ── 노드 탭 핸들러 ─────────────────────────────────────────────────────────
  void _onNodeTap(String nodeId) {
    setState(() => _selectedNodeId = nodeId);
  }

  @override
  Widget build(BuildContext context) {
    // 데이터 변경 감지 → 그래프 재생성
    ref.listen(graphDataProvider, (_, next) {
      next.whenData(_rebuildGraph);
    });

    final graphAsync = ref.watch(graphDataProvider);
    final searchQuery = ref.watch(graphQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('지식그래프'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: '노드 검색 (1홉 서브그래프)...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearSearch,
                      ),
                    TextButton(
                      onPressed: _submitSearch,
                      child: const Text('검색'),
                    ),
                  ],
                ),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (_) => _submitSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ),
      body: graphAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오류: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(graphDataProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (_) {
          final graph = _gvGraph;
          if (graph == null || graph.nodeCount() == 0) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hub_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    searchQuery.isEmpty
                        ? '그래프 데이터가 없습니다.\n트리플을 추출하면 그래프가 생성됩니다.'
                        : '"$searchQuery" 검색 결과가 없습니다.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (searchQuery.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _clearSearch,
                      child: const Text('전체 그래프 보기'),
                    ),
                  ],
                ],
              ),
            );
          }

          return Row(
            children: [
              // ── 그래프 캔버스 ────────────────────────────────────────────
              Expanded(
                flex: _selectedNodeId != null ? 3 : 1,
                child: Stack(
                  children: [
                    InteractiveViewer(
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(200),
                      minScale: 0.05,
                      maxScale: 4.0,
                      child: GraphView(
                        graph: graph,
                        algorithm: _algorithm,
                        paint: Paint()
                          ..color = Colors.blueGrey.shade200
                          ..strokeWidth = 1.2
                          ..style = PaintingStyle.stroke,
                        builder: (Node gvNode) {
                          final nodeId =
                              gvNode.key!.value as String;
                          final nodeData = _nodeMap[nodeId];
                          final isHighlighted = searchQuery.isNotEmpty &&
                              nodeId.toLowerCase().contains(
                                    searchQuery.toLowerCase(),
                                  );
                          return GraphNodeWidget(
                            nodeId: nodeId,
                            nodeType: nodeData?.type ?? '',
                            highlighted: isHighlighted ||
                                nodeId == _selectedNodeId,
                            onTap: () => _onNodeTap(nodeId),
                          );
                        },
                      ),
                    ),
                    // 통계 오버레이
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatsOverlay(
                        nodes: _graphData?.nodes.length ?? 0,
                        triples: _graphData?.triples.length ?? 0,
                        isFiltered: searchQuery.isNotEmpty,
                      ),
                    ),
                    // 줌 힌트
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '핀치/스크롤로 줌  ·  드래그로 이동',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 노드 상세 패널 ────────────────────────────────────────────
              if (_selectedNodeId != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 280,
                  child: _NodeDetailPanel(
                    nodeId: _selectedNodeId!,
                    nodeData: _nodeMap[_selectedNodeId!],
                    triples: _graphData?.triples ?? [],
                    onClose: () =>
                        setState(() => _selectedNodeId = null),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── 통계 오버레이 ─────────────────────────────────────────────────────────────

class _StatsOverlay extends StatelessWidget {
  final int nodes;
  final int triples;
  final bool isFiltered;
  const _StatsOverlay(
      {required this.nodes,
      required this.triples,
      required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (isFiltered)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(Icons.filter_alt, size: 12, color: Colors.amber),
          ),
        Text('노드 $nodes  ·  트리플 $triples',
            style:
                const TextStyle(fontSize: 11, color: Colors.white)),
      ]),
    );
  }
}

// ── 노드 상세 패널 ────────────────────────────────────────────────────────────

class _NodeDetailPanel extends StatelessWidget {
  final String nodeId;
  final GraphNode? nodeData;
  final List<Triple> triples;
  final VoidCallback onClose;

  const _NodeDetailPanel({
    required this.nodeId,
    required this.nodeData,
    required this.triples,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // 이 노드와 연결된 트리플
    final connected = triples
        .where((t) => t.subject == nodeId || t.object == nodeId)
        .toList();
    final outgoing =
        connected.where((t) => t.subject == nodeId).toList();
    final incoming =
        connected.where((t) => t.object == nodeId).toList();

    final color = nodeColorForType(nodeData?.type ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: color.withValues(alpha: 0.1),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color,
                child: Text(
                  nodeId.isNotEmpty ? nodeId[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nodeId,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    if (nodeData != null)
                      Text(nodeData!.type,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // 통계
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            _StatPill('나가는 관계', outgoing.length),
            const SizedBox(width: 10),
            _StatPill('들어오는 관계', incoming.length),
          ]),
        ),
        const Divider(height: 1),

        // 트리플 목록
        Expanded(
          child: connected.isEmpty
              ? const Center(
                  child: Text('연결된 트리플 없음',
                      style: TextStyle(color: Colors.grey, fontSize: 13)))
              : ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    if (outgoing.isNotEmpty) ...[
                      const _SectionHeader('나가는 관계'),
                      ...outgoing
                          .map((t) => _TripleRow(triple: t, focusId: nodeId)),
                    ],
                    if (incoming.isNotEmpty) ...[
                      const _SectionHeader('들어오는 관계'),
                      ...incoming
                          .map((t) => _TripleRow(triple: t, focusId: nodeId)),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  const _StatPill(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$label $value',
          style: const TextStyle(fontSize: 11)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _TripleRow extends StatelessWidget {
  final Triple triple;
  final String focusId;
  const _TripleRow({required this.triple, required this.focusId});

  @override
  Widget build(BuildContext context) {
    final isSubject = triple.subject == focusId;
    final other = isSubject ? triple.object : triple.subject;
    final arrow = isSubject ? '→' : '←';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(arrow,
              style: TextStyle(
                  color: isSubject
                      ? Theme.of(context).colorScheme.primary
                      : Colors.orange,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Flexible(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontSize: 12),
                children: [
                  TextSpan(
                    text: triple.predicate,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(text: other),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
