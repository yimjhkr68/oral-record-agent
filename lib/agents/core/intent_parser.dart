// lib/agents/core/intent_parser.dart
// 사용자 자연어 입력 → AgentIntent 변환
//
// 두 가지 방식:
//   1. 규칙 기반 (빠름, 오프라인) — 키워드 패턴 매칭
//   2. Claude API 기반 (정확함, 온라인) — 애매한 입력 fallback

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_intent.dart';

/// ────────────────────────────────────────────────────────
/// IntentParser
///
/// 사용 예:
///   final parser = IntentParser(claudeApiKey: apiKey);
///   final intent = await parser.parse('interview.mp3 등록해줘');
///   // → AgentIntent(type: registerRecord, confidence: 95%, ...)
/// ────────────────────────────────────────────────────────
class IntentParser {
  final String? claudeApiKey;

  /// API 키 없이 규칙 기반만 사용하려면 null 전달
  IntentParser({this.claudeApiKey});

  // ─── 공개 API ────────────────────────────────────────

  /// 사용자 입력 → AgentIntent
  /// [context]: 추가 힌트 (예: {'currentScreen': 'recordList'})
  Future<AgentIntent> parse(
    String userInput, {
    Map<String, dynamic> context = const {},
  }) async {
    final trimmed = userInput.trim();

    // 빈 입력
    if (trimmed.isEmpty) {
      return AgentIntent(
        type: IntentType.unknown,
        rawInput: userInput,
        confidence: 0.0,
      );
    }

    // 1단계: 규칙 기반 시도
    final ruleResult = _parseByRules(trimmed, context);

    // 규칙 기반으로 충분히 확신 있으면 바로 반환
    if (ruleResult.confidence >= 0.6 && !_hasConflict(trimmed)) {
      return ruleResult;
    }

    // 2단계: Claude API fallback
    if (claudeApiKey != null && claudeApiKey!.isNotEmpty) {
      try {
        return await _parseByClaudeApi(trimmed, context);
      } catch (_) {
        // API 실패 시 규칙 기반 결과라도 반환
        return ruleResult;
      }
    }

    return ruleResult;
  }

  // ─── 규칙 기반 파싱 ───────────────────────────────────

  AgentIntent _parseByRules(String input, Map<String, dynamic> context) {
    final lower = input.toLowerCase();

    // 각 IntentType별 매칭 점수 계산
    final scores = <IntentType, int>{};
    for (final entry in _keywordMap.entries) {
      final count = entry.value.where((kw) => lower.contains(kw)).length;
      if (count > 0) scores[entry.key] = count;
    }

    // 파라미터 추출
    final params = _extractParams(input, lower);

    // 파일 경로 포함 시 registerRecord 힌트
    if (params.containsKey('filePath')) {
      scores[IntentType.registerRecord] =
          (scores[IntentType.registerRecord] ?? 0) + 1;
    }

    // 매칭 없음
    if (scores.isEmpty) {
      return AgentIntent(
        type: IntentType.unknown,
        rawInput: input,
        params: params,
        confidence: 0.0,
      );
    }

    // 최고 점수 IntentType 선택
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final matchCount = best.value;

    // confidence 계산
    double confidence = matchCount >= 2 ? 0.9 : 0.75;
    if (params.containsKey('filePath')) confidence = (confidence + 0.1).clamp(0.0, 1.0);

    return AgentIntent(
      type: best.key,
      rawInput: input,
      params: params,
      confidence: confidence,
    );
  }

  // ─── 키워드 맵 ────────────────────────────────────────

