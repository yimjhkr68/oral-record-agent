// 파일 목적: summarizeRecord 도구 구현
// 구술 기록을 요약 (자동 생성)
// 원본 길이의 30-50% 수준으로 핵심 내용 추출

/// 요약 결과
class SummaryResult {
  final String originalText;
  final String summary;
  final List<String> keyPoints;
  final int originalLength;
  final int summaryLength;
  final double compressionRatio;

  SummaryResult({
    required this.originalText,
    required this.summary,
    required this.keyPoints,
    required this.compressionRatio,
  })  : originalLength = originalText.length,
        summaryLength = summary.length;

  /// 요약률 (0.0-1.0)
  double get summaryRatio => summaryLength / originalLength;
}

/// SummarizeRecord 도구
///
/// 책임:
/// 1. 텍스트의 핵심 문장 선택 (추출형 요약)
/// 2. Claude를 통한 추상형 요약 (선택적)
/// 3. 키포인트 추출
///
/// 전략:
/// - extractive: 원본 문장 선택 (빠름, 충실도 높음)
/// - abstractive: 새로운 문장 생성 (Claude, 세련됨)
/// - hybrid: 둘 다 적용 (최고 품질)
///
/// 반환:
/// - SummaryResult (summary, keyPoints, compressionRatio)
///
/// 예외처리:
/// - ValidationException: text 비어있음, compressionRatio 유효성
/// - NetworkException: Claude API 호출 실패
abstract class SummarizeRecordTool {
  /// 기록 요약
  ///
  /// 파라미터:
  /// - text: 원본 콘텐츠
  /// - ratio: 요약 비율 (0.0-1.0, 기본: 0.4 = 40%)
  /// - strategy: "extractive"(기본), "abstractive", "hybrid"
  /// - useClaude: Claude 사용 여부 (abstractive/hybrid에서)
  ///
  /// 반환:
  /// - SummaryResult
  static Future<SummaryResult> execute({
    required String text,
    double ratio = 0.4,
    String strategy = 'extractive',
    bool useClaude = true,
  }) async {
    throw UnimplementedError(
      'summarizeRecord는 추출형/추상형 요약 필요\n'
      '전략: extractive, abstractive, hybrid\n'
      '반환: SummaryResult(summary, keyPoints, compressionRatio)',
    );
  }

  /// 추출형 요약 (문장 선택)
  static SummaryResult summarizeExtractive(
    String text, {
    double ratio = 0.4,
  }) {
    final sentences = text.split(RegExp(r'[.!?]+'));
    final sentenceCount = sentences.length;
    final summaryCount = (sentenceCount * ratio).ceil();

    // 간단한 휴리스틱: 긴 문장 + 키워드 포함 문장 선택
    final scoredSentences = sentences
        .asMap()
        .entries
        .map((e) {
          final idx = e.key;
          final sent = e.value.trim();
          if (sent.isEmpty) return (sent, 0.0);

          // 점수 계산
          double score = sent.length.toDouble() / 100; // 길이
          if (sent.contains('중요') || sent.contains('핵심')) score += 2.0;
          if (idx == 0 || idx == sentenceCount - 1) score += 1.0; // 첫/마지막

          return (sent, score);
        })
        .where((e) => e.$1.isNotEmpty)
        .toList();

    scoredSentences.sort((a, b) => b.$2.compareTo(a.$2));

    final summary =
        '${scoredSentences.take(summaryCount).map((e) => e.$1).join('. ')}.';

    return SummaryResult(
      originalText: text,
      summary: summary,
      keyPoints: summary.split('.').where((s) => s.trim().isNotEmpty).toList(),
      compressionRatio: ratio,
    );
  }

  /// 추상형 요약 (Claude 사용)
  static Future<SummaryResult> summarizeAbstractive({
    required String text,
    double ratio = 0.4,
  }) async {
    // NOTE: Claude API 통합 필요
    throw UnimplementedError(
      'Claude 기반 추상형 요약 필요\n'
      'Prompt: 다음 텍스트를 40% 수준으로 요약하세요',
    );
  }

  /// 키포인트 추출
  static List<String> extractKeyPoints(String text, {int maxPoints = 5}) {
    final sentences = text.split(RegExp(r'[.!?]+'));

    final keyPoints = sentences
        .where((s) => s.contains('중요') || s.contains('핵심') || s.length > 50)
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .take(maxPoints)
        .toList();

    return keyPoints.isEmpty
        ? sentences
            .where((s) => s.trim().isNotEmpty)
            .take(maxPoints)
            .map((s) => s.trim())
            .toList()
        : keyPoints;
  }
}
