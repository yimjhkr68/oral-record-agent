// lib/agents/tools/smart_search_tool.dart
// 의미 기반 스마트 검색 툴 — Claude API 관련도 점수 계산

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../src/data/models/search_filters.dart';
import '../../src/data/models/narrator.dart';
import 'tool_interface.dart';
import 'tool_services.dart';

class SmartSearchTool extends AgentTool {
  final ToolServices? _services;
  SmartSearchTool([this._services]);

  @override
  String get name => 'smart_search';

  @override
  String get description =>
      '사용자 프롬프트의 의미를 분석하여 관련 구술 기록을 검색합니다. '
      'Claude API를 활용한 의미 기반 관련도 점수로 순위를 매깁니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'query',
          type: 'string',
          description: '검색 쿼리 (사용자 입력 전체)',
          required: true,
        ),
        const ToolParam(
          name: 'maxResults',
          type: 'number',
          description: '최대 결과 수',
          defaultValue: 10,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final query = input['query'] as String? ?? '';
    final maxResults = (input['maxResults'] as num?)?.toInt() ?? 10;

    final repo = _services?.recordRepo;
    if (repo == null) {
      // 스텁 모드
      return ToolResult(success: true, output: {
        'records': <Map<String, dynamic>>[],
        'totalFound': 0,
        'hasResults': false,
        'searchStrategy': '스텁 모드',
      });
    }

    // 1. 전체 기록 조회
    final allRecords = await repo.searchRecords(SearchFilters(limit: 9999));
    if (allRecords.isEmpty) {
      return ToolResult(success: true, output: {
        'records': <Map<String, dynamic>>[],
        'totalFound': 0,
        'hasResults': false,
        'searchStrategy': '기록 없음',
      });
    }

    // 2. 구술자 이름 조회 (ID → 이름 맵)
    final narratorMap = <String, String>{};
    try {
      final narrators = await (_services?.narratorRepo?.getAllNarrators() ??
          Future.value(<Narrator>[]));
      for (final n in narrators) {
        narratorMap[n.id] = n.name;
      }
    } catch (_) {}

    // 3. 검색 대상 요약 목록 구성 (Claude 입력용, 레코드당 최대 200자)
    final recordBriefs = allRecords.map((r) {
      final summarySnip = (r.summary ?? r.content).length > 200
          ? (r.summary ?? r.content).substring(0, 200)
          : (r.summary ?? r.content);
      return {
        'id': r.id,
        'title': r.title,
        'narratorName': narratorMap[r.narratorId] ?? '',
        'tags': r.tags.join(', '),
        'summary': summarySnip,
      };
    }).toList();

    // 4. 관련도 점수 계산
    final apiKey = _services?.claudeApiKey;
    List<Map<String, dynamic>> scored;
    String strategy;

    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        scored = await _semanticScore(query, recordBriefs, apiKey);
        strategy = 'AI 의미 검색';
      } catch (_) {
        scored = _keywordScore(query, recordBriefs);
        strategy = '키워드 검색 (AI 실패)';
      }
    } else {
      scored = _keywordScore(query, recordBriefs);
      strategy = '키워드 검색';
    }

    // 5. 필터 (관련도 0.3 이상) → 정렬 → 상위 N개
    scored.sort((a, b) =>
        (b['relevanceScore'] as double).compareTo(a['relevanceScore'] as double));

    final filtered = scored
        .where((r) => (r['relevanceScore'] as double) >= 0.3)
        .take(maxResults)
        .toList();

    // 6. 전체 레코드 데이터로 보강
    final enriched = filtered.map((r) {
      final rid = r['recordId'] as String;
      final record = allRecords.firstWhere((rec) => rec.id == rid,
          orElse: () => allRecords.first);
      final preview = (record.summary ?? record.content);
      final previewSnip =
          preview.length > 100 ? preview.substring(0, 100) : preview;
      return {
        'recordId': rid,
        'title': record.title,
        'narratorName': narratorMap[record.narratorId] ?? '',
        'date': record.createdAt.toIso8601String(),
        'summaryPreview': previewSnip,
        'relevanceScore': r['relevanceScore'],
      };
    }).toList();

    return ToolResult(success: true, output: {
      'records': enriched,
      'totalFound': enriched.length,
      'hasResults': enriched.isNotEmpty,
      'searchStrategy': strategy,
    });
  }

  // ── Claude API 관련도 점수 ─────────────────────────────

  Future<List<Map<String, dynamic>>> _semanticScore(
    String query,
    List<Map<String, dynamic>> records,
    String apiKey,
  ) async {
    // 기록 수가 많으면 배치 처리 (Claude 컨텍스트 제한)
    final batch = records.take(30).toList();

    final recordsJson = jsonEncode(batch);

    final systemPrompt =
        '당신은 구술기록 검색 전문가입니다. '
        '사용자 쿼리와 각 기록의 관련도를 0.0~1.0으로 평가하세요. '
        'JSON 배열로만 응답하세요 (설명 없이):\n'
        '[{"recordId": "id", "relevanceScore": 0.8}, ...]';

    final userContent =
        '쿼리: "$query"\n\n기록 목록:\n$recordsJson';

    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 1024,
            'system': systemPrompt,
            'messages': [
              {'role': 'user', 'content': userContent},
            ],
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Claude API ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (body['content'] as List).first['text'] as String;

    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start == -1 || end == -1) throw Exception('JSON 파싱 실패');

    final list = jsonDecode(text.substring(start, end + 1)) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // ── 키워드 기반 폴백 점수 ─────────────────────────────

  List<Map<String, dynamic>> _keywordScore(
    String query,
    List<Map<String, dynamic>> records,
  ) {
    final keywords = query
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 2)
        .map((w) => w.toLowerCase())
        .toList();

    return records.map((r) {
      final searchTarget =
          '${r['title']} ${r['summary']} ${r['tags']} ${r['narratorName']}'
              .toLowerCase();
      int hits = 0;
      for (final kw in keywords) {
        if (searchTarget.contains(kw)) hits++;
      }
      final score =
          keywords.isEmpty ? 0.0 : (hits / keywords.length).clamp(0.0, 1.0);
      return {
        'recordId': r['id'],
        'relevanceScore': score * 0.9, // 키워드 검색은 최대 0.9
      };
    }).toList();
  }
}
