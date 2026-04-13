// lib/src/presentation/widgets/review_dialog.dart
// 에이전트 결과 검토/승인 다이얼로그

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/search_filters.dart';
import '../providers/agent_state_provider.dart';
import '../providers/record_provider.dart';
import '../theme/app_theme.dart';

class ReviewDialog extends ConsumerWidget {
  const ReviewDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentState = ref.watch(agentStateProvider);
    final result = agentState.pendingReview;

    // 상태가 pendingReview에서 벗어나면 다이얼로그 자동 닫기
    ref.listen(agentStateProvider, (prev, next) {
      if (prev?.status == AgentProcessStatus.pendingReview &&
          next.status != AgentProcessStatus.pendingReview) {
        if (context.mounted) Navigator.of(context).maybePop();
      }
    });

    if (result == null) return const SizedBox.shrink();

    final steps = result.toolCallResults;
    final reviewContent =
        result.reviewContent ?? result.summary ?? '처리 결과를 검토해주세요.';

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.rate_review_outlined,
                color: AppTheme.accent, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('검토 요청'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 검토 내용 ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                reviewContent,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),

            // ── 처리 단계 목록 ─────────────────────────
            if (steps.isNotEmpty) ...[
              Text('처리 단계',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: steps.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final step = steps[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        step.success
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: step.success
                            ? Colors.green.shade600
                            : AppTheme.error,
                        size: 18,
                      ),
                      title: Text(
                        step.toolName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      subtitle: step.errorMessage != null
                          ? Text(step.errorMessage!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.error))
                          : null,
                      trailing: Text(
                        '${step.executionTime.inMilliseconds}ms',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── 저장 ID 미리보기 ────────────────────────
            if (result.savedRecordId != null)
              _InfoRow(
                icon: Icons.bookmark_outline,
                label: '기록 ID',
                value: result.savedRecordId!,
              ),

            // ── 요약 ────────────────────────────────────
            if (result.summary != null)
              _InfoRow(
                icon: Icons.summarize_outlined,
                label: '요약',
                value: result.summary!,
              ),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.close, size: 16),
          label: const Text('거부'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error),
          ),
          onPressed: () {
            ref.read(agentStateProvider.notifier).rejectReview();
            // 상태 변화 리스너가 Navigator.pop 처리하지만 안전 처리
            if (context.mounted) Navigator.of(context).maybePop();
            // 기록 목록 갱신
            ref.invalidate(recentRecordsProvider);
            ref.invalidate(recordListProvider(SearchFilters()));
          },
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.check, size: 16),
          label: const Text('승인'),
          onPressed: () {
            ref.read(agentStateProvider.notifier).approveReview();
            if (context.mounted) Navigator.of(context).maybePop();
            ref.invalidate(recentRecordsProvider);
            ref.invalidate(recordListProvider(SearchFilters()));
          },
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text('$label: ',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
