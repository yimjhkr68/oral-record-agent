// lib/src/presentation/widgets/duplicate_resolution_dialog.dart
// 중복 파일 감지 시 3가지 처리 선택 다이얼로그

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/agent_state_provider.dart';
import '../theme/app_theme.dart';

class DuplicateResolutionDialog extends ConsumerWidget {
  final DuplicateFileInfo info;

  const DuplicateResolutionDialog({super.key, required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateStr =
        info.existingDate != null ? info.existingDate!.substring(0, 10) : '';

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('이미 등록된 파일이에요'),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기존 기록 정보
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.existingTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (info.existingDisplayId != null) ...[
                        _MetaChip(
                            icon: Icons.tag, label: info.existingDisplayId!),
                        const SizedBox(width: 8),
                      ],
                      if (dateStr.isNotEmpty)
                        _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label: dateStr),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '처리 방법을 선택하세요',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            // 3개 선택 카드
            _OptionCard(
              icon: Icons.block_outlined,
              color: AppTheme.textSecondary,
              title: '등록 중단',
              subtitle: '현재 파일 등록을 취소하고 대기 상태로 돌아갑니다',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(agentStateProvider.notifier).resolveDuplicate(
                      DuplicateResolution.cancel,
                      info.filePath,
                      info.existingRecordId,
                    );
              },
            ),
            const SizedBox(height: 8),
            _OptionCard(
              icon: Icons.add_circle_outline,
              color: AppTheme.primaryLight,
              title: '새 기록으로 강제 등록',
              subtitle: '중복 체크를 건너뛰고 별도 기록으로 저장합니다',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(agentStateProvider.notifier).resolveDuplicate(
                      DuplicateResolution.forceRegister,
                      info.filePath,
                      info.existingRecordId,
                    );
              },
            ),
            const SizedBox(height: 8),
            _OptionCard(
              icon: Icons.edit_outlined,
              color: Colors.teal,
              title: '기존 기록 업데이트',
              subtitle: 'OCR/전사를 재실행해 기존 기록의 내용·요약·태그를 갱신합니다',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(agentStateProvider.notifier).resolveDuplicate(
                      DuplicateResolution.updateExisting,
                      info.filePath,
                      info.existingRecordId,
                    );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(agentStateProvider.notifier).dismissDuplicate();
            context.go('/records/detail/${info.existingRecordId}');
          },
          icon: const Icon(Icons.open_in_new_outlined, size: 15),
          label: const Text('기존 기록 보기'),
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
