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

/// v3.0 Hive 서버 쿼리 결과 (AI 답변 + 소스 목록)
class HiveQueryResult {
  final String answer;
  final List<HiveRecord> sources;

  const HiveQueryResult({required this.answer, required this.sources});
}

/// v3.0 Hive 서버 클라이언트 (별도 baseUrl)
class HiveApi {
  final Dio _dio;

  HiveApi(String baseUrl)
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 60), // v3.0 AI 응답 포함
          headers: {'Content-Type': 'application/json'},
        ));

  /// v3.0 POST /query/ → AI 답변 + 소스 목록
  Future<HiveQueryResult> query(String queryText, {int topK = 5}) async {
    final res = await _dio.post('/query/', data: {'query': queryText, 'top_k': topK});
    final sources = (res.data['sources'] as List? ?? [])
        .map((s) => HiveRecord.fromJson(s as Map<String, dynamic>))
        .toList();
    return HiveQueryResult(
      answer: res.data['answer'] as String? ?? '',
      sources: sources,
    );
  }

  Future<bool> checkConnection() async {
    try {
      await _dio.get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }
}

class HiveRecord {
  final String displayId;
  final String title;
  final String narratorName;
  final String mainCategory;
  final String text;
  final double score;

  const HiveRecord({
    required this.displayId,
    required this.title,
    required this.narratorName,
    required this.mainCategory,
    required this.text,
    required this.score,
  });

  factory HiveRecord.fromJson(Map<String, dynamic> json) => HiveRecord(
        displayId: json['display_id'] ?? '',
        title: json['title'] ?? '',
        narratorName: json['narrator_name'] ?? '',
        mainCategory: json['main_category'] ?? '',
        text: json['text'] ?? '',
        score: (json['score'] ?? 0.0).toDouble(),
      );
}
