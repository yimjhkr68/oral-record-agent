// lib/agents/core/prompt_enhancer.dart
// Claude API를 이용해 사용자 프롬프트를 개선하는 클래스

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_intent.dart';

class EnhancedPrompt {
  final String original;
  final String enhanced;
  final String reason;
  final bool isImproved;

  const EnhancedPrompt({
    required this.original,
    required this.enhanced,
    required this.reason,
    required this.isImproved,
  });
}

/// 프롬프트 개선 대상 인텐트 및 키워드
const _kEnhanceKeywords = [
  '만들어', '생성해', '작성해', '보고서', '책', '정리해줘',
  '분석해', '분석', '요약해', '파악해',
  '소설', '에세이', '창작', '학술', '논문', '교양', '평전', '전기',
];

class PromptEnhancer {
  final String? apiKey;

  const PromptEnhancer({this.apiKey});

  /// 현재 입력이 프롬프트 개선 대상인지 판단
  static bool shouldEnhance(String input) {
    final lower = input.toLowerCase();
    return _kEnhanceKeywords.any((kw) => lower.contains(kw));
  }

  /// 인텐트 타입별 시스템 프롬프트 반환
  static String _buildEnhanceSystemPrompt(IntentType intentType) {
    const base =
        '사용자의 짧고 모호한 지시를 더 명확하고 구체적인 지시로 개선하세요. '
        '구술기록 도메인 용어(구술자, 면담, 기록, 전사, 요약)를 적절히 활용하세요. '
        '중요: 사용자가 명시한 분석 방법론(비교문화적 관점, 생애사적 접근, 여성주의적 시각 등) '
        '키워드는 반드시 개선된 프롬프트에 원문 그대로 보존해야 합니다. '
        '이미 충분히 구체적이면 isImproved: false로 반환하세요. '
        '반드시 아래 JSON만 반환하세요 (설명 없이):\n'
        '{"enhanced": "개선된 프롬프트", "reason": "개선 이유 한 줄", "isImproved": true}';

    switch (intentType) {
      case IntentType.writeCreative:
        return '당신은 구술기록 기반 창작 글쓰기 전문가입니다. '
            '구술 기록을 소설·에세이·단편 이야기 등 문학적 형식으로 변환하는 요청을 구체화하세요. '
            '장르(소설/에세이/단편), 시점(1인칭/3인칭), 톤(서정적/사실적), 분량 등을 명시합니다. $base';
      case IntentType.writeAcademic:
        return '당신은 구술사·사회과학 학술 논문 작성 전문가입니다. '
            '구술 기록을 학술 논문으로 변환하는 요청을 구체화하세요. '
            '연구 방법론(구술사/생애사/질적연구), 인용 형식, 이론적 틀, 학술지 투고 수준을 명시합니다. $base';
      case IntentType.writePopular:
        return '당신은 교양서·평전·전기 작가입니다. '
            '구술 기록을 일반 독자를 위한 교양서 형식으로 변환하는 요청을 구체화하세요. '
            '대상 독자, 서술 방식(평전/인물이야기/구술모음집), 분량 등을 명시합니다. $base';
      default:
        return '당신은 구술기록관리 에이전트의 프롬프트 개선 도우미입니다. $base';
    }
  }

  /// 프롬프트 개선 시도.
  /// [intentType]: 감지된 의도 타입 (인텐트별 특화 프롬프트 적용)
  /// API 키 없거나 실패 시 원본 반환 (isImproved = false).
  Future<EnhancedPrompt> enhance(
    String userPrompt, {
    IntentType intentType = IntentType.generateContent,
  }) async {
    if (apiKey == null || apiKey!.isEmpty) {
      return EnhancedPrompt(
        original: userPrompt,
        enhanced: userPrompt,
        reason: '',
        isImproved: false,
      );
    }

    try {
      const endpoint = 'https://api.anthropic.com/v1/messages';
      final systemPrompt = _buildEnhanceSystemPrompt(intentType);

      final resp = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey!,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5-20251001',
              'max_tokens': 500,
              'system': systemPrompt,
              'messages': [
                {'role': 'user', 'content': '사용자 입력: "$userPrompt"'},
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        return _fallback(userPrompt);
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final rawText =
          (body['content'] as List).first['text'] as String;

      // JSON 추출 (```json ... ``` 래핑 제거)
      final jsonStr = _extractJson(rawText);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      final enhanced = parsed['enhanced'] as String? ?? userPrompt;
      final reason = parsed['reason'] as String? ?? '';
      final isImproved = parsed['isImproved'] as bool? ?? false;

      if (!isImproved || enhanced.trim() == userPrompt.trim()) {
        return EnhancedPrompt(
          original: userPrompt,
          enhanced: userPrompt,
          reason: '',
          isImproved: false,
        );
      }

      return EnhancedPrompt(
        original: userPrompt,
        enhanced: enhanced,
        reason: reason,
        isImproved: true,
      );
    } catch (_) {
      return _fallback(userPrompt);
    }
  }

  static EnhancedPrompt _fallback(String input) => EnhancedPrompt(
        original: input,
        enhanced: input,
        reason: '',
        isImproved: false,
      );

  static String _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return text.substring(start, end + 1);
    return text;
  }
}
