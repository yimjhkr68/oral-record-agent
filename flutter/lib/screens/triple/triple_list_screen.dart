import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/triple.dart';
import '../../providers/triple_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';

class TripleListScreen extends ConsumerStatefulWidget {
  const TripleListScreen({super.key});

  @override
  ConsumerState<TripleListScreen> createState() => _TripleListScreenState();
}

class _TripleListScreenState extends ConsumerState<TripleListScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final status = _tabController.index == 0 ? 'active' : 'archived';
      ref.read(tripleStatusProvider.notifier).state = status;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _submitSearch() {
    ref.read(tripleQueryProvider.notifier).state = _searchCtrl.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(tripleListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('트리플 관리'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AI 추출'),
            onPressed: () => context.go('/triple/extract'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: '주어, 속성, 목적어 검색...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(tripleQueryProvider.notifier).state = '';
                            },
                          ),
                        TextButton(
                          onPressed: _submitSearch,
                          child: const Text('검색'),
                        ),
                      ],
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  onSubmitted: (_) => _submitSearch(),
                ),
              ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: '활성'),
                  Tab(text: '아카이브'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('오류: $e',
                  style: AppTypography.body.copyWith(color: AppColors.error)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(tripleListProvider),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (triples) {
          if (triples.isEmpty) {
            return EmptyState(
              icon: Icons.list_alt_outlined,
              title: ref.watch(tripleQueryProvider).isEmpty
                  ? '트리플이 없습니다'
                  : '검색 결과가 없습니다',
              description: ref.watch(tripleQueryProvider).isEmpty
                  ? '[AI 추출]로 구술자료에서 추출하세요.'
                  : null,
            );
          }
          return Column(
            children: [
              _StatsBar(total: triples.length),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref.invalidate(tripleListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: triples.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _TripleCard(triple: triples[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── 통계 헤더 ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final int total;
  const _StatsBar({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _Stat(label: '트리플', value: total),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$value',
          style: AppTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary)),
      const SizedBox(width: 4),
      Text(label, style: AppTypography.caption),
    ]);
  }
}

// ── 트리플 카드 ───────────────────────────────────────────────────────────────

class _TripleCard extends ConsumerWidget {
  final Triple triple;
  const _TripleCard({required this.triple});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArchived = triple.status == TripleStatus.archived;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 주어 → 속성 → 목적어
          Row(
            children: [
              _NodeChip(label: triple.subject, type: triple.subjectType),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  const Icon(Icons.arrow_forward, size: 14,
                      color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(triple.predicate,
                      style: AppTypography.body.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14,
                      color: AppColors.textMuted),
                ]),
              ),
              _NodeChip(label: triple.object, type: triple.objectType),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _MetaChip(
                  icon: Icons.layers_outlined,
                  label: triple.ontologyVersion),
              const SizedBox(width: 6),
              _MetaChip(
                  icon: Icons.percent,
                  label: '${(triple.confidence * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 6),
              _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: triple.createdAt.length >= 10
                      ? triple.createdAt.substring(0, 10)
                      : triple.createdAt),
              if (triple.note.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(triple.note,
                      style: AppTypography.caption,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
              if (isArchived) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.archived.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: AppColors.archived.withValues(alpha: 0.3)),
                  ),
                  child: Text('아카이브',
                      style: AppTypography.badge
                          .copyWith(color: AppColors.archived)),
                ),
              ],
              const Spacer(),
              if (!isArchived) _ActionMenu(triple: triple),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodeChip extends StatelessWidget {
  final String label;
  final String type;
  const _NodeChip({required this.label, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          if (type.isNotEmpty)
            Text(type, style: AppTypography.caption),
        ],
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
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: AppColors.textMuted),
      const SizedBox(width: 3),
      Text(label, style: AppTypography.caption),
    ]);
  }
}

// ── 액션 메뉴 ─────────────────────────────────────────────────────────────────

class _ActionMenu extends ConsumerWidget {
  final Triple triple;
  const _ActionMenu({required this.triple});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      iconSize: 18,
      padding: EdgeInsets.zero,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'archive', child: Text('아카이브')),
        PopupMenuItem(
            value: 'delete',
            child: Text('삭제', style: TextStyle(color: Colors.red))),
      ],
      onSelected: (action) async {
        if (action == 'archive') {
          await _archive(context, ref);
        } else if (action == 'delete') {
          await _delete(context, ref);
        }
      },
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(tripleApiProvider).archiveTriple(triple.id);
      ref.invalidate(tripleListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('트리플 삭제'),
        content: Text(
            '"${triple.subject} → ${triple.predicate} → ${triple.object}"\n'
            '를 영구 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(tripleApiProvider).deleteTriple(triple.id);
      ref.invalidate(tripleListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }
}
