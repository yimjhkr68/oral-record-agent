// lib/src/presentation/widgets/agent_dashboard_panel.dart
// 200px 우측 대시보드: 에이전트 통계 + 최근 기록 목록

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/record_provider.dart';
import '../providers/agent_state_provider.dart';
import '../providers/agent_history_provider.dart';
import '../../../agents/core/agent_history.dart';

class AgentDashboardPanel extends ConsumerWidget {
  const AgentDashboardPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(agentHistoryProvider);
    final agentState = ref.watch(agentStateProvider);
    final recentAsync = ref.watch(recentRecordsProvider);

    final totalRuns = history.length;
    final successCount =
        history.where((e) => e.status == AgentHistoryStatus.success).length;
    final failCount =
        history.where((e) => e.status == AgentHistoryStatus.failed).length;

    return Container(
      width: 200,
      color: const Color(0xFF1E2736),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('에이전트 통계'),
          _StatRow(label: '총 실행', value: '$totalRuns 회'),
          _StatRow(label: '성공', value: '$successCount 회'),
          _StatRow(label: '실패', value: '$failCount 회'),
          _AgentStatusRow(status: agentState.status),
          const _Divider(),
          _sectionLabel('최근 등록 기록'),
          Expanded(
            child: recentAsync.when(
              data: (records) {
                if (records.isEmpty) {
                  return const Center(
                    child: Text(
                      '기록 없음',
                      style: TextStyle(color: Colors.white24, fontSize: 11),
                    ),
                  );
                }
                final shown = records.take(5).toList();
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: shown.length,
                  itemBuilder: (ctx, i) {
                    final r = shown[i];
                    return InkWell(
                      onTap: () => context.go('/records/detail/${r.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          r.title,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style:
                    const TextStyle(color: Colors.white38, fontSize: 11)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _AgentStatusRow extends StatelessWidget {
  final AgentProcessStatus status;
  const _AgentStatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AgentProcessStatus.idle => ('대기 중', const Color(0xFF4CAF50)),
      AgentProcessStatus.thinking => ('분석 중', const Color(0xFF2196F3)),
      AgentProcessStatus.executing => ('실행 중', const Color(0xFFFF9800)),
      AgentProcessStatus.pendingReview =>
        ('검토 대기', const Color(0xFFFFEB3B)),
      AgentProcessStatus.pendingSearchConfirm =>
        ('검색 확인', const Color(0xFF29B6F6)),
      AgentProcessStatus.error => ('오류', const Color(0xFFF44336)),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('상태',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Divider(color: Colors.white12, height: 1),
      );
}
