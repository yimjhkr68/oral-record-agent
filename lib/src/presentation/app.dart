// 파일 목적: 메인 앱 구조
// Material 앱 래퍼, Riverpod 설정, 라우팅 통합, 인증 분기

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routes.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'providers/auth_provider.dart';
import 'providers/duration_backfill_provider.dart';
import 'providers/display_id_migration_provider.dart';

/// 메인 애플리케이션 위젯
class OralRecordApp extends ConsumerWidget {
  const OralRecordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // 로그인 전: 로그인 화면만 표시
    if (!authState.isLoggedIn) {
      return MaterialApp(
        title: '구술기록 관리 시스템',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginPage(),
      );
    }

    // 로그인 후: 앱 시작 시 백그라운드 작업 실행
    ref.read(durationBackfillProvider);
    ref.read(displayIdMigrationProvider);

    return MaterialApp.router(
      title: '구술기록 관리 시스템',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: goRouter,
    );
  }
}
