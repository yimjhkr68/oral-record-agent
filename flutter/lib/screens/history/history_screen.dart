import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/history_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'ontology_history_tab.dart';
import 'extraction_history_tab.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모든 이력 삭제'),
        content: const Text(
            '온톨로지 이력과 트리플 생성 이력을 모두 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('전체 삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(historyApiProvider).clearAll();
    ref.read(ontologyEventProvider.notifier).clearAll();
    ref.read(sessionListProvider.notifier).clearAll();
    ref.invalidate(historySummaryProvider);
  }

  void _refresh() {
    ref.read(ontologyEventProvider.notifier).load();
    ref.read(sessionListProvider.notifier).load();
    ref.invalidate(historySummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(historySummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('이력'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: '모든 이력 삭제',
            onPressed: _clearAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '온톨로지 이력'),
            Tab(text: '트리플 생성 이력'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── 요약 통계 ────────────────────────────────────────────────────
          summary.when(
            data: (s) => _SummaryBar(summary: s),
            loading: () =>
                const SizedBox(height: 4, child: LinearProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(height: 1),
          // ── 탭 콘텐츠 ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: const [
                OntologyHistoryTab(),
                ExtractionHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 요약 통계 바 ──────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final dynamic summary;
  const _SummaryBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('구술기록', summary.records),
          _Stat('온톨로지', summary.ontologyVersions),
          _Stat('확정', summary.confirmedOntologies),
          _Stat('추출 세션', summary.extractionSessions),
          if (summary.lastActivity.isNotEmpty)
            Text('마지막 활동: ${summary.lastActivity}',
                style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value',
            style: AppTypography.heading1.copyWith(
                color: AppColors.primary, letterSpacing: 0)),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}
