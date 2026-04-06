// lib/src/presentation/widgets/multi_step_progress.dart
// 멀티스텝 태스크 진행상황 표시 위젯

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../agents/core/multi_step_task.dart';
import '../providers/agent_state_provider.dart';
import '../theme/app_theme.dart';

class MultiStepProgressWidget extends ConsumerWidget {
  const MultiStepProgressWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(currentMultiTaskProvider);
    if (task == null) return const SizedBox.shrink();

    final agentState = ref.watch(agentStateProvider);
    final isBusy = agentState.status == AgentProcessStatus.executing;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(color: AppTheme.cardShadow, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(task: task, isBusy: isBusy, ref: ref),
          _ProgressBar(task: task),
          _StepList(task: task),
          if (task.isCompleted) _Summary(task: task),
        ],
      ),
    );
  }
}

// ── 헤더 (제목 + 취소 버튼) ──────────────────────────────

class _Header extends StatelessWidget {
  final MultiStepTask task;
  final bool isBusy;
  final WidgetRef ref;

  const _Header({required this.task, required this.isBusy, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.account_tree_outlined,
              size: 15, color: AppTheme.primaryLight),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              task.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${task.completedCount}/${task.totalCount}',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isBusy && !task.isCancelled) ...[
            const SizedBox(width: 4),
            SizedBox(
              height: 28,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: AppTheme.error,
                ),
                onPressed: () =>
                    ref.read(agentStateProvider.notifier).cancelTask(),
                child: const Text('취소', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 전체 진행 바 ──────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final MultiStepTask task;
  const _ProgressBar({required this.task});

  @override
  Widget build(BuildContext context) {
    final progress = task.progressPercent;
    final color = task.isCancelled
        ? AppTheme.textDisabled
        : task.hasFailed
            ? AppTheme.error
            : task.isCompleted
                ? Colors.green.shade600
                : AppTheme.primaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: AppTheme.border,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}

// ── 단계 목록 ──────────────────────────────────────────────

class _StepList extends StatelessWidget {
  final MultiStepTask task;
  const _StepList({required this.task});

  @override
  Widget build(BuildContext context) {
    const maxVisible = 5;
    final steps = task.steps;
    final displaySteps = steps.length > maxVisible
        ? steps.sublist(0, maxVisible)
        : steps;
    final hiddenCount = steps.length - displaySteps.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...displaySteps.asMap().entries.map(
                (e) => _StepRow(index: e.key, step: e.value),
              ),
          if (hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 22),
              child: Text(
                '... 외 $hiddenCount개 단계',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textDisabled),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final TaskStep step;
  const _StepRow({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconForStatus(step.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: step.status == StepStatus.running
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              step.intent.params['query'] as String? ??
                  step.intent.typeLabel,
              style: TextStyle(
                fontSize: 11,
                color: step.status == StepStatus.failed
                    ? AppTheme.error
                    : AppTheme.textSecondary,
                decoration: step.status == StepStatus.skipped
                    ? TextDecoration.lineThrough
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (step.status == StepStatus.failed &&
              step.result?.errorMessage != null)
            Tooltip(
              message: step.result!.errorMessage!,
              child: const Icon(Icons.info_outline,
                  size: 13, color: AppTheme.error),
            ),
        ],
      ),
    );
  }

  (IconData, Color) _iconForStatus(StepStatus s) {
    switch (s) {
      case StepStatus.pending:
        return (Icons.radio_button_unchecked, AppTheme.textDisabled);
      case StepStatus.running:
        return (Icons.circle, AppTheme.primaryLight);
      case StepStatus.done:
        return (Icons.check_circle_outline, Colors.green.shade600);
      case StepStatus.failed:
        return (Icons.cancel_outlined, AppTheme.error);
      case StepStatus.skipped:
        return (Icons.remove_circle_outline, AppTheme.textDisabled);
    }
  }
}

// ── 완료 요약 ──────────────────────────────────────────────

class _Summary extends StatelessWidget {
  final MultiStepTask task;
  const _Summary({required this.task});

  @override
  Widget build(BuildContext context) {
    final done = task.completedCount;
    final total = task.totalCount;
    final failed = task.failedSteps.length;
    final skipped = task.steps.where((s) => s.status == StepStatus.skipped).length;
    final secs = task.elapsed.inSeconds;

    final statusColor = task.hasFailed
        ? AppTheme.error
        : task.isCancelled
            ? AppTheme.textDisabled
            : Colors.green.shade600;
    final statusLabel = task.isCancelled
        ? '취소됨'
        : task.hasFailed
            ? '일부 실패'
            : '완료';

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
            task.isCancelled
                ? Icons.cancel_outlined
                : task.hasFailed
                    ? Icons.warning_amber_outlined
                    : Icons.done_all,
            size: 14,
            color: statusColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$statusLabel  $done/$total 성공'
              '${failed > 0 ? "  •  $failed 실패" : ""}'
              '${skipped > 0 ? "  •  $skipped 건너뜀" : ""}'
              '  ($secs초)',
              style: TextStyle(
                fontSize: 11,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
