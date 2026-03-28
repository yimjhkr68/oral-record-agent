// lib/src/presentation/widgets/agent_dashboard_panel.dart
// 200px 우측 대시보드: 기록 통계 4개 + 에이전트 통계 + 최근 등록 목록

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/record_provider.dart';
import '../providers/agent_state_provider.dart';
import '../providers/agent_history_provider.dart';
import '../providers/dashboard_stats_provider.dart';
import '../../../agents/core/agent_history.dart';

class AgentDashboardPanel extends ConsumerStatefulWidget {
  const AgentDashboardPanel({super.key});

  @override
  ConsumerState<AgentDashboardPanel> createState() =>
      _AgentDashboardPanelState();
}

class _AgentDashboardPanelState extends ConsumerState<AgentDashboardPanel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 30초마다 통계 자동 갱신
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(recentRecordsProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(agentHistoryProvider);
    final agentState = ref.watch(agentStateProvider);
    final recentAsync = ref.watch(recentRecordsProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

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
          // ── 기록 통계 그리드 ────────────────────────────
          _sectionLabel('기록 통계'),
          statsAsync.when(
            data: (stats) => _buildStatsGrid(stats),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: Colors.white38),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const _Divider(),

          // ── 에이전트 통계 ────────────────────────────────
          _sectionLabel('에이전트 통계'),
          _StatRow(label: '총 실행', value: '$totalRuns 회'),
          _StatRow(label: '성공', value: '$successCount 회'),
          _StatRow(label: '실패', value: '$failCount 회'),
          _AgentStatusRow(status: agentState.status),
          const _Divider(),

          // ── 최근 등록 목록 ──────────────────────────────
          _sectionLabel('최근 등록'),
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
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: shown.length,
                  itemBuilder: (ctx, i) {
                    final r = shown[i];
                    final dateStr =
                        '${r.createdAt.month}/${r.createdAt.day}';
                    return InkWell(
                      onTap: () => context.go('/records/detail/${r.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // REC ID + 배지
                            Row(
                              children: [
                                if (r.displayId != null)
                                  Text(
                                    r.displayId!,
                                    style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 9,
                                        letterSpacing: 0.5),
                                  ),
                                const Spacer(),
                                _InputTypeBadge(inputType: r.inputType),
                              ],
                            ),
                            const SizedBox(height: 2),
                            // 제목
                            Text(
                              r.title,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // 날짜
                            Text(
                              dateStr,
                              style: const TextStyle(
                                  color: Colors.white24, fontSize: 9),
                            ),
                          ],
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
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white38),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DashboardStats stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.7,
        children: [
          _StatCard(label: '전체', value: '${stats.totalRecords}'),
          _StatCard(label: '이번 달', value: '${stats.thisMonthRecords}'),
          _StatCard(label: '구술자', value: '${stats.narratorCount}'),
          _StatCard(
              label: '미처리',
              value: '${stats.unprocessedCount}',
              highlight: stats.unprocessedCount > 0),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
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

// ── 통계 카드 (2x2 그리드용) ─────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueColor =
        highlight ? const Color(0xFFFF9800) : Colors.white70;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ── 인풋 타입 배지 ───────────────────────────────────────

class _InputTypeBadge extends StatelessWidget {
  final String inputType;
  const _InputTypeBadge({required this.inputType});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (inputType) {
      'audio' => ('음성', const Color(0xFF4CAF50)),
      'text' => ('텍스트', const Color(0xFF2196F3)),
      'document' => ('문서', const Color(0xFF9C27B0)),
      'image' => ('이미지', const Color(0xFFFF9800)),
      _ => ('기타', Colors.white24),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── 가로 통계 행 ─────────────────────────────────────────

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

// ── 에이전트 상태 행 ─────────────────────────────────────

class _AgentStatusRow extends StatelessWidget {
  final AgentProcessStatus status;
  const _AgentStatusRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AgentProcessStatus.idle => ('대기 중', const Color(0xFF4CAF50)),
      AgentProcessStatus.enhancingPrompt =>
        ('프롬프트 분석', const Color(0xFF9C27B0)),
      AgentProcessStatus.waitingPromptChoice =>
        ('개선 선택 대기', const Color(0xFFE91E63)),
      AgentProcessStatus.planningPreview =>
        ('계획 확인', const Color(0xFF00BCD4)),
      AgentProcessStatus.thinking => ('분석 중', const Color(0xFF2196F3)),
      AgentProcessStatus.executing => ('실행 중', const Color(0xFFFF9800)),
      AgentProcessStatus.pendingReview =>
        ('검토 대기', const Color(0xFFFFEB3B)),
      AgentProcessStatus.pendingSearchConfirm =>
        ('검색 확인', const Color(0xFF29B6F6)),
      AgentProcessStatus.pendingDuplicate =>
        ('중복 감지', const Color(0xFFFF9800)),
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
              Text(label, style: TextStyle(color: color, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 구분선 ───────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Divider(color: Colors.white12, height: 1),
      );
}
