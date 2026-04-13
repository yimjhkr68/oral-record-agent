import 'dart:async' show unawaited;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/data/hive_service.dart';
import 'src/data/services/auth_service.dart';
import 'src/data/services/rag_server_service.dart';
import 'src/presentation/app.dart';
import 'src/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일에서 환경 변수 로딩 (파일 없어도 앱 실행 가능)
  String apiKey = '';
  try {
    await dotenv.load(fileName: '.env');
    apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
  } catch (_) {
    // .env 누락 시 API 키 없이 실행 (로컬 Whisper 모드로 동작)
  }

  // RAG 서버 (Qdrant + FastAPI) 시작 - 실패해도 앱 실행에 영향 없음
  unawaited(RagServerService.start());

  // Hive 초기화 및 어댑터 등록 (lock 충돌 시 재시도)
  await HiveService.initializeHive();
  try {
    await HiveService.initializeAllBoxes();
    await HiveService.seedSampleData();
    await AuthService.seedAdminAccount();
  } catch (e) {
    // lock 충돌 등으로 실패 시 1초 대기 후 재시도
    await Future.delayed(const Duration(seconds: 1));
    await HiveService.initializeAllBoxes();
    await HiveService.seedSampleData();
    await AuthService.seedAdminAccount();
  }

  runApp(
    ProviderScope(
      overrides: [
        // .env에서 읽은 API 키로 설정 초기화
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(initialApiKey: apiKey),
        ),
      ],
      child: const OralRecordApp(),
    ),
  );
}
