import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/api_client.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureDefaultSettings();
  runApp(const ProviderScope(child: OralRecordApp()));
}

/// 최초 실행 시 SharedPreferences에 기본값 저장
Future<void> _ensureDefaultSettings() async {
  final prefs = await SharedPreferences.getInstance();
  if (!prefs.containsKey('server_url')) {
    await prefs.setString('server_url', defaultServerUrl);
  }
}