  static const Map<IntentType, List<String>> _keywordMap = {
    IntentType.registerRecord: [
      '등록', '추가', '올려', '저장해', '넣어', '업로드',
    ],
    IntentType.searchRecord: [
      '찾아', '검색', '조회', '보여줘', '있어', '어디',
    ],
    IntentType.generateContent: [
      '만들어', '생성해', '작성해', '보고서', '책', '정리해줘',
    ],
    IntentType.analyzeRecord: [
      '분석해', '분석', '어떤 내용', '요약해', '파악해',
    ],
    IntentType.managePersons: [
      '인물', '구술자', '면담자', '사람',
    ],
    IntentType.exportData: [
      '내보내', '추출해', 'csv', 'json', '다운로드',
    ],
    IntentType.writeCreative: [
      '소설', '단편소설', '창작', '스토리텔링', '에세이', '이야기로 써', '문학적으로',
    ],
    IntentType.writeAcademic: [
      '학술', '논문', '학술논문', '연구보고서', '아카데믹', '학술지', '연구 논문',
    ],
    IntentType.writePopular: [
      '교양', '대중서', '평전', '전기', '일반 독자', '교양서', '대중적으로',
    ],
  };

  // ─── 충돌 감지 ────────────────────────────────────────

  /// 여러 IntentType에 동시에 매칭되면 충돌로 판단
  bool _hasConflict(String input) {
    final lower = input.toLowerCase();
    int matchedTypes = 0;
    for (final keywords in _keywordMap.values) {
      if (keywords.any((kw) => lower.contains(kw))) matchedTypes++;
    }
    return matchedTypes >= 3;
  }

  // ─── 파라미터 추출 ────────────────────────────────────

  Map<String, dynamic> _extractParams(String input, String lower) {
    final params = <String, dynamic>{};

    // 파일 경로 감지
    final filePath = _extractFilePath(input);
    if (filePath != null) params['filePath'] = filePath;

    // 분석 요구사항(방법론/관점 키워드) 감지
    final requirements = _extractRequirements(input);
    if (requirements != null) params['requirements'] = requirements;

    // 인물 이름 감지 (한국어 2~4글자 + 호칭)
    final personName = _extractPersonName(input);
    if (personName != null) params['narratorName'] = personName;

    // 날짜/기간 감지
    final period = _extractPeriod(input);
    if (period != null) params['period'] = period;

    // 포맷 감지
    final format = _extractFormat(lower);
    if (format != null) params['format'] = format;

    // 검색 쿼리: 인물명 있으면 쿼리에도 포함
    if (personName != null) params['query'] = personName;

    // 문서 유형 감지 (generateContent 인텐트용)
    params['docType'] = _extractDocType(lower);

    // 출력 모드 감지 (writeCreative/writeAcademic/writePopular 인텐트용)
    final outputType = _extractOutputType(lower);
    if (outputType != null) params['outputType'] = outputType;

    return params;
  }

  /// 파일 경로 패턴 감지
  String? _extractFilePath(String input) {
    // Windows 경로: C:\, D:\, E:\ 등 (공백 포함 경로 지원)
    // 파일 확장자로 경로 끝을 판별하여 공백이 있는 경로도 올바르게 추출
    const exts = r'mp3|mp4|wav|m4a|webm|mov|pdf|docx|txt|md|csv|jpg|jpeg|png|bmp|tiff|tif|webp';
    final winPathWithExt = RegExp(
      r'[A-Za-z]:\\[^\n"]*?\.(' + exts + r')(?=\s|$)',
      caseSensitive: false,
    );
    final winMatchWithExt = winPathWithExt.firstMatch(input);
    if (winMatchWithExt != null) return winMatchWithExt.group(0);

    // 확장자 없는 경로 폴백: 공백 전까지
    final winPath = RegExp(r'[A-Za-z]:\\[^\s]+');
    final winMatch = winPath.firstMatch(input);
    if (winMatch != null) return winMatch.group(0);

    // Unix/업로드 경로: /uploads/, /path/ 등
    final unixPath = RegExp(r'/\S+\.\w{2,5}');
    final unixMatch = unixPath.firstMatch(input);
    if (unixMatch != null) return unixMatch.group(0);

    // 확장자만 있는 파일명: 파일명.mp3 등
    final extPattern = RegExp(
      r'\S+\.(mp3|mp4|wav|m4a|webm|mov|pdf|docx|txt|md|csv|jpg|jpeg|png|bmp|tiff|tif|webp)',
      caseSensitive: false,
    );
    final extMatch = extPattern.firstMatch(input);
    if (extMatch != null) return extMatch.group(0);

    return null;
  }

