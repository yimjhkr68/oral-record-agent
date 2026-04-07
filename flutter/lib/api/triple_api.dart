import 'api_client.dart';
import '../models/triple.dart';

class TripleApi {
  final ApiClient _client;
  TripleApi(this._client);

  Future<GraphData> listTriples({
    String q = '',
    String? version,
    String status = 'active',
  }) async {
    final res = await _client.get('/api/triples/', params: {
      'q': q,
      if (version != null) 'version': version,
      'status': status,
    });
    return GraphData.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteTriple(String id) async {
    await _client.delete('/api/triples/$id');
  }

  Future<Triple> archiveTriple(String id, {String reason = ''}) async {
    final res = await _client
        .post('/api/triples/$id/archive', data: {'reason': reason});
    return Triple.fromJson(res.data as Map<String, dynamic>);
  }

  /// 반환: {"added": N, "skipped": N, "triples": [...]}
  Future<Map<String, dynamic>> extractTriples(
    String content,
    String ontologyVersionId, {
    String? sourceRecordId,
  }) async {
    final res = await _client.post('/api/triples/extract', data: {
      'content': content,
      'ontology_version_id': ontologyVersionId,
      if (sourceRecordId != null && sourceRecordId.isNotEmpty)
        'source_record_id': sourceRecordId,
    });
    return res.data as Map<String, dynamic>;
  }
}
