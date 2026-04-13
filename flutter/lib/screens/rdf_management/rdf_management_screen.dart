import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'migration_screen.dart';
import 'ontology_editor_screen.dart';
import 'validation_screen.dart';
import 'semantic_search_screen.dart';
import 'publish_screen.dart';

// ── RDF 관리 메인 화면 — 5개 서브탭 ─────────────────────────────────────────
class RdfManagementScreen extends ConsumerStatefulWidget {
  const RdfManagementScreen({super.key});

  @override
  ConsumerState<RdfManagementScreen> createState() =>
      _RdfManagementScreenState();
}

class _RdfManagementScreenState extends ConsumerState<RdfManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _tabs = [
    (Icons.swap_horiz, '마이그레이션'),
    (Icons.edit_note, '온톨로지편집'),
    (Icons.verified_outlined, '품질검증'),
    (Icons.manage_search, '추론검색'),
    (Icons.publish, '공표'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // ── 헤더 ─────────────────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree,
                          size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('RDF 관리', style: AppTypography.heading2),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFaint,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.4)),
                        ),
                        child: Text('v5.0',
                            style: AppTypography.badge.copyWith(
                                color: AppColors.secondary)),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tab,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: _tabs
                      .map((t) => Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t.$1, size: 14),
                                const SizedBox(width: 6),
                                Text(t.$2),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
              ],
            ),
          ),
          // ── 탭 본문 ───────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                const MigrationScreen(),
                const OntologyEditorScreen(),
                const ValidationScreen(),
                const SemanticSearchScreen(),
                const PublishScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
