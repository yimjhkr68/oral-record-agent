import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/history.dart';
import '../../providers/history_provider.dart';

class ExtractionHistoryTab extends ConsumerWidget {
  const ExtractionHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    if (state.sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('트리플 생성 이력이 없습니다',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _SessionCard(session: state.sessions[i]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final ExtractionSession session;
  const _SessionCard({required this.session});

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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더 행
            Row(children: [
              Icon(Icons.circle, size: 10, color: statusColor),
              const SizedBox(width: 6),
              Text(session.ontologyVersionId,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(statusLabel,
                    style: TextStyle(fontSize: 10, color: statusColor)),
              ),
              const Spacer(),
              Text(session.dateLabel,
                  style:
                      const TextStyle(fontSize: 11, color: Colors.grey)),
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
            // 처리 기록 목록 (있을 때만)
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
              fontSize: 11,
              color: color ?? Colors.grey.shade700)),
    );
  }
}
