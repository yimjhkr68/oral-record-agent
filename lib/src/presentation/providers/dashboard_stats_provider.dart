// lib/src/presentation/providers/dashboard_stats_provider.dart
// 홈 대시보드 통계 Provider

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/repository_provider.dart';

class DashboardStats {
  final int totalRecords;
  final int thisMonthRecords;
  final int narratorCount;
  final int unprocessedCount;

  const DashboardStats({
    required this.totalRecords,
    required this.thisMonthRecords,
    required this.narratorCount,
    required this.unprocessedCount,
  });
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final recordRepo = await ref.watch(recordRepositoryProvider.future);
  final narratorRepo = await ref.watch(narratorRepositoryProvider.future);

  final totalRecords = await recordRepo.getTotalRecordCount();
  final narratorCount = await narratorRepo.getTotalNarratorCount();

  // 이번 달 + 미처리 수: 전체 기록에서 계산
  final allRecords = await recordRepo.getRecentRecords(100000);
  final now = DateTime.now();
  final thisMonthRecords = allRecords
      .where((r) => r.createdAt.year == now.year && r.createdAt.month == now.month)
      .length;
  final unprocessedCount = allRecords.where((r) => r.content.trim().isEmpty).length;

  return DashboardStats(
    totalRecords: totalRecords,
    thisMonthRecords: thisMonthRecords,
    narratorCount: narratorCount,
    unprocessedCount: unprocessedCount,
  );
});
