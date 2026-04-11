import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/api_client.dart';
import 'app.dart';
import 'services/graph_color_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureDefaultSettings();
  await GraphColorSettings.init();
  runApp(const ProviderScope(child: OralRecordApp()));
}

/// 최초 실행 시 SharedPreferences에 기본값 저장
Future<void> _ensureDefaultSettings() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('server_url')) {
    await prefs.setString('server_url', defaultServerUrl);
  }
}

/// 저장된 API 키를 서버에 주입 — 앱 연결 후 호출
Future<void> injectSavedApiKey(ApiClient client) async {
  final prefs = await SharedPreferences.getInstance();
  final key = prefs.getString('anthropic_api_key') ?? '';
  if (key.isEmpty) return;
  try {
    await client.post('/api/settings/api-key', data: {'api_key': key});
  } catch (_) {
    // 서버 미시작 시 무시 — 설정 화면에서 [저장] 시 재시도됨
  }
}
