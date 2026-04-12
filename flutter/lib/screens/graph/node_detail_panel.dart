import 'package:flutter/material.dart';
import '../../models/triple.dart';
import '../../widgets/graph/graph_node_model.dart';
import '../../widgets/graph/graph_painter.dart';

/// 노드 클릭 시 우측에서 슬라이드인 되는 상세 패널
class NodeDetailPanel extends StatelessWidget {
  final LayoutNode node;
  final List<Triple> rawTriples;
  final VoidCallback onClose;
  final void Function(String nodeId)? onFocusNode;

  const NodeDetailPanel({
    required this.node,
    required this.rawTriples,
    required this.onClose,
    this.onFocusNode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final outgoing =
        rawTriples.where((t) => t.subject == node.id).toList();
    final incoming =
        rawTriples.where((t) => t.object == node.id).toList();
    final color = graphClassColors[node.type] ?? Colors.blueGrey;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color,
                  child: Text(
                    node.id.isNotEmpty ? node.id[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(node.id,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis),
                      Text(node.type,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: '닫기',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // ── 연결 통계 ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                _StatChip('나가는', outgoing.length, Colors.blue),
                const SizedBox(width: 8),
                _StatChip('들어오는', incoming.length, Colors.green),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── 트리플 탭 목록 ────────────────────────────────────────────────
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    unselectedLabelStyle: const TextStyle(fontSize: 12),
                    tabs: [
                      Tab(text: '나가는 (${outgoing.length})'),
                      Tab(text: '들어오는 (${incoming.length})'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _TripleList(
                            triples: outgoing,
                            focusId: node.id,
                            isOutgoing: true,
                            onFocusNode: onFocusNode),
                        _TripleList(
                            triples: incoming,
                            focusId: node.id,
                            isOutgoing: false,
                            onFocusNode: onFocusNode),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 통계 칩 ────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _StatChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      );
}

// ── 트리플 목록 ────────────────────────────────────────────────────────────────

class _TripleList extends StatelessWidget {
  final List<Triple> triples;
  final String focusId;
  final bool isOutgoing;
  final void Function(String nodeId)? onFocusNode;

  const _TripleList({
    required this.triples,
    required this.focusId,
    required this.isOutgoing,
    this.onFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    if (triples.isEmpty) {
      return Center(
        child: Text('없음',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: triples.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final t = triples[i];
        final other = isOutgoing ? t.object : t.subject;
        return InkWell(
          onTap: onFocusNode != null ? () => onFocusNode!(other) : null,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOutgoing ? '→' : '←',
                  style: TextStyle(
                      color: isOutgoing
                          ? Theme.of(ctx).colorScheme.primary
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.predicate,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(ctx).colorScheme.primary)),
                      const SizedBox(height: 2),
                      Text(other,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // 포커스 힌트 아이콘
                if (onFocusNode != null)
                  Icon(Icons.center_focus_weak_outlined,
                      size: 14,
                      color: Colors.grey.shade400),
              ],
            ),
          ),
        );
      },
    );
  }
}
