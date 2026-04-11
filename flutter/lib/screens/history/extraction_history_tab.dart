import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/history.dart';
import '../../providers/history_provider.dart';

class ExtractionHistoryTab extends ConsumerStatefulWidget {
  const ExtractionHistoryTab({super.key});

  @override
  ConsumerState<ExtractionHistoryTab> createState() =>
      _ExtractionHistoryTabState();
}

class _ExtractionHistoryTabState
    extends ConsumerState<ExtractionHistoryTab> {
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteBulk() async {
    final ids = List<String>.from(_selectedIds);
    _exitSelectMode();
    await ref.read(sessionListProvider.notifier).deleteBulk(ids);
  }

  Future<void> _deleteSingle(String id) async {
    await ref.read(sessionListProvider.notifier).deleteSingle(id);
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('트리플 생성 이력 전체 삭제'),
        content: const Text('모든 트리플 생성 이력을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('전체 삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(sessionListProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionListProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Text(state.error!,
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      );
    }

    return Column(
      children: [
        // ── 액션 바 ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              TextButton.icon(
                icon: Icon(
                    _selectMode ? Icons.close : Icons.checklist,
                    size: 16),
                label: Text(
                    _selectMode ? '취소' : '선택 삭제',
                    style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  if (_selectMode) {
                    _exitSelectMode();
                  } else {
                    setState(() => _selectMode = true);
                  }
                },
              ),
              if (_selectMode && _selectedIds.isNotEmpty) ...[
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6)),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.white),
                  label: Text('${_selectedIds.length}개 삭제',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12)),
                  onPressed: _deleteBulk,
                ),
              ],
              if (!_selectMode) ...[
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep,
                      color: Colors.red, size: 16),
                  label: const Text('전체 삭제',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                  onPressed: state.sessions.isEmpty
                      ? null
                      : () => _clearAll(context),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 목록 ────────────────────────────────────────────────────────────
        if (state.sessions.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('트리플 생성 이력이 없습니다',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: state.sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final session = state.sessions[i];
                return _SessionCard(
                  session: session,
                  selectMode: _selectMode,
                  selected: _selectedIds.contains(session.id),
                  onToggle: () => _toggleSelect(session.id),
                  onDelete: () => _deleteSingle(session.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ExtractionSession session;
  final bool selectMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.selectMode,
    required this.selected,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = session.isCompleted
        ? Colors.green
        : session.isFailed
            ? Colors.red
            : Colors.orange;
    final statusLabel = session.isCompleted
        ? '완료'
        : session.isFailed
            ? '실패'
            : '진행 중';

    return GestureDetector(
      onTap: selectMode ? onToggle : null,
      child: Card(
        margin: EdgeInsets.zero,
        color: selected ? Colors.red.withValues(alpha: 0.05) : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 행
              Row(children: [
                if (selectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Checkbox(
                      value: selected,
                      onChanged: (_) => onToggle(),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  Icon(Icons.circle, size: 10, color: statusColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(session.ontologyVersionId,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(fontSize: 10, color: statusColor)),
                ),
                const SizedBox(width: 8),
                Text(session.dateLabel,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (!selectMode) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: '삭제',
                    onPressed: onDelete,
                  ),
                ],
              ]),
              const SizedBox(height: 6),
              // 통계 행
              Row(children: [
                _StatChip('기록 ${session.totalRecords}건'),
                const SizedBox(width: 6),
                _StatChip('추출 ${session.extractedCount}개'),
                if (session.isCompleted) ...[
                  const SizedBox(width: 6),
                  _StatChip('확정 ${session.confirmedCount}개',
                      color: Colors.green.shade700),
                  if (session.rejectedCount > 0) ...[
                    const SizedBox(width: 6),
                    _StatChip('제외 ${session.rejectedCount}개',
                        color: Colors.grey),
                  ],
                ],
              ]),
              if (session.records.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: session.records
                      .map((r) => Chip(
                            label: Text(r.title,
                                style: const TextStyle(fontSize: 11)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _StatChip(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, color: color ?? Colors.grey.shade700)),
    );
  }
}
