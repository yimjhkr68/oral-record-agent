import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String defaultServerUrl = 'http://127.0.0.1:9000';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late Dio _dio;    // 일반 API: 목록 조회, CRUD
  late Dio _aiDio;  // AI 호출: generate, merge (타임아웃 120초)
  String _baseUrl = defaultServerUrl;

  ApiClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _aiDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 120),
      headers: {'Content-Type': 'application/json'},
    ));
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? defaultServerUrl;
    _dio.options.baseUrl = _baseUrl;
    _aiDio.options.baseUrl = _baseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    _aiDio.options.baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  String get baseUrl => _baseUrl;

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get('$_baseUrl$path', queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post('$_baseUrl$path', data: data);

  /// AI 생성/종합 전용 — receiveTimeout 120초
  Future<Response> postAI(String path, {dynamic data}) =>
      _aiDio.post('$_baseUrl$path', data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch('$_baseUrl$path', data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put('$_baseUrl$path', data: data);

  Future<Response> delete(String path) => _dio.delete('$_baseUrl$path');

  Future<Response> postFormData(String path, FormData data) =>
      _dio.post('$_baseUrl$path', data: data);

  Future<bool> checkConnection() async {
    try {
      await _dio.get('$_baseUrl/health');
      return true;
    } catch (_) {
      return false;
    }
  }
}
