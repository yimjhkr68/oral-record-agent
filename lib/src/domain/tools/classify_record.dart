// 파일 목적: classifyRecord 도구 구현 (스펙)
// record.content를 분석하여 카테고리/태그 자동 지정
// Claude API를 활용한 NLP 분류


/// classifyRecord 도구
///
/// 책임:
/// 1. Record 조회
/// 2. 콘텐츠 분석 (Claude HTTP API 호출)
/// 3. 자동 분류 결과 (mainCategory 추천)
/// 4. 분류 저장
///
/// 분류 카테고리:
/// - 정치사건, 경제정책, 문화콘텐츠, 개인사, 기타
///
/// 네트워크 재시도:
/// - Claude API 호출 시 3회 재시도
///
/// 예외처리:
/// - ValidationException: recordId 비어있음
/// - DatabaseException: Record 미존재, 콘텐츠 비어있음
/// - NetworkException: Claude API 호출 실패 (3회 재시도)
abstract class ClassifyRecordTool {
  /// 기록 자동 분류
  ///
  /// 파라미터:
  /// - recordId: 분류할 기록 ID (필수)
  ///
  /// 반환:
  /// - {classification: String, confidence: double}
  ///
  /// 예외:
  /// - ValidationException: 입력 검증 실패
  /// - DatabaseException: Record 미존재
  /// - NetworkException: Claude API 호출 실패 (3회 재시도)
  static Future<Map<String, dynamic>> execute({
    required String recordId,
  }) async {
    throw UnimplementedError(
      'classifyRecord는 Claude API와 통합 필요\n'
      'Claude Prompt: 콘텐츠 분석 후 카테고리 추천\n'
      '반환: {classification: String, confidence: 0.0-1.0}',
    );
  }

  /// Claude를 통한 분류 요청
  static Future<String> callClaudeForClassification({
    required String content,
    int maxRetries = 3,
  }) async {
    throw UnimplementedError(
      'Claude API 통합 필요\n'
      'Prompt: 다음 콘텐츠를 분류하세요 (정치사건, 경제정책, 문화콘텐츠, 개인사, 기타)',
    );
  }
}
