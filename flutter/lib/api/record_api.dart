import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/oral_record.dart';

class RecordApi {
  final ApiClient _client;
  RecordApi(this._client);

  Future<List<OralRecord>> list({
    String q = '',
    String sourceType = '',
    String source = '',
    int limit = 100,
  }) async {
    final res = await _client.get('/api/records/', params: {
      if (q.isNotEmpty) 'q': q,
      if (sourceType.isNotEmpty) 'source_type': sourceType,
      if (source.isNotEmpty) 'source': source,
      'limit': limit,
    });
    final List items = res.data['records'] ?? [];
    return items.map((e) => OralRecord.fromJson(e)).toList();
  }

  Future<OralRecord> get(String id) async {
    final res = await _client.get('/api/records/$id');
    return OralRecord.fromJson(res.data);
  }

  Future<OralRecord> createText({
    required String title,
    required String content,
    String note = '',
  }) async {
    final res = await _client.post('/api/records/text', data: {
      'title': title,
      'content': content,
      'note': note,
    });
    return OralRecord.fromJson(res.data);
  }

  /// bytes 기반 파일 업로드 (Windows desktop 호환)
  Future<OralRecord> createFileFromBytes({
    required List<int> bytes,
    required String fileName,
    String note = '',
    String source = 'manual',
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      'note': note,
      'source': source,
    });
    final res = await _client.postFormData('/api/records/file', formData);
    return OralRecord.fromJson(res.data);
  }

  /// 원본 파일 다운로드 — bytes 반환
  Future<List<int>> downloadFile(String id) async {
    final res = await _client.get(
      '/api/records/$id/download',
      options: Options(responseType: ResponseType.bytes),
    );
    return (res.data as List<dynamic>).cast<int>();
  }

  Future<OralRecord> update(
    String id, {
    String? title,
    String? note,
  }) async {
    final res = await _client.patch('/api/records/$id', data: {
      if (title != null) 'title': title,
      if (note != null) 'note': note,
    });
    return OralRecord.fromJson(res.data);
  }

  Future<void> delete(String id) async {
    await _client.delete('/api/records/$id');
  }

  Future<List<Map<String, dynamic>>> getUsage(String id) async {
    final res = await _client.get('/api/records/$id/usage');
    final List items = res.data['sessions'] ?? [];
    return items.cast<Map<String, dynamic>>();
  }
}