  /// 한국어 인물 이름 감지 (2~4글자 + 선생님/씨/님 패턴)
  String? _extractPersonName(String input) {
    final pattern = RegExp(r'([가-힣]{2,4})\s*(선생님|씨|님|교수|박사)');
    final match = pattern.firstMatch(input);
    return match?.group(1);
  }

  /// 날짜/기간 감지
  String? _extractPeriod(String input) {
    // "3월", "12월" 등
    final monthPattern = RegExp(r'(\d{1,2})월');
    final monthMatch = monthPattern.firstMatch(input);
    if (monthMatch != null) return '${monthMatch.group(1)}월';

    // "2024년" 등
    final yearPattern = RegExp(r'(\d{4})년');
    final yearMatch = yearPattern.firstMatch(input);
    if (yearMatch != null) return '${yearMatch.group(1)}년';

    // 상대적 기간
    if (input.contains('지난달')) return '지난달';
    if (input.contains('이번달') || input.contains('이번 달')) return '이번달';
    if (input.contains('지난주')) return '지난주';
    if (input.contains('올해')) return '올해';

    return null;
  }

  /// 내보내기 포맷 감지
  String? _extractFormat(String lower) {
    if (lower.contains('csv')) return 'csv';
    if (lower.contains('json')) return 'json';
    if (lower.contains('docx') || lower.contains('word')) return 'docx';
    if (lower.contains('pdf')) return 'pdf';
    if (lower.contains('txt') || lower.contains('텍스트')) return 'txt';
    return null;
  }

  /// 출력 모드 감지 (writeCreative/writeAcademic/writePopular 인텐트용)
  /// 반환값: 'creative' | 'academic' | 'popular' | null
  String? _extractOutputType(String lower) {
    if (lower.contains('소설') ||
        lower.contains('단편소설') ||
        lower.contains('창작') ||
        lower.contains('스토리텔링') ||
        lower.contains('에세이') ||
        lower.contains('문학적')) {
      return 'creative';
    }
    if (lower.contains('학술') ||
        lower.contains('논문') ||
        lower.contains('아카데믹') ||
        lower.contains('연구 논문')) {
      return 'academic';
    }
    if (lower.contains('교양') ||
        lower.contains('대중서') ||
        lower.contains('평전') ||
        lower.contains('전기') ||
        lower.contains('교양서') ||
        lower.contains('대중적')) {
      return 'popular';
    }
    return null;
  }

  /// 문서 생성 유형 감지 (generateContent 인텐트용)
  /// 기본값: 'report'
  String _extractDocType(String lower) {
    if (lower.contains('책') ||
        lower.contains('생애사') ||
        lower.contains('생애')) {
      return 'book';
    }
    if (lower.contains('요약') ||
        lower.contains('정리') ||
        lower.contains('요약집')) {
      return 'summary';
    }
    return 'report'; // 보고서가 기본값
  }

  /// 분석 방법론·관점 요구사항 감지
  /// 예: "비교문화적 관점으로", "생애사적 접근", "여성주의적 시각"
  String? _extractRequirements(String input) {
    final patterns = [
      // ~적 관점/시각/접근/분석
      RegExp(r'[가-힣A-Za-z]+적\s*(?:관점|시각|접근|분석|방식|입장)'),
      // ~(으로/로) 분석/작성/정리
      RegExp(r'[가-힣A-Za-z\s]{2,10}(?:으로|로)\s*(?:분석|작성|정리|서술)'),
      // ~중심/기반/위주
      RegExp(r'[가-힣A-Za-z]+\s*(?:중심|기반|위주)(?:으로|로)?'),
    ];
    final found = <String>[];
    for (final p in patterns) {
      for (final m in p.allMatches(input)) {
        final g = m.group(0)?.trim();
        if (g != null && g.length >= 4 && !found.contains(g)) {
          found.add(g);
        }
      }
    }
    return found.isEmpty ? null : found.join(', ');
  }

