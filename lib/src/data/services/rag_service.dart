// lib/src/data/services/rag_service.dart
// RAG FastAPI 서버와 통신하는 서비스
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/record.dart';
import '../models/narrator.dart';

class RagSource {
  final String displayId;
  final String recordId;
  final String title;
  final String narratorName;
  final String mainCategory;
  final List<String> keywordTags;
  final double score;
  final String text;

  const RagSource({
    required this.displayId,
    required this.recordId,
    required this.title,
    required this.narratorName,
    required this.mainCategory,
    required this.keywordTags,
    required this.score,
    required this.text,
  });

  factory RagSource.fromJson(Map<String, dynamic> j) => RagSource(
        displayId: j['display_id'] as String? ?? '',
        recordId: j['record_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        narratorName: j['narrator_name'] as String? ?? '',
        mainCategory: j['main_category'] as String? ?? '',
        keywordTags:
            (j['keyword_tags'] as List<dynamic>?)?.cast<String>() ?? [],
        score: (j['score'] as num?)?.toDouble() ?? 0.0,
        text: j['text'] as String? ?? '',
      );
}

class RagResult {
  final String answer;
  final List<RagSource> sources;
  final String query;

  const RagResult({
    required this.answer,
    required this.sources,
    required this.query,
  });

  factory RagResult.fromJson(Map<String, dynamic> j) => RagResult(
        answer: j['answer'] as String? ?? '',
        sources: (j['sources'] as List<dynamic>?)
                ?.map((s) => RagSource.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        query: j['query'] as String? ?? '',
      );
}

class RagService {
  final String baseUrl;

  const RagService({this.baseUrl = 'http://127.0.0.1:9000'});

  // ── RAG 질의 ───────────────────────────────────────────────

  Future<RagResult> query(String q, {int topK = 5}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/query/'),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({'query': q, 'top_k': topK}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('RAG 서버 오류 (${response.statusCode})');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return RagResult.fromJson(data);
  }

  // ── 기록 단건 수집 (저장 시 자동 호출) ────────────────────

  Future<bool> ingestRecord(
    Record record, {
    Narrator? narrator,
  }) async {
    try {
      final body = {
        'id':           record.id,
        'title':        record.title,
        'content':      record.content,
        'summary':      record.summary,
        'inputType':    record.inputType,
        'narratorId':   record.narratorId,
        'narratorName': narrator?.name ?? '',
        'mainCategory': record.mainCategory,
        'keywordTags':  record.keywordTags,
        'displayId':    record.displayId,
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/ingest/record'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (_) {
      // RAG 서버 오류는 조용히 실패 (앱 동작에 영향 없음)
      return false;
    }
  }

  // ── 기록 삭제 시 Qdrant에서도 제거 ───────────────────────

  Future<bool> deleteRecord(String recordId) async {
    try {
      final response = await http
          .delete(Uri.parse('$baseUrl/ingest/record/$recordId'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── 서버 상태 확인 ────────────────────────────────────────

  Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
