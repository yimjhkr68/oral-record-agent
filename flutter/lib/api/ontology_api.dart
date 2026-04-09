import 'package:dio/dio.dart';
import 'api_client.dart';
import '../models/ontology.dart';

class OntologyApi {
  final ApiClient _client;
  OntologyApi(this._client);

  Future<List<OntologyVersion>> listVersions() async {
    final res = await _client.get('/api/ontologies/');
    return (res.data as List)
        .map((e) => OntologyVersion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OntologyVersion> getVersion(String versionId) async {
    final res = await _client.get('/api/ontologies/$versionId');
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> createDraft(
      String versionId, String description) async {
    final res = await _client.post('/api/ontologies/', data: {
      'version_id': versionId,
      'description': description,
    });
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> updateDraft(
    String versionId, {
    List<OntologyClass>? classes,
    List<OntologyPredicate>? predicates,
    String? description,
  }) async {
    final res = await _client.patch('/api/ontologies/$versionId', data: {
      if (classes != null)
        'classes': classes.map((c) => c.toJson()).toList(),
      if (predicates != null)
        'predicates': predicates.map((p) => p.toJson()).toList(),
      if (description != null) 'description': description,
    });
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteDraft(String versionId) async {
    await _client.delete('/api/ontologies/$versionId');
  }

  Future<OntologyVersion> confirmVersion(String versionId) async {
    final res = await _client.post('/api/ontologies/$versionId/confirm');
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> archiveVersion(String versionId) async {
    final res = await _client.post('/api/ontologies/$versionId/archive');
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> generateFromSample(
    String sampleText, {
    String? baseVersionId,
  }) async {
    // AI 호출 — postAI() (120초 타임아웃)
    final res = await _client.postAI('/api/ontologies/generate', data: {
      'sample_text': sampleText,
      if (baseVersionId != null) 'base_version_id': baseVersionId,
    });
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  Future<OntologyVersion> mergeDrafts(
    List<String> versionIds,
    String newVersionId,
  ) async {
    // AI 호출 — postAI() (120초 타임아웃)
    final res = await _client.postAI('/api/ontologies/merge', data: {
      'version_ids': versionIds,
      'new_version_id': newVersionId,
    });
    return OntologyVersion.fromJson(res.data as Map<String, dynamic>);
  }

  /// 파일(txt/pdf/docx) → 텍스트 추출
  /// 반환: {"text": "...", "filename": "...", "chars": N}
  Future<Map<String, dynamic>> extractTextFromFile(
    String filePath,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
    });
    final res = await _client.postFormData(
        '/api/ontologies/extract-text', formData);
    return res.data as Map<String, dynamic>;
  }
}

