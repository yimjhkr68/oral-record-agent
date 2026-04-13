// 파일 목적: 대시보드 홈 화면 - 통계 요약 카드, 차트, 최근 활동
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/search_filters.dart';
import '../providers/master_data_provider.dart';
import '../providers/record_provider.dart';
import '../providers/search_filter_provider.dart';
import '../theme/app_theme.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  String _getNarratorName(String narratorId, List narrators) {
    try {
      return (narrators.firstWhere((n) => n.id == narratorId)).name as String;
    } catch (_) {
      return '미지정';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recordListProvider(SearchFilters(limit: 999999)));
    final narratorsAsync = ref.watch(narratorListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('구술기록 관리'),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 빠른 작업 ────────────────────────────────
            Text('빠른 작업',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    label: '녹음 시작',
                    icon: Icons.mic,
                    onTap: () => context.push('/recording'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    label: '파일 업로드',
                    icon: Icons.upload_file,
                    onTap: () => context.push('/file-picker'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickActionButton(
                    label: '텍스트 입력',
                    icon: Icons.text_snippet,
                    onTap: () => context.push('/text-input'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 최근 활동 헤더 ───────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('대시보드',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => context.go('/records'),
                  child: const Text('모두 보기'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── 데이터 의존 영역 ─────────────────────────
            recordsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('로드 실패: $e')),
              data: (records) {
          final narrators = narratorsAsync.valueOrNull ?? [];
          final now = DateTime.now();

          // 이번 달 기록
          final thisMonthRecords = records
              .where((r) =>
                  r.createdAt.year == now.year &&
                  r.createdAt.month == now.month)
              .toList();

          // 전사 완료 기록 (content가 실제 텍스트인 것)
          final transcribedCount = records
              .where((r) =>
                  r.content.isNotEmpty &&
                  !r.content.startsWith('[') &&
                  r.content.length > 10)
              .length;

          // 파일 형식 분포
          final typeCounts = <String, int>{
            '음성': records.where((r) => r.inputType == 'audio').length,
            '영상': records.where((r) => r.inputType == 'video').length,
            '문서': records.where((r) => r.inputType == 'document').length,
            '텍스트': records.where((r) => r.inputType == 'text').length,
          };

          // 월별 기록 (최근 6개월)
          final monthlyCounts = <String, int>{};
          for (var i = 5; i >= 0; i--) {
            final d = DateTime(now.year, now.month - i, 1);
            final key = '${d.month}월';
            monthlyCounts[key] = records
                .where((r) =>
                    r.createdAt.year == d.year &&
                    r.createdAt.month == d.month)
                .length;
          }

          // 구술자별 기록 수 (상위 5명)
          final narratorCounts = <String, int>{};
          for (final r in records) {
            final name = _getNarratorName(r.narratorId, narrators);
            narratorCounts[name] = (narratorCounts[name] ?? 0) + 1;
          }
          final topNarrators = narratorCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top5 = topNarrators.take(5).toList();

          // 최근 활동 5건
          final recentRecords = [...records]
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final recent5 = recentRecords.take(5).toList();

          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 요약 카드 4개 ──────────────────────────
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _StatCard(
                      label: '전체 기록',
                      value: '${records.length}',
                      icon: Icons.article,
                      color: AppTheme.primary,
                      onTap: () => context.go('/records'),
                    ),
                    _StatCard(
                      label: '이번 달',
                      value: '${thisMonthRecords.length}',
                      icon: Icons.calendar_month,
                      color: AppTheme.primaryLight,
                      onTap: () {
                        ref.read(searchFilterProvider.notifier).setDateRange(
                          DateTime(now.year, now.month, 1),
                          DateTime(now.year, now.month + 1, 0, 23, 59, 59),
                        );
                        context.go('/records');
                      },
                    ),
                    _StatCard(
                      label: '구술자',
                      value: '${narrators.length}',
                      icon: Icons.people,
                      color: const Color(0xFF388E3C),
                      onTap: () => context.go('/people'),
                    ),
                    _StatCard(
                      label: '전사 완료',
                      value: '$transcribedCount',
                      icon: Icons.text_snippet,
                      color: AppTheme.accent,
                      onTap: () => context.go('/records'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 차트 행 ────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 월별 막대 그래프
                    Expanded(
                      flex: 3,
                      child: _ChartCard(
                        title: '월별 등록 현황',
                        child: SizedBox(
                          height: 200,
                          child: monthlyCounts.values.every((v) => v == 0)
                              ? const Center(
                                  child: Text('데이터 없음',
                                      style: TextStyle(color: Colors.grey)))
                              : BarChart(
                                  BarChartData(
                                    alignment:
                                        BarChartAlignment.spaceAround,
                                    maxY: (monthlyCounts.values.isEmpty
                                            ? 1
                                            : monthlyCounts.values.reduce(
                                                    (a, b) => a > b ? a : b) +
                                                1)
                                        .toDouble(),
                                    barTouchData:
                                        BarTouchData(enabled: false),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            final keys =
                                                monthlyCounts.keys.toList();
                                            final idx = value.toInt();
                                            if (idx >= 0 &&
                                                idx < keys.length) {
                                              return Text(keys[idx],
                                                  style: const TextStyle(
                                                      fontSize: 11));
                                            }
                                            return const SizedBox.shrink();
                                          },
                                        ),
                                      ),
                                      leftTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 28),
                                      ),
                                      topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                      rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                              showTitles: false)),
                                    ),
                                    gridData:
                                        const FlGridData(show: true),
                                    borderData:
                                        FlBorderData(show: false),
                                    barGroups: monthlyCounts.entries
                                        .toList()
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      return BarChartGroupData(
                                        x: entry.key,
                                        barRods: [
                                          BarChartRodData(
                                            toY: entry.value.value
                                                .toDouble(),
                                            color: AppTheme.primary,
                                            width: 22,
                                            borderRadius:
                                                const BorderRadius
                                                    .vertical(
                                                    top: Radius.circular(
                                                        4)),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 파일 형식 도넛 차트
                    Expanded(
                      flex: 2,
                      child: _ChartCard(
                        title: '파일 형식',
                        child: SizedBox(
                          height: 200,
                          child: typeCounts.values.every((v) => v == 0)
                              ? const Center(
                                  child: Text('데이터 없음',
                                      style: TextStyle(color: Colors.grey)))
                              : PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 40,
                                    sections: [
                                      if (typeCounts['음성']! > 0)
                                        PieChartSectionData(
                                          value: typeCounts['음성']!
                                              .toDouble(),
                                          title:
                                              '음성\n${typeCounts['음성']}',
                                          color: AppTheme.audioColor,
                                          radius: 60,
                                          titleStyle: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold),
                                        ),
                                      if (typeCounts['영상']! > 0)
                                        PieChartSectionData(
                                          value: typeCounts['영상']!
                                              .toDouble(),
                                          title:
                                              '영상\n${typeCounts['영상']}',
                                          color: const Color(0xFF7B1FA2),
                                          radius: 60,
                                          titleStyle: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold),
                                        ),
                                      if (typeCounts['문서']! > 0)
                                        PieChartSectionData(
                                          value: typeCounts['문서']!
                                              .toDouble(),
                                          title:
                                              '문서\n${typeCounts['문서']}',
                                          color: const Color(0xFFD32F2F),
                                          radius: 60,
                                          titleStyle: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold),
                                        ),
                                      if (typeCounts['텍스트']! > 0)
                                        PieChartSectionData(
                                          value: typeCounts['텍스트']!
                                              .toDouble(),
                                          title:
                                              '텍스트\n${typeCounts['텍스트']}',
                                          color: Colors.grey,
                                          radius: 60,
                                          titleStyle: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white,
                                              fontWeight:
                                                  FontWeight.bold),
                                        ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 구술자별 기록 수 ───────────────────────
                if (top5.isNotEmpty) ...[
                  _ChartCard(
                    title: '구술자별 기록 수 (상위 5명)',
                    child: Column(
                      children: top5.map((entry) {
                        final maxVal = top5.first.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: maxVal > 0
                                      ? entry.value / maxVal
                                      : 0,
                                  backgroundColor: AppTheme.divider,
                                  color: AppTheme.primary,
                                  minHeight: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('${entry.value}건',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── 최근 활동 ─────────────────────────────
                _ChartCard(
                  title: '최근 활동',
                  child: Column(
                    children: recent5.isEmpty
                        ? [
                            const Center(
                                child: Text('기록 없음',
                                    style: TextStyle(color: Colors.grey)))
                          ]
                        : recent5.map((r) {
                            final icon = r.inputType == 'audio'
                                ? Icons.mic
                                : r.inputType == 'video'
                                    ? Icons.videocam
                                    : r.inputType == 'document'
                                        ? Icons.description
                                        : Icons.text_snippet;
                            final iconColor = r.inputType == 'audio'
                                ? AppTheme.audioColor
                                : r.inputType == 'video'
                                    ? AppTheme.videoColor
                                    : r.inputType == 'document'
                                        ? AppTheme.docColor
                                        : AppTheme.textFileColor;
                            return ListTile(
                              dense: true,
                              leading: Icon(icon,
                                  color: iconColor, size: 20),
                              title: Text(r.title,
                                  style: const TextStyle(fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${r.updatedAt.year}-${r.updatedAt.month.toString().padLeft(2, '0')}-${r.updatedAt.day.toString().padLeft(2, '0')} · ${r.mainCategory}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right, size: 16),
                              onTap: () =>
                                  context.push('/records/detail/${r.id}'),
                            );
                          }).toList(),
                  ),
                ),
              ],
            );
        },
      ),
    ],
  ),
),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/file-picker'),
        icon: const Icon(Icons.add),
        label: const Text('기록 추가'),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
