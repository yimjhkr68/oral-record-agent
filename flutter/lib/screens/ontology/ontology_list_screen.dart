import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/ontology.dart';
import '../../providers/ontology_provider.dart';

class OntologyListScreen extends ConsumerWidget {
  const OntologyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(ontologyListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('온톨로지 관리'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('샘플에서 AI 생성'),
            onPressed: () => _showGenerateDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('새 버전'),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오류: $e', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(ontologyListProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (versions) {
          if (versions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_tree_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('온톨로지 버전이 없습니다.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('새 버전 만들기'),
                    onPressed: () => _showCreateDialog(context, ref),
                  ),
                ],
              ),
            );
          }
          // 최신순 정렬
          final sorted = [...versions]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ontologyListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) =>
                  _VersionCard(version: sorted[i]),
            ),
          );
        },
      ),
    );
  }

  // ── [+ 새 버전] 다이얼로그 ──────────────────────────────────────────────────
  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final idCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 온톨로지 버전'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: '버전 ID',
                  hintText: 'v1.0',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '버전 ID를 입력하세요' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: '설명 (선택)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    try {
      await ref
          .read(ontologyApiProvider)
          .createDraft(idCtrl.text.trim(), descCtrl.text.trim());
      ref.invalidate(ontologyListProvider);
    } catch (e) {
      if (context.mounted) {
        _showError(context, e.toString());
      }
    }
  }

  // ── [샘플에서 AI 생성] 다이얼로그 ────────────────────────────────────────────
  Future<void> _showGenerateDialog(BuildContext context, WidgetRef ref) async {
    final textCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('샘플 텍스트로 AI 온톨로지 생성'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '구술 자료 샘플 텍스트를 입력하면 AI가 온톨로지를 자동 생성합니다.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: textCtrl,
                    decoration: const InputDecoration(
                      labelText: '구술 샘플 텍스트',
                      hintText: '예) 김철수는 1950년 서울에서 태어났으며...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '텍스트를 입력하세요' : null,
                  ),
                  if (loading) ...[
                    const SizedBox(height: 16),
                    const Row(children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('AI 생성 중...', style: TextStyle(fontSize: 13)),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('AI 생성'),
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => loading = true);
                      try {
                        await ref
                            .read(ontologyApiProvider)
                            .generateFromSample(textCtrl.text.trim());
                        ref.invalidate(ontologyListProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setState(() => loading = false);
                        if (ctx.mounted) _showError(ctx, e.toString());
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// ── 버전 카드 ────────────────────────────────────────────────────────────────

class _VersionCard extends ConsumerWidget {
  final OntologyVersion version;
  const _VersionCard({required this.version});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _StatusBadge(status: version.status),
        title: Text(
          version.versionId,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (version.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(version.description,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 4),
            Text(
              '클래스 ${version.classes.length}개  ·  속성 ${version.predicates.length}개  ·  ${_formatDate(version.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/ontology/${version.versionId}'),
      ),
    );
  }

  String _formatDate(String iso) {
    if (iso.length < 10) return iso;
    return iso.substring(0, 10);
  }
}

// ── 상태 배지 ────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OntologyStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OntologyStatus.draft => ('Draft', const Color(0xFF1976D2)),
      OntologyStatus.confirmed => ('Confirmed', const Color(0xFF388E3C)),
      OntologyStatus.archived => ('Archived', const Color(0xFF757575)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
