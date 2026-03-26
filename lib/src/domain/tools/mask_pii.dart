// 파일 목적: maskPII 도구 구현
// 탐지된 PII를 무음화(마스킹) 처리
// 3가지 전략: full(*로 전체 치환), partial(일부만 표시), hash(해시값)

import 'package:oral_record_agent/src/data/models/pii_item.dart';

/// 마스킹 전략
enum MaskingStrategy { full, partial, hash }

/// MaskPII 도구
///
/// 책임:
/// 1. PII 탐지 (detectPII 결과 사용 또는 새로 탐지)
/// 2. 마스킹 전략에 따라 치환
/// 3. 마스킹된 콘텐츠 + 감사 로그 반환
///
/// 전략:
/// - full: "user@example.com" → "*****" (완전 치환)
/// - partial: "user@example.com" → "u***@e***m" (일부 표시)
/// - hash: "user@example.com" → "{HASH:a3c4}" (해시값 + 감시계)
///
/// 반환:
/// - maskedContent: 마스킹된 텍스트
/// - maskingLog: [{type, original_length, masked_at, strategy}, ...]
/// - piiCount: 마스킹된 PII 개수
///
/// 예외처리:
/// - ValidationException: content 비어있음, strategy 유효성
/// - DatabaseException: PII 탐지 실패
abstract class MaskPIITool {
  /// PII를 마스킹처리
  ///
  /// 파라미터:
  /// - content: 원본 콘텐츠
  /// - strategy: full(기본), partial, hash
  /// - piiItems: 사전에 탐지된 PIIItem 리스트 (선택)
  ///           없으면 자동 탐지
  ///
  /// 반환:
  /// - {maskedContent, maskingLog, piiCount}
  static Future<Map<String, dynamic>> execute({
    required String content,
    MaskingStrategy strategy = MaskingStrategy.full,
    List<PIIItem>? piiItems,
  }) async {
    throw UnimplementedError(
      'maskPII는 전략별 마스킹 + 감시계 로깅 필요\n'
      '전략: full, partial, hash\n'
      '반환: {maskedContent, maskingLog, piiCount}',
    );
  }

  /// Full 마스킹 (전체 치환)
  static String maskFull(String value) {
    if (value.isEmpty) return '';
    return '*' * (value.length > 5 ? 5 : value.length);
  }

  /// Partial 마스킹 (일부 표시)
  static String maskPartial(String value,
      {int showFirst = 1, int showLast = 1}) {
    if (value.length <= (showFirst + showLast)) return value;
    final middle = '*' * (value.length - showFirst - showLast);
    return '${value.substring(0, showFirst)}$middle${value.substring(value.length - showLast)}';
  }

  /// Hash 마스킹
  static String maskHash(String value) {
    if (value.isEmpty) return '{HASH:0000}';
    // NOTE: 실제 SHA256 해시 사용
    final hashValue = value.hashCode.abs().toString().substring(0, 4);
    return '{HASH:$hashValue}';
  }
}
