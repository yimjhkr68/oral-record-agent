// 파일 목적: suggestActions 도구 구현
// 분석된 구술 기록에 기반하여 후속 행동 제안
// 우선순위, 실행 가능성, 영향력 기반 제안

/// 제안된 행동
class ActionSuggestion {
  final String action;
  final String reason;
  final double priority; // 0.0-1.0
  final double feasibility; // 0.0-1.0
  final double impact; // 0.0-1.0
  final List<String> relatedKeywords;
  final Duration? estimatedTime;

  ActionSuggestion({
    required this.action,
    required this.reason,
    required this.priority,
    required this.feasibility,
    required this.impact,
    required this.relatedKeywords,
    this.estimatedTime,
  });

  /// 종합 점수 (우선순위 * 실행가능성 * 영향력)
  double get score => priority * feasibility * impact;
}

/// SuggestActions 도구
///
/// 책임:
/// 1. 추출된 메타데이터와 분석 결과 기반 행동 제안
/// 2. 우선순위화 (우선순위 * 실행가능성 * 영향력)
/// 3. 워크플로우 자동화 제안 (선택적)
///
/// 입력:
/// - metadata: extractMetadata 결과
/// - category: categorizeContent 결과
/// - summary: summarizeRecord 결과
/// - userContext: 사용자 정보 (선택)
///
/// 반환:
/// - List<ActionSuggestion> (우선순위 순)
///
/// 규칙 예:
/// - 날짜 언급 → 일정 등록 제안
/// - 인물명 언급 → 연락처 추가 제안
/// - 문제 키워드 → 해결 방안 제안
///
/// 예외처리:
/// - ValidationException: 분석 데이터 없음
abstract class SuggestActionsTool {
  /// 행동 제안
  ///
  /// 파라미터:
  /// - keywords: 추출된 키워드 리스트
  /// - category: 분류 결과
  /// - summary: 요약 텍스트
  /// - entities: 추출된 엔티티 (인물, 장소 등)
  ///
  /// 반환:
  /// - List<ActionSuggestion> (score 내림차순)
  static Future<List<ActionSuggestion>> execute({
    required List<String> keywords,
    String? category,
    String? summary,
    List<String>? entities,
  }) async {
    throw UnimplementedError(
      'suggestActions는 규칙 기반 행동 제안 필요\n'
      '입력: keywords, category, summary, entities\n'
      '반환: List<ActionSuggestion>(score 내림차순)',
    );
  }

  /// 간단한 규칙 기반 제안 (데모)
  static List<ActionSuggestion> suggestByRules({
    required List<String> keywords,
    String? category,
    List<String>? entities,
  }) {
    final suggestions = <ActionSuggestion>[];

    // 규칙 1: 날짜 키워드 → 일정 등록
    if (keywords
        .any((k) => k.contains('일정') || k.contains('회의') || k.contains('만남'))) {
      suggestions.add(ActionSuggestion(
        action: '일정 등록',
        reason: '면담 일정이 언급되었습니다.',
        priority: 0.9,
        feasibility: 0.95,
        impact: 0.8,
        relatedKeywords: ['일정', '회의'],
        estimatedTime: const Duration(minutes: 5),
      ));
    }

    // 규칙 2: 인물 엔티티 → 연락처 추가
    if (entities != null && entities.isNotEmpty) {
      suggestions.add(ActionSuggestion(
        action: '연락처 추가',
        reason: '${entities.length}명의 인물이 언급되었습니다.',
        priority: 0.7,
        feasibility: 0.8,
        impact: 0.6,
        relatedKeywords: entities.take(3).toList(),
        estimatedTime: const Duration(minutes: 10),
      ));
    }

    // 규칙 3: 카테고리별 제안
    if (category == '역사') {
      suggestions.add(ActionSuggestion(
        action: '역사 자료 아카이빙',
        reason: '역사 관련 기록으로 분류되었습니다.',
        priority: 0.6,
        feasibility: 0.7,
        impact: 0.85,
        relatedKeywords: ['역사', '아카이빙'],
        estimatedTime: const Duration(hours: 1),
      ));
    }

    // 규칙 4: 문제 키워드 → 해결 방안
    if (keywords
        .any((k) => k.contains('문제') || k.contains('이슈') || k.contains('해결'))) {
      suggestions.add(ActionSuggestion(
        action: '문제 해결 방안 수립',
        reason: '기록에서 문제 또는 이슈가 언급되었습니다.',
        priority: 0.85,
        feasibility: 0.6,
        impact: 0.9,
        relatedKeywords: ['문제', '해결'],
        estimatedTime: const Duration(hours: 2),
      ));
    }

    // 우선순위순 정렬
    suggestions.sort((a, b) => b.score.compareTo(a.score));

    return suggestions;
  }
}
