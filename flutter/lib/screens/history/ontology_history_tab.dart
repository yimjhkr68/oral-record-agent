import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/history.dart';
import '../../providers/history_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';

class OntologyHistoryTab extends ConsumerStatefulWidget {
  const OntologyHistoryTab({super.key});

  @override
  ConsumerState<OntologyHistoryTab> createState() => _OntologyHistoryTabState();
}

class _OntologyHistoryTabState extends ConsumerState<OntologyHistoryTab> {
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
    await ref.read(ontologyEventProvider.notifier).deleteBulk(ids);
  }

  Future<void> _deleteSingle(String id) async {
    await ref.read(ontologyEventProvider.notifier).deleteSingle(id);
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('온톨로지 이력 전체 삭제'),
        content: const Text('모든 온톨로지 이력을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
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
    await ref.read(ontologyEventProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ontologyEventProvider);

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
                  onPressed: state.events.isEmpty
                      ? null
                      : () => _clearAll(context),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 목록 ────────────────────────────────────────────────────────────
        if (state.events.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.history_edu_outlined,
              title: '온톨로지 이력이 없습니다',
              description: '온톨로지를 생성하거나 확정하면\n이력이 기록됩니다.',
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: state.events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (_, i) {
                final event = state.events[i];
                return _EventTile(
                  event: event,
                  selectMode: _selectMode,
                  selected: _selectedIds.contains(event.id),
                  onToggle: () => _toggleSelect(event.id),
                  onDelete: () => _deleteSingle(event.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _EventTile extends StatelessWidget {
  final OntologyEvent event;
  final bool selectMode;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _EventTile({
    required this.event,
    required this.selectMode,
    required this.selected,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      selected: selected,
      onTap: selectMode ? onToggle : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
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
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _EventIcon(eventType: event.eventType),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(event.versionId,
                      style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  const SizedBox(width: 8),
                  _EventChip(eventType: event.eventType),
                ]),
                if (event.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(event.detail, style: AppTypography.caption),
                ],
              ],
            ),
          ),
          Text(event.dateLabel, style: AppTypography.caption),
          if (!selectMode) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 15, color: AppColors.error),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '삭제',
              onPressed: onDelete,
            ),
          ],
        ],
      ),
    );
  }
}

class _EventIcon extends StatelessWidget {
  final String eventType;
  const _EventIcon({required this.eventType});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (eventType) {
      'confirmed' => (Icons.check_circle, AppColors.confirmed),
      'created'   => (Icons.add_circle_outline, AppColors.primary),
      'updated'   => (Icons.edit, AppColors.draft),
      'deleted'   => (Icons.delete_outline, AppColors.error),
      'archived'  => (Icons.archive_outlined, AppColors.archived),
      'generated' => (Icons.auto_awesome, AppColors.secondary),
      'merged'    => (Icons.merge, AppColors.secondary),
      _           => (Icons.circle_outlined, AppColors.textMuted),
    };
    return Icon(icon, color: color, size: 18);
  }
}

class _EventChip extends StatelessWidget {
  final String eventType;
  const _EventChip({required this.eventType});

  @override
  Widget build(BuildContext context) {
    final label = switch (eventType) {
      'confirmed' => '확정',
      'created'   => '생성',
      'updated'   => '수정',
      'deleted'   => '삭제',
      'archived'  => '아카이브',
      'generated' => 'AI 생성',
      'merged'    => '병합',
      _           => eventType,
    };
    final color = switch (eventType) {
      'confirmed' => AppColors.confirmed,
      'created'   => AppColors.primary,
      'updated'   => AppColors.draft,
      'deleted'   => AppColors.error,
      'archived'  => AppColors.archived,
      'generated' => AppColors.secondary,
      'merged'    => AppColors.secondary,
      _           => AppColors.textMuted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppTypography.badge.copyWith(color: color)),
    );
  }
}
