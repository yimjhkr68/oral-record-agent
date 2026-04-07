import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ontology.dart';
import '../../providers/ontology_provider.dart';

class OntologyDetailScreen extends ConsumerWidget {
  final String versionId;
  const OntologyDetailScreen({super.key, required this.versionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(ontologyDetailProvider(versionId));

    return detailAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(versionId)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(versionId)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오류: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.invalidate(ontologyDetailProvider(versionId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      data: (version) => _DetailView(version: version),
    );
  }
}

// ── 실제 상세 뷰 ─────────────────────────────────────────────────────────────

class _DetailView extends ConsumerWidget {
  final OntologyVersion version;
  const _DetailView({required this.version});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDraft = version.status == OntologyStatus.draft;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(version.versionId,
                  style: const TextStyle(fontSize: 16,
                      fontWeight: FontWeight.bold)),
              _StatusChip(status: version.status),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.category_outlined), text: '클래스'),
              Tab(icon: Icon(Icons.link_outlined), text: '속성'),
            ],
          ),
          actions: [
            if (isDraft)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('확정하기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF388E3C),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _confirmVersion(context, ref),
                ),
              ),
            if (!isDraft)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: const Text('읽기 전용',
                      style: TextStyle(fontSize: 12)),
                  backgroundColor:
                      Colors.grey.withValues(alpha: 0.15),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // 버전 메타 정보
            _MetaInfo(version: version),
            const Divider(height: 1),
            // 탭 내용
            Expanded(
              child: TabBarView(
                children: [
                  _ClassesTab(classes: version.classes),
                  _PredicatesTab(predicates: version.predicates),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmVersion(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('온톨로지 확정'),
        content: Text(
            '"${version.versionId}"을 확정하시겠습니까?\n'
            '확정 후에는 수정 및 삭제가 불가능합니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF388E3C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('확정'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    try {
      await ref.read(ontologyApiProvider).confirmVersion(version.versionId);
      ref.invalidate(ontologyDetailProvider(version.versionId));
      ref.invalidate(ontologyListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('확정 완료')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('오류: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ── 메타 정보 헤더 ────────────────────────────────────────────────────────────

class _MetaInfo extends StatelessWidget {
  final OntologyVersion version;
  const _MetaInfo({required this.version});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _MetaItem(label: '생성일', value: _fmt(version.createdAt)),
          if (version.confirmedAt != null) ...[
            const SizedBox(width: 24),
            _MetaItem(label: '확정일', value: _fmt(version.confirmedAt!)),
          ],
          const SizedBox(width: 24),
          _MetaItem(
              label: '클래스',
              value: '${version.classes.length}개'),
          const SizedBox(width: 24),
          _MetaItem(
              label: '속성',
              value: '${version.predicates.length}개'),
          if (version.description.isNotEmpty) ...[
            const SizedBox(width: 24),
            Expanded(
              child: _MetaItem(
                  label: '설명', value: version.description),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value,
            style: const TextStyle(fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── 클래스 탭 ─────────────────────────────────────────────────────────────────

class _ClassesTab extends StatelessWidget {
  final List<OntologyClass> classes;
  const _ClassesTab({required this.classes});

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const Center(
          child: Text('클래스 없음', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: classes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ClassCard(cls: classes[i]),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final OntologyClass cls;
  const _ClassCard({required this.cls});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(cls.color);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 색상 도트
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 3, right: 10),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(cls.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 8),
                    Text('(${cls.labelKo})',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.grey)),
                  ]),
                  if (cls.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(cls.description,
                        style: const TextStyle(fontSize: 13)),
                  ],
                  if (cls.examples.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: cls.examples
                          .map((e) => Chip(
                                label: Text(e,
                                    style: const TextStyle(fontSize: 11)),
                                padding: EdgeInsets.zero,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 속성 탭 ───────────────────────────────────────────────────────────────────

class _PredicatesTab extends StatelessWidget {
  final List<OntologyPredicate> predicates;
  const _PredicatesTab({required this.predicates});

  @override
  Widget build(BuildContext context) {
    if (predicates.isEmpty) {
      return const Center(
          child: Text('속성 없음', style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: predicates.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _PredicateCard(pred: predicates[i]),
    );
  }
}

class _PredicateCard extends StatelessWidget {
  final OntologyPredicate pred;
  const _PredicateCard({required this.pred});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름 + 도메인→레인지
            Row(children: [
              const Icon(Icons.link, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(pred.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              if (pred.domain.isNotEmpty || pred.range.isNotEmpty)
                Text(
                  '${pred.domain.join(', ')} → ${pred.range.join(', ')}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF1565C0)),
                ),
            ]),
            if (pred.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(pred.description,
                  style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 상태 칩 ───────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final OntologyStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OntologyStatus.draft => ('Draft', const Color(0xFF1976D2)),
      OntologyStatus.confirmed => ('Confirmed', const Color(0xFF388E3C)),
      OntologyStatus.archived => ('Archived', const Color(0xFF757575)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── 유틸 ─────────────────────────────────────────────────────────────────────

Color _parseColor(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length == 6) {
    return Color(int.parse('FF$h', radix: 16));
  }
  return const Color(0xFF888888);
}
