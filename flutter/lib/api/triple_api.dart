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

  Future<Triple> updateTriple(String id, {
    String? predicate,
    String? object,
    String? objectType,
    double? confidence,
    String? note,
  }) async {
    final res = await _client.patch('/api/triples/$id', data: {
      if (predicate != null) 'predicate': predicate,
      if (object != null) 'object': object,
      if (objectType != null) 'object_type': objectType,
      if (confidence != null) 'confidence': confidence,
      if (note != null) 'note': note,
    });
    return Triple.fromJson(res.data as Map<String, dynamic>);
  }

  /// AI 추출 — DB 저장 없이 미리보기 반환 (120초 타임아웃)
  /// 반환: {"triples": [...], "count": N, "source_record_id": "..."}
  Future<Map<String, dynamic>> extractTriples(
    String content,
    String ontologyVersionId, {
    String? sourceRecordId,
  }) async {
    final res = await _client.postAI('/api/triples/extract', data: {
      'content': content,
      'ontology_version_id': ontologyVersionId,
      if (sourceRecordId != null && sourceRecordId.isNotEmpty)
        'source_record_id': sourceRecordId,
    });
    return res.data as Map<String, dynamic>;
  }

  /// 검토 완료된 pending 트리플 → GraphDB에 일괄 저장
  Future<Map<String, dynamic>> bulkConfirm(
      List<Map<String, dynamic>> triples) async {
    final res = await _client.post('/api/triples/bulk-confirm',
        data: {'triples': triples});
    return res.data as Map<String, dynamic>;
  }
}
