import 'package:dio/dio.dart';
import '../api/api_client.dart';
import '../models/oral_record.dart';

class RecordApi {
  final ApiClient _client;
  RecordApi(this._client);

  Future<List<OralRecord>> list({
    String q = '',
    String sourceType = '',
    int limit = 100,
  }) async {
    final res = await _client.get('/api/records/', params: {
      if (q.isNotEmpty) 'q': q,
      if (sourceType.isNotEmpty) 'source_type': sourceType,
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

  Future<OralRecord> createFile({
    required String filePath,
    required String fileName,
    String note = '',
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (note.isNotEmpty) 'note': note,
    });
    final res = await _client.postFormData('/api/records/file', formData);
    return OralRecord.fromJson(res.data);
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
