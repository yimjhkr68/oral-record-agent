import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/ontology/ontology_list_screen.dart';
import 'screens/ontology/ontology_detail_screen.dart';
import 'screens/triple/triple_list_screen.dart';
import 'screens/triple/triple_extract_screen.dart';
import 'screens/graph/knowledge_graph_screen.dart';

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
              path: '/ontology/:versionId',
              builder: (c, s) =>
                  OntologyDetailScreen(versionId: s.pathParameters['versionId']!)),
          GoRoute(
              path: '/triple',
              builder: (c, s) => const TripleListScreen()),
          GoRoute(
              path: '/triple/extract',
              builder: (c, s) => const TripleExtractScreen()),
          GoRoute(
              path: '/graph',
              builder: (c, s) => const KnowledgeGraphScreen()),
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
      title: '구술기록 지식그래프 v4.0',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex(location),
            onDestinationSelected: (i) => _navigate(context, i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('구술기록\n지식그래프',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: Text('온톨로지')),
              NavigationRailDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: Text('트리플')),
              NavigationRailDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub),
                  label: Text('지식그래프')),
              NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('설정')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/ontology')) return 0;
    if (location.startsWith('/triple')) return 1;
    if (location.startsWith('/graph')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/ontology');
      case 1:
        context.go('/triple');
      case 2:
        context.go('/graph');
      case 3:
        context.go('/settings');
    }
  }
}
