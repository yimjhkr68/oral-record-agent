// 파일 목적: 라우팅 구성 (v2 - ShellRoute + 인물사전 추가)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'pages/record_input_pages.dart';
import 'pages/metadata_input_page.dart';
import 'pages/record_list_page.dart';
import 'pages/search_filter_page.dart';
import 'pages/record_detail_page.dart';
import 'pages/settings_page.dart';
import 'pages/people_page.dart';
import 'pages/narrator_detail_page.dart';
import 'pages/interviewer_detail_page.dart';
import 'pages/add_edit_narrator_page.dart';
import 'pages/add_edit_interviewer_page.dart';
import 'pages/search_page.dart';
import 'pages/account_management_page.dart';
import 'screens/agent_screen.dart';

// ── 공통 하단 네비게이션 바 ────────────────────────────────────
class AppBottomNavBar extends StatelessWidget {
  /// 현재 선택된 탭 인덱스 (0=홈, 1=인물사전, 2=기록목록, 3=검색, 4=설정)
  /// -1이면 아무 탭도 선택되지 않은 상태 (상세 화면 등)
  final int currentIndex;

  const AppBottomNavBar({super.key, this.currentIndex = -1});

  static const _routes = ['/', '/people', '/records', '/search', '/settings', '/agent'];

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex >= 0;
    return BottomNavigationBar(
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: isActive ? AppTheme.primary : Colors.grey,
      unselectedItemColor: AppTheme.textDisabled,
      selectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      backgroundColor: AppTheme.surface,
      elevation: 8,
      onTap: (i) => context.go(_routes[i]),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: '홈',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: '인물사전',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: '기록 목록',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: '검색',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: '설정',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.smart_toy_outlined),
          activeIcon: Icon(Icons.smart_toy),
          label: '에이전트',
        ),
      ],
    );
  }
}

// ── 셸 위젯 (주요 화면: NavigationRail 제거, BottomNavBar 사용) ──
class _AppShell extends StatelessWidget {
  final Widget child;
  const _AppShell({required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/people')) return 1;
    if (location.startsWith('/records')) return 2;
    if (location.startsWith('/search')) return 3;
    if (location.startsWith('/settings')) return 4;
    if (location.startsWith('/agent')) return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNavBar(currentIndex: selectedIndex),
    );
  }
}

// ── 라우터 ────────────────────────────────────────────────────
final goRouter = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    // ── Shell: NavigationRail 포함 주요 화면 ──
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/people',
          builder: (context, state) => const PeoplePage(),
        ),
        GoRoute(
          path: '/records',
          builder: (context, state) => const RecordListPage(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const SearchPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/agent',
          builder: (context, state) => const AgentScreen(),
        ),
      ],
    ),

    // ── 독립 화면 (NavigationRail 없음) ──
    GoRoute(
      path: '/recording',
      builder: (context, state) => const RecordingPage(),
    ),
    GoRoute(
      path: '/file-picker',
      builder: (context, state) => const FilePickerPage(),
    ),
    GoRoute(
      path: '/text-input',
      builder: (context, state) => const TextInputPage(),
    ),
    GoRoute(
      path: '/metadata-input',
      builder: (context, state) => const MetadataInputPage(),
    ),

    // 기록 상세/검색
    GoRoute(
      path: '/records/search-filter',
      builder: (context, state) => const SearchFilterPage(),
    ),
    GoRoute(
      path: '/records/detail/:recordId',
      builder: (context, state) {
        final recordId = state.pathParameters['recordId'] ?? '';
        return RecordDetailPage(recordId: recordId);
      },
    ),

    // 계정 관리 (관리자 전용)
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const AccountManagementPage(),
    ),

    // 인물사전 상세/추가/편집
    GoRoute(
      path: '/people/narrator/add',
      builder: (context, state) => const AddEditNarratorPage(),
    ),
    GoRoute(
      path: '/people/narrator/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return NarratorDetailPage(narratorId: id);
      },
    ),
    GoRoute(
      path: '/people/narrator/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AddEditNarratorPage(narratorId: id);
      },
    ),
    GoRoute(
      path: '/people/interviewer/add',
      builder: (context, state) => const AddEditInterviewerPage(),
    ),
    GoRoute(
      path: '/people/interviewer/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return InterviewerDetailPage(interviewerId: id);
      },
    ),
    GoRoute(
      path: '/people/interviewer/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AddEditInterviewerPage(interviewerId: id);
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('라우트 오류: ${state.error}')),
  ),
);

class RoutePaths {
  static const String home = '/';
  static const String people = '/people';
  static const String recording = '/recording';
  static const String filePicker = '/file-picker';
  static const String textInput = '/text-input';
  static const String metadataInput = '/metadata-input';
  static const String records = '/records';
  static const String searchFilter = '/records/search-filter';
  static const String search = '/search';
  static const String settings = '/settings';
}
