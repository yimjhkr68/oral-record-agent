import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  static const _configs = {
    'draft':     (AppColors.draft,     '작업 중'),
    'confirmed': (AppColors.confirmed, '확정'),
    'archived':  (AppColors.archived,  '아카이브'),
    'active':    (AppColors.success,   '활성'),
    'pending':   (AppColors.warning,   '검토 중'),
    'running':   (AppColors.info,      '처리 중'),
  };

  @override
  Widget build(BuildContext context) {
    final entry = _configs[status.toLowerCase()];
    final color = entry?.$1 ?? AppColors.textMuted;
    final label = entry?.$2 ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: AppTypography.badge.copyWith(color: color)),
    );
  }
}
