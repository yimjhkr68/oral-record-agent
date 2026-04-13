// 파일 목적: extractMetadata 도구 구현
// 구술 콘텐츠에서 메타데이터 자동 추출
// 주제, 키워드, 인물, 장소, 날짜 등


/// 추출된 메타데이터
class ExtractedMetadata {
  final String? mainCategory;
  final String? subCategory;
  final List<String> keywords;
  final List<String> entities; // 인물명, 장소명
  final List<String> dates;
  final double confidence;

  ExtractedMetadata({
    this.mainCategory,
    this.subCategory,
    required this.keywords,
    required this.entities,
    required this.dates,
    this.confidence = 0.8,
  });
}

/// ExtractMetadata 도구
///
/// 책임:
/// 1. 텍스트에서 자동으로 메타데이터 추출
/// 2. 키워드, 엔티티(인물, 장소), 날짜 인식
/// 3. 주제 분류 (ML 또는 규칙 기반)
///
/// 추출 항목:
/// - keywords: TF-IDF 또는 BERT 기반 (상위 10개)
/// - entities: NER(Named Entity Recognition) 기반
/// - dates: 정규식 + 파싱 (YYYY-MM-DD, "지난 월요일" 등)
/// - mainCategory: 사전 학습된 분류기 또는 규칙
/// - subCategory: mainCategory에 따른 세부 분류
///
/// 반환:
/// - ExtractedMetadata (keywords, entities, dates, mainCategory, confidence)
///
/// 예외처리:
/// - ValidationException: content 비어있음
/// - DatabaseException: 분류 모델 로드 실패
abstract class ExtractMetadataTool {
  /// 메타데이터 추출
  ///
  /// 파라미터:
  /// - content: 분석할 콘텐츠
  /// - useML: ML 모델 사용 여부 (기본: true, 선택적)
  ///
  /// 반환:
  /// - ExtractedMetadata
  static Future<ExtractedMetadata> execute({
    required String content,
    bool useML = true,
  }) async {
    throw UnimplementedError(
      'extractMetadata는 키워드 추출 + 엔티티 인식 + 날짜 파싱 필요\n'
      '추출: keywords(상위10), entities(NER), dates, mainCategory\n'
      '반환: ExtractedMetadata',
    );
  }

  /// 간단한 키워드 추출 (정규식 기반)
  static List<String> extractKeywords(String content, {int topN = 10}) {
    // NOTE: 단순 구현 - 실제로는 TF-IDF나 BERT 사용
    final words = content.split(RegExp(r'\s+|[,.\-!?;:]'));
    final wordFreq = <String, int>{};

    for (final word in words) {
      if (word.length > 3) {
        // 3글자 이상만
        final lower = word.toLowerCase();
        wordFreq[lower] = (wordFreq[lower] ?? 0) + 1;
      }
    }

    final sorted = wordFreq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(topN).map((e) => e.key).toList();
  }

  /// 날짜 추출
  static List<String> extractDates(String content) {
    final dates = <String>[];

    // YYYY-MM-DD 형식
    final isoDateRegex = RegExp(r'\d{4}-\d{2}-\d{2}');
    dates.addAll(
        isoDateRegex.allMatches(content).map((m) => m.group(0)!).toList());

    // YYYY년 MM월 DD일 형식
    final koreanDateRegex = RegExp(r'\d{4}년\s*\d{1,2}월\s*\d{1,2}일');
    dates.addAll(
        koreanDateRegex.allMatches(content).map((m) => m.group(0)!).toList());

    return dates.toSet().toList();
  }

  /// 엔티티 추출 (간단한 규칙 기반)
  static List<String> extractEntities(String content) {
    final entities = <String>[];

    // 대문자로 시작하는 단어들 (인물, 장소 가능성)
    final capitalizedRegex = RegExp(r'\b[A-Z][a-z]+');
    entities.addAll(
        capitalizedRegex.allMatches(content).map((m) => m.group(0)!).toList());

    return entities.toSet().toList();
  }
}
