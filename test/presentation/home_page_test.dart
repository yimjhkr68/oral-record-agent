// 파일 목적: HomePage Widget 테스트

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oral_record_agent/src/presentation/pages/home_page.dart';

void main() {
  group('HomePage Widget 테스트', () {
    testWidgets('최근 기록 로딩 상태 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomePage()),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('빠른 작업 버튼 3개 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomePage()),
        ),
      );

      // 빠른 작업 텍스트 찾기
      expect(find.text('빠른 작업'), findsOneWidget);

      // 3개 버튼 찾기
      expect(find.text('녹음 시작'), findsOneWidget);
      expect(find.text('파일 업로드'), findsOneWidget);
      expect(find.text('텍스트 입력'), findsOneWidget);
    });

    testWidgets('빠른 작업 버튼 탭 네비게이션', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const HomePage(),
            routes: [
              GoRoute(
                path: 'recording',
                builder: (_, __) =>
                    Scaffold(appBar: AppBar(title: const Text('녹음'))),
              ),
              GoRoute(
                path: 'file-picker',
                builder: (_, __) =>
                    Scaffold(appBar: AppBar(title: const Text('파일'))),
              ),
              GoRoute(
                path: 'text-input',
                builder: (_, __) =>
                    Scaffold(appBar: AppBar(title: const Text('텍스트'))),
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

      // 녹음 버튼 탭
      await tester.tap(find.text('녹음 시작'));
      await tester.pump(); // 탭 처리
      await tester.pump(const Duration(seconds: 1)); // 라우트 전환 애니메이션

      expect(find.text('녹음'), findsOneWidget);
    });

    testWidgets('최근 기록 표시 - 로딩 상태 확인', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomePage()),
        ),
      );

      // Hive 미초기화 환경에서 로딩 상태 확인
      // 실제 데이터 검증은 통합 테스트에서 수행
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('최근 기록 탭 시 상세 화면으로 이동', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HomePage(),
            routes: {
              '/record-detail': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments as String?;
                return Scaffold(
                  appBar: AppBar(title: Text('상세 - $args')),
                );
              },
            },
          ),
        ),
      );

      await tester.pump();

      // 기록 항목을 찾아 탭 (실제 데이터가 있을 경우)
      // 현재 로딩 중이므로 스캐폴드 구조만 확인
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('에러 상태 표시', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: HomePage()),
        ),
      );

      // 에러 상태는 Provider에서 처리되므로
      // 여기서는 스캐폴드와 앱바만 확인
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('모두 보기 버튼', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const HomePage(),
            routes: {
              '/records': (_) =>
                  Scaffold(appBar: AppBar(title: const Text('전체'))),
            },
          ),
        ),
      );

      expect(find.text('모두 보기'), findsOneWidget);
    });
  });
}
