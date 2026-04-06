// lib/src/presentation/widgets/plan_preview_card.dart
// 실행 전 계획 미리보기 카드 (PlanPreviewCard)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/agent_state_provider.dart';
import '../theme/app_theme.dart';

class PlanPreviewCard extends ConsumerStatefulWidget {
  final PendingPlanData plan;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const PlanPreviewCard({
    super.key,
    required this.plan,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  ConsumerState<PlanPreviewCard> createState() => _PlanPreviewCardState();
}

class _PlanPreviewCardState extends ConsumerState<PlanPreviewCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withValues(alpha: 0.07),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist_rounded,
                    size: 16, color: AppTheme.primaryLight),
                const SizedBox(width: 6),
                const Text(
                  '실행 계획 확인',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryLight,
                  ),
                ),
                const Spacer(),
                // 의도 뱃지
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.plan.intentLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 프롬프트 미리보기
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    widget.plan.userInput,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textPrimary),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 10),

                // 실행 단계 목록
                const Text(
                  '실행 단계',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                ...widget.plan.planSteps.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryLight
                                  .withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryLight,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.value,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    )),

                const SizedBox(height: 10),
                const Divider(height: 1, color: AppTheme.border),
                const SizedBox(height: 10),

                // 버튼 행
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: const Text('취소',
                          style: TextStyle(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: widget.onConfirm,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('실행',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
