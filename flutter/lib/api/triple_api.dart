import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/triple.dart';

class TripleApi {
  final ApiClient _client;
  String role; // 'viewer' | 'admin'

  TripleApi(this._client, {this.role = 'viewer'});

  Options get _adminOpts => Options(headers: {'x-role': role});

  // ── 조회 (인증 불필요) ─────────────────────────────────────────────────────

  Future<List<Triple>> listTriples({
    String q = '',
    String? version,
    String status = 'active',
    String subjectType = '',
  }) async {
    final res = await _client.get('/api/triples/', params: {
      'q': q,
      if (version != null) 'version': version,
      'status': status,
      if (subjectType.isNotEmpty) 'subject_type': subjectType,
    });
    final data = res.data as Map<String, dynamic>;
    return (data['items'] as List? ?? [])
        .map((t) => Triple.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// 관리자용 목록 조회 — GET /api/triples/list
  Future<List<Triple>> listManagedTriples({
    String? version,
    String? source,
    String? createdBy,
    String? dateFrom,
    String? dateTo,
    String? status,
  }) async {
    final res = await _client.get('/api/triples/list', params: {
      if (version != null) 'version': version,
      if (source != null) 'source': source,
      if (createdBy != null) 'by': createdBy,
      if (dateFrom != null) 'from': dateFrom,
      if (dateTo != null) 'to': dateTo,
      if (status != null) 'status': status,
    });
    final data = res.data as Map<String, dynamic>;
    return (data['triples'] as List)
        .map((t) => Triple.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  // ── 쓰기 (admin role 필요) ─────────────────────────────────────────────────

  Future<Triple> createTriple({
    required String subject,
    required String subjectType,
    required String predicate,
    required String object,
    required String objectType,
    required String ontologyVersion,
    String? sourceRecordId,
    double confidence = 1.0,
    String note = '',
    String createdBy = 'admin',
    String extractionMethod = 'manual',
  }) async {
    final res = await _client.post('/api/triples/', data: {
      'subject': subject,
      'subject_type': subjectType,
      'predicate': predicate,
      'object': object,
      'object_type': objectType,
      'ontology_version': ontologyVersion,
      if (sourceRecordId != null) 'source_record_id': sourceRecordId,
      'confidence': confidence,
      'note': note,
      'created_by': createdBy,
      'extraction_method': extractionMethod,
    }, options: _adminOpts);
    return Triple.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteTriple(String id) async {
    await _client.delete('/api/triples/$id', options: _adminOpts);
  }

  Future<Triple> archiveTriple(String id, {String reason = ''}) async {
    final res = await _client.post('/api/triples/$id/archive',
        data: {'reason': reason}, options: _adminOpts);
    return Triple.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Triple> updateTriple(String id, {
    String? predicate,
    String? object,
    String? objectType,
    double? confidence,
    String? note,
    String? updatedBy,
  }) async {
    final res = await _client.patch('/api/triples/$id', data: {
      if (predicate != null) 'predicate': predicate,
      if (object != null) 'object': object,
      if (objectType != null) 'object_type': objectType,
      if (confidence != null) 'confidence': confidence,
      if (note != null) 'note': note,
      if (updatedBy != null) 'updated_by': updatedBy,
    }, options: _adminOpts);
    return Triple.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Triple> putTriple(String id, {
    String? subject,
    String? subjectType,
    String? predicate,
    String? object,
    String? objectType,
    double? confidence,
    String? note,
    String? updatedBy,
  }) async {
    final res = await _client.put('/api/triples/$id', data: {
      if (subject != null) 'subject': subject,
      if (subjectType != null) 'subject_type': subjectType,
      if (predicate != null) 'predicate': predicate,
      if (object != null) 'object': object,
      if (objectType != null) 'object_type': objectType,
      if (confidence != null) 'confidence': confidence,
      if (note != null) 'note': note,
      if (updatedBy != null) 'updated_by': updatedBy,
    }, options: _adminOpts);
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

  /// 범주별 카운트 — Map<typeName, count>
  Future<Map<String, int>> getCategories({
    String? version,
    String status = 'active',
  }) async {
    final res = await _client.get('/api/triples/categories', params: {
      if (version != null) 'version': version,
      'status': status,
    });
    final data = res.data as Map<String, dynamic>;
    final cats = data['categories'] as List? ?? [];
    return {
      for (final c in cats)
        c['name'] as String: (c['count'] as num).toInt()
    };
  }
}
