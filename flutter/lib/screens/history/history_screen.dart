import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/history_provider.dart';
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
            onPressed: () {
              ref.read(ontologyEventProvider.notifier).load();
              ref.read(sessionListProvider.notifier).load();
              ref.invalidate(historySummaryProvider);
            },
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
            loading: () => const SizedBox(height: 4,
                child: LinearProgressIndicator()),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('구술기록', summary.records),
          _Stat('온톨로지', summary.ontologyVersions),
          _Stat('확정', summary.confirmedOntologies),
          _Stat('추출 세션', summary.extractionSessions),
          if (summary.lastActivity.isNotEmpty)
            Text('마지막 활동: ${summary.lastActivity}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
