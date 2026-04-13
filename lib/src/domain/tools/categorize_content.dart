// 파일 목적: categorizeContent 도구 구현
// 구술 기록을 주제별로 자동 분류
// 다중 분류 지원 (기록이 여러 주제에 속할 수 있음)


/// 분류 결과
class CategoryResult {
  final String mainCategory;
  final String? subCategory;
  final double confidence;
  final List<String> alternativeCategories;

  CategoryResult({
    required this.mainCategory,
    this.subCategory,
    required this.confidence,
    required this.alternativeCategories,
  });
}

/// CategorizeContent 도구
///
/// 책임:
/// 1. 텍스트 기반 주제 분류 (다중 라벨)
/// 2. 신뢰도 점수 제공
/// 3. 대안 분류 제시
///
/// 분류 체계:
/// - mainCategory: "역사", "문화", "과학", "정치", "경제" 등 10-20개
/// - subCategory: mainCategory별 세분화 (선택)
/// - confidence: 0.0-1.0
///
/// 전략:
/// - 규칙 기반: 키워드 매칭 (빠름)
/// - ML 기반: 사전 학습된 분류기 (정확함)
/// - 하이브리드: 둘 다 (최고 성능)
///
/// 반환:
/// - List<CategoryResult> (다중 분류)
///
/// 예외처리:
/// - ValidationException: text 비어있음
/// - DatabaseException: 분류기 모델 로드 실패
abstract class CategorizeContentTool {
  /// 콘텐츠 분류
  ///
  /// 파라미터:
  /// - text: 분류할 텍스트
  /// - topN: 상위 N개 분류 결과 (기본: 1)
  /// - useML: ML 모델 사용 여부 (기본: true)
  /// - threshold: 신뢰도 임계값 (기본: 0.5)
  ///
  /// 반환:
  /// - List<CategoryResult>
  static Future<List<CategoryResult>> execute({
    required String text,
    int topN = 1,
    bool useML = true,
    double threshold = 0.5,
  }) async {
    throw UnimplementedError(
      'categorizeContent는 주제 분류 + ML 모델 필요\n'
      '분류: mainCategory + subCategory\n'
      '반환: List<CategoryResult>',
    );
  }

  /// 규칙 기반 분류 (간단 휴리스틱)
  static CategoryResult categorizeByRules(String text) {
    final lowerText = text.toLowerCase();
    final scoreMap = <String, double>{};

    // 키워드 매칭
    const keywords = {
      '역사': ['전쟁', '역사', '왕', '조선', '고구려', '백제'],
      '문화': ['문화', '예술', '전통', '민속', '비물질'],
      '과학': ['과학', '연구', '실험', '발견', '원리'],
      '정치': ['정치', '선거', '정부', '정책', '법'],
      '경제': ['경제', '사업', '돈', '금융', '투자'],
      '교육': ['교육', '학교', '학생', '공부', '선생'],
      '보건': ['건강', '의료', '병원', '보건', '질병'],
      '농업': ['농다', '농사', '농민', '식량', '수확'],
    };

    for (final entry in keywords.entries) {
      final category = entry.key;
      final words = entry.value;

      int matchCount = 0;
      for (final word in words) {
        if (lowerText.contains(word)) matchCount++;
      }

      scoreMap[category] = matchCount.toDouble();
    }

    // 점수 가장 높은 분류 선택
    final sorted = scoreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntry = sorted.first;
    final mainCategory = topEntry.key;
    final score = (topEntry.value / 10).clamp(0.0, 1.0);

    return CategoryResult(
      mainCategory: mainCategory,
      confidence: score,
      alternativeCategories: sorted.skip(1).take(2).map((e) => e.key).toList(),
    );
  }

  /// 미리 정의된 카테고리 목록
  static const List<String> predefinedCategories = [
    '역사',
    '문화',
    '과학',
    '정치',
    '경제',
    '교육',
    '보건',
    '농업',
    '기술',
    '환경',
  ];
}
