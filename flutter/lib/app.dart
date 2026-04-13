import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'theme/app_typography.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/ontology/ontology_list_screen.dart';
import 'screens/triple/triple_screen.dart';
import 'screens/graph/knowledge_graph_screen.dart';
import 'screens/records/record_list_screen.dart';
import 'screens/history/history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/ontology',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
              path: '/ontology',
              builder: (c, s) => const OntologyListScreen()),
          GoRoute(
              path: '/triple',
              builder: (c, s) => const TripleScreen()),
          GoRoute(
              path: '/graph',
              builder: (c, s) => const KnowledgeGraphScreen()),
          GoRoute(
              path: '/records',
              builder: (c, s) => const RecordListScreen()),
          GoRoute(
              path: '/history',
              builder: (c, s) => const HistoryScreen()),
          GoRoute(
              path: '/settings',
              builder: (c, s) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class OralRecordApp extends ConsumerWidget {
  const OralRecordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Oral Record Agent v4.0 — Ontology Knowledge Graph',
      theme: buildLightTheme(),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

// ── 네비게이션 항목 데이터 ─────────────────────────────
class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
  const _NavItemData(this.icon, this.selectedIcon, this.label, this.route);
}

const _navItems = [
  _NavItemData(Icons.account_tree_outlined, Icons.account_tree,
      '온톨로지', '/ontology'),
  _NavItemData(Icons.list_alt_outlined, Icons.list_alt,
      '트리플', '/triple'),
  _NavItemData(Icons.hub_outlined, Icons.hub,
      '지식그래프', '/graph'),
  _NavItemData(Icons.library_books_outlined, Icons.library_books,
      '기록', '/records'),
  _NavItemData(Icons.history_outlined, Icons.history,
      '이력', '/history'),
  _NavItemData(Icons.settings_outlined, Icons.settings,
      '설정', '/settings'),
];

// ── AppShell ──────────────────────────────────────────
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _selectedIndex(location);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ── 커스텀 사이드바 ──────────────────────────
          Container(
            width: 64,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                // 로고 영역
                Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Tooltip(
                    message: '구술기록 지식그래프',
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.hub, size: 18,
                          color: Colors.white),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // 네비게이션 아이템
                ...List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final isSelected = selectedIndex == i;
                  return _NavItem(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: item.label,
                    selected: isSelected,
                    onTap: () => context.go(item.route),
                  );
                }),

                const Spacer(),

                // 하단 버전 표시
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('v4', style: AppTypography.caption),
                ),
              ],
            ),
          ),

          // ── 메인 콘텐츠 ────────────────────────────
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/ontology')) return 0;
    if (location.startsWith('/triple'))   return 1;
    if (location.startsWith('/graph'))    return 2;
    if (location.startsWith('/records'))  return 3;
    if (location.startsWith('/history'))  return 4;
    if (location.startsWith('/settings')) return 5;
    return 0;
  }
}

// ── 네비게이션 아이템 위젯 ────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.label,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.primaryFaint
                  : _hovered
                      ? AppColors.surfaceHover
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: widget.selected
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4))
                  : null,
            ),
            child: Icon(
              widget.selected ? widget.selectedIcon : widget.icon,
              size: 20,
              color: widget.selected
                  ? AppColors.primary
                  : _hovered
                      ? AppColors.textSecondary
                      : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
