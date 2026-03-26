// 파일 목적: detectPII 도구 구현 (스펙)
// 기록 콘텐츠에서 개인식별정보(PII) 탐지
// 정규식 (패턴 매칭) + Claude (의미론적 분석) 혼합

import 'package:oral_record_agent/src/data/models/pii_item.dart';

/// detectPII 도구
///
/// 책임:
/// 1. 정규식 기반 PII 탐지 (이메일, 전화, SSN, 신용카드)
/// 2. Claude 기반 의미론적 분석 (열가지 이상의 PII 유형)
/// 3. PIIItem 리스트 생성 (타입, 값, 위치)
/// 4. 스코어링 및 신뢰도 평가
///
/// 탐지 유형 (정규식):
/// - email: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$
/// - phone: 010-\\d{4}-\\d{4}, 02-\\d{3,4}-\\d{4} 등
/// - ssn: \\d{6}-[1-4]\\d{6}
/// - credit_card: \\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}
///
/// Claude 분석 유형 (향후):
/// - person_name, birth_date, address, account_number, ...
///
/// 예외처리:
/// - ValidationException: content 비어있음
/// - DatabaseException: 분석 실패
/// - NetworkException: Claude API 호출 실패 (선택적)
abstract class DetectPIITool {
  /// 콘텐츠에서 PII 탐지
  ///
  /// 파라미터:
  /// - content: 분석할 텍스트 (필수)
  /// - useClaudeAnalysis: Claude 분석 포함 여부 (기본: true)
  ///
  /// 반환:
  /// - List<PIIItem> (type, value, startIndex, endIndex 포함)
  ///
  /// 예외:
  /// - ValidationException: content 비어있음
  /// - NetworkException: Claude API 호출 실패 (선택적)
  static Future<List<PIIItem>> execute({
    required String content,
    bool useClaudeAnalysis = true,
  }) async {
    throw UnimplementedError(
      'detectPII는 정규식 기반 탐지 + Claude 통합 필요\n'
      '정규식 패턴: email, phone, ssn, credit_card\n'
      '반환: List<PIIItem>',
    );
  }

  /// 정규식 기반 PII 탐지
  static List<PIIItem> detectWithRegex(String content) {
    final results = <PIIItem>[];

    // 이메일 탐지
    final emailRegex = RegExp(
      r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    );
    for (final match in emailRegex.allMatches(content)) {
      results.add(PIIItem(
        type: 'email',
        value: match.group(0)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }

    // 전화번호 탐지
    final phoneRegex = RegExp(r'0\d{1,2}-\d{3,4}-\d{4}');
    for (final match in phoneRegex.allMatches(content)) {
      results.add(PIIItem(
        type: 'phone',
        value: match.group(0)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }

    // 주민번호 탐지
    final ssnRegex = RegExp(r'\d{6}-[1-4]\d{6}');
    for (final match in ssnRegex.allMatches(content)) {
      results.add(PIIItem(
        type: 'ssn',
        value: match.group(0)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }

    // 신용카드 탐지
    final creditCardRegex = RegExp(r'\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}');
    for (final match in creditCardRegex.allMatches(content)) {
      results.add(PIIItem(
        type: 'credit_card',
        value: match.group(0)!,
        startIndex: match.start,
        endIndex: match.end,
      ));
    }

    return results;
  }

  /// Claude를 통한 의미론적 PII 분석
  static Future<List<PIIItem>> detectWithClaude({
    required String content,
    int maxRetries = 3,
  }) async {
    throw UnimplementedError(
      'Claude API 통합 필요\n'
      'Prompt: 다음 텍스트에서 개인식별정보를 모두 찾으세요\n'
      '반환: JSON 형식 [{type, value, startIndex, endIndex}, ...]',
    );
  }
}
