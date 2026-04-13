import 'package:shared_preferences/shared_preferences.dart';

/// 범주(구술자 ID) 표시/숨김 설정 — SharedPreferences 영속
class GraphVisibilitySettings {
  static const _prefix = 'graph_visibility_';
  static final Map<String, bool> _cache = {};

  /// 앱 시작 시 또는 필요 시 캐시 초기화
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cache.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final id = key.replaceFirst(_prefix, '');
        _cache[id] = prefs.getBool(key) ?? true;
      }
    }
  }

  /// 해당 ID 표시 여부 (캐시 없으면 기본 true)
  static bool isVisible(String id) => _cache[id] ?? true;

  /// 표시 설정 변경 + 영속 저장
  static Future<void> setVisible(String id, bool visible) async {
    _cache[id] = visible;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$id', visible);
  }

  /// 전체 초기화 (모두 표시)
  static Future<void> resetAll() async {
    _cache.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix)) await prefs.remove(key);
    }
  }
}