  // ─── Claude API fallback ──────────────────────────────

  Future<AgentIntent> _parseByClaudeApi(
    String input,
    Map<String, dynamic> context,
  ) async {
    const endpoint = 'https://api.anthropic.com/v1/messages';

    const systemPrompt = '''
당신은 구술기록관리 시스템의 의도 분류기입니다.
사용자의 한국어 입력을 분석하여 의도를 JSON으로 반환하세요.

IntentType 목록:
- registerRecord: 파일 등록, 추가, 업로드
- searchRecord: 기록 검색, 조회
- generateContent: 보고서/책/문서 생성 (일반)
- analyzeRecord: 기록 분석, 요약
- managePersons: 인물사전 관리
- exportData: CSV/JSON 내보내기
- writeCreative: 소설/에세이/창작 글쓰기
- writeAcademic: 학술 논문/연구보고서 작성
- writePopular: 교양서/평전/대중서 작성
- unknown: 분류 불가

outputType 값 (writeCreative/writeAcademic/writePopular일 때):
- creative: 소설, 단편소설, 에세이, 창작
- academic: 학술논문, 연구보고서, 논문
- popular: 교양서, 평전, 전기, 대중서

반드시 아래 JSON만 반환하세요 (설명 없이):
{
  "intentType": "...",
  "confidence": 0.0~1.0,
  "params": {
    "filePath": "파일 경로 (있을 때만)",
    "narratorName": "인물 이름 (있을 때만)",
    "period": "기간 (있을 때만)",
    "format": "포맷 (있을 때만)",
    "query": "검색어 (있을 때만)",
    "outputType": "creative|academic|popular (있을 때만)"
  }
}''';

    final response = await http
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': claudeApiKey!,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': 'claude-haiku-4-5-20251001',
            'max_tokens': 256,
            'system': systemPrompt,
            'messages': [
              {'role': 'user', 'content': '사용자 입력: "$input"'},
            ],
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Claude API 오류: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final text = (body['content'] as List).first['text'] as String;

    // JSON 파싱
    final jsonStr = _extractJson(text);
    final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

    final intentTypeStr = parsed['intentType'] as String? ?? 'unknown';
    final confidence = (parsed['confidence'] as num?)?.toDouble() ?? 0.5;
    final rawParams = parsed['params'] as Map<String, dynamic>? ?? {};

    // null 값 제거
    final params = Map<String, dynamic>.fromEntries(
      rawParams.entries.where((e) => e.value != null),
    );

    return AgentIntent(
      type: _parseIntentType(intentTypeStr),
      rawInput: input,
      params: params,
      confidence: confidence,
    );
  }

  /// 응답 텍스트에서 JSON 블록 추출
  String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1) throw FormatException('JSON 없음: $text');
    return text.substring(start, end + 1);
  }

  IntentType _parseIntentType(String s) {
    switch (s) {
      case 'registerRecord':   return IntentType.registerRecord;
      case 'searchRecord':     return IntentType.searchRecord;
      case 'generateContent':  return IntentType.generateContent;
      case 'analyzeRecord':    return IntentType.analyzeRecord;
      case 'managePersons':    return IntentType.managePersons;
      case 'exportData':       return IntentType.exportData;
      case 'writeCreative':    return IntentType.writeCreative;
      case 'writeAcademic':    return IntentType.writeAcademic;
      case 'writePopular':     return IntentType.writePopular;
      default:                 return IntentType.unknown;
    }
  }
}
