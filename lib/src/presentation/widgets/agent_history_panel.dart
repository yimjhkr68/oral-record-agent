// lib/src/presentation/widgets/agent_history_panel.dart
// 200px 실행 이력 트리 패널 (ExpansionTile 기반)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/agent_history_provider.dart';
import '../../../agents/core/agent_history.dart';
import 'history_detail_window.dart';

class AgentHistoryPanel extends ConsumerWidget {
  const AgentHistoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(agentHistoryProvider);

    return Container(
      width: 200,
      color: const Color(0xFF242D3D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(onClear: () => ref.read(agentHistoryProvider.notifier).clear()),
          Expanded(
            child: entries.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: entries.length,
                    itemBuilder: (ctx, i) => _HistoryTile(entry: entries[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClear;
  const _Header({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      child: Row(
        children: [
          const Text(
            '실행 이력',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Tooltip(
            message: '이력 초기화',
            child: InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child:
                    Icon(Icons.delete_outline, size: 14, color: Colors.white38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final AgentHistoryEntry entry;
  const _HistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dotColor = switch (entry.status) {
      AgentHistoryStatus.success => const Color(0xFF4CAF50),
      AgentHistoryStatus.failed => const Color(0xFFF44336),
      AgentHistoryStatus.cancelled => const Color(0xFFFF9800),
      AgentHistoryStatus.noResults => const Color(0xFF78909C),
    };

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.only(bottom: 4),
        collapsedIconColor: Colors.white24,
        iconColor: Colors.white38,
        leading: GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => HistoryDetailWindow(entry: entry),
          ),
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        title: GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => HistoryDetailWindow(entry: entry),
          ),
          child: Text(
            entry.title,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        subtitle: Text(
          _timeAgo(entry.createdAt),
          style: const TextStyle(color: Colors.white38, fontSize: 9),
        ),
        children: entry.steps.map((s) => _LogRow(item: s)).toList(),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }
}

class _LogRow extends StatelessWidget {
  final HistoryLogItem item;
  const _LogRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final labelColor = item.isError ? const Color(0xFFEF9A9A) : Colors.white38;
    final textColor = item.isError ? const Color(0xFFEF9A9A) : Colors.white54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '[${item.step}]',
            style: TextStyle(color: labelColor, fontSize: 9),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              item.detail,
              style: TextStyle(color: textColor, fontSize: 9),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, color: Colors.white12, size: 32),
          SizedBox(height: 8),
          Text(
            '실행 이력 없음',
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
