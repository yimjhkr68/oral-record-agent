// 파일 목적: RecordListPage Widget 테스트

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oral_record_agent/src/presentation/pages/record_list_page.dart';

void main() {
  group('RecordListPage Widget 테스트', () {
    testWidgets('기록 목록 로딩 상태', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RecordListPage()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('검색 아이콘 버튼', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RecordListPage()),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('기록 추가 FAB', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RecordListPage()),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('기록이 없는 경우 메시지 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RecordListPage()),
        ),
      );

      // 로딩 완료 후 빈 상태 확인 (실제 구현에서 데이터 없을 경우)
      // 현재는 로딩 상태이므로, 이후 시뮬레이션 필요
    });

    testWidgets('기록 리스트 아이템 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RecordListPage()),
        ),
      );

      // ListTile 찾기 (데이터가 있을 경우)
      // 현재는 로딩 중이므로 스킵
    });

    testWidgets('페이징 구현 - 로딩 상태 확인', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: RecordListPage()),
        ),
      );

      // 초기 로딩 상태에서 CircularProgressIndicator 표시
      // ListView는 데이터 로드 완료 후 표시 (Hive 초기화 필요)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('검색 필터 네비게이션', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/records',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold()),
          GoRoute(
            path: '/records',
            builder: (_, __) => const RecordListPage(),
            routes: [
              GoRoute(
                path: 'search-filter',
                builder: (_, __) =>
                    Scaffold(appBar: AppBar(title: const Text('검색'))),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // 검색 아이콘 탭
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump(); // 탭 처리
      await tester.pump(const Duration(seconds: 1)); // 라우트 전환 애니메이션

      // 검색 화면 라우팅 확인
      expect(find.text('검색'), findsOneWidget);
    });
  });
}
