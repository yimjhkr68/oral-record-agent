import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/ontology_api.dart';

const String _hivePrefKey = 'hive_server_url';
const String defaultHiveUrl = 'http://127.0.0.1:8000';

// Hive 서버 URL — 설정 화면에서 변경 가능
final hiveUrlProvider = StateProvider<String>((ref) => defaultHiveUrl);

final hiveApiProvider = Provider<HiveApi>((ref) {
  final url = ref.watch(hiveUrlProvider);
  return HiveApi(url);
});

Future<String> loadSavedHiveUrl() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_hivePrefKey) ?? defaultHiveUrl;
}

Future<void> saveHiveUrl(String url) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_hivePrefKey, url);
}
