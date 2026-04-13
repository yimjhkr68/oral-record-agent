// 파일 목적: validatePII 도구 구현
// 탐지된 PII의 진정성 검증 (유효한 이메일인지, 유효한 전화번호인지 등)

import 'package:oral_record_agent/src/data/models/pii_item.dart';

/// PII 검증 결과
class PIIValidationResult {
  final PIIItem piiItem;
  final bool isValid;
  final String reason;
  final double confidence;

  PIIValidationResult({
    required this.piiItem,
    required this.isValid,
    this.reason = '',
    this.confidence = 1.0,
  });
}

/// ValidatePII 도구
///
/// 책임:
/// 1. PII의 형식 검증 (유효한 이메일, 전화번호 등)
/// 2. 비즈니스 규칙 검증 (국가별 전화번호 규칙 등)
/// 3. 신뢰도 점수 반환
///
/// 검증 규칙:
/// - email: RFC 5322 정규식 + 도메인 존재 여부
/// - phone: 국가별 전화번호 형식 (한국: 10-11자리)
/// - ssn: 주민번호 체크디짓
/// - credit_card: Luhn 알고리즘
///
/// 반환:
/// - List<PIIValidationResult> (isValid, reason, confidence)
///
/// 예외처리:
/// - ValidationException: piiItems 비어있음
/// - NetworkException: 도메인 검증 실패 (선택적)
abstract class ValidatePIITool {
  /// PII 항목들 검증
  ///
  /// 파라미터:
  /// - piiItems: 검증할 PII 리스트
  /// - checkDomain: 도메인 존재 여부 확인 (이메일)
  ///
  /// 반환:
  /// - List<PIIValidationResult>
  static Future<List<PIIValidationResult>> execute({
    required List<PIIItem> piiItems,
    bool checkDomain = false,
  }) async {
    throw UnimplementedError(
      'validatePII는 형식 + 비즈니스 규칙 검증 필요\n'
      '검증: email(RFC5322), phone(한국), ssn(체크디짓), credit_card(Luhn)\n'
      '반환: List<PIIValidationResult>',
    );
  }

  /// 이메일 검증
  static PIIValidationResult validateEmail(PIIItem email) {
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    final isValid = RegExp(emailRegex).hasMatch(email.value);

    return PIIValidationResult(
      piiItem: email,
      isValid: isValid,
      reason: isValid ? '유효한 이메일 형식' : '이메일 형식 오류',
      confidence: isValid ? 0.95 : 0.0,
    );
  }

  /// 전화번호 검증 (한국)
  static PIIValidationResult validatePhone(PIIItem phone) {
    // 한국 전화번호: 010-XXXX-XXXX (10자리), 02-XXX-XXXX (9자리)
    final phoneRegex = RegExp(r'^0\d{1,2}-\d{3,4}-\d{4}$');
    final isValid = phoneRegex.hasMatch(phone.value);

    return PIIValidationResult(
      piiItem: phone,
      isValid: isValid,
      reason: isValid ? '유효한 전화번호 형식' : '전화번호 형식 오류',
      confidence: isValid ? 0.90 : 0.0,
    );
  }

  /// 주민번호 검증 (체크디짓)
  static PIIValidationResult validateSSN(PIIItem ssn) {
    final ssnRegex = RegExp(r'^(\d{6})-([1-4]\d{6})$');
    final match = ssnRegex.firstMatch(ssn.value);

    if (match == null) {
      return PIIValidationResult(
        piiItem: ssn,
        isValid: false,
        reason: '주민번호 형식 오류',
        confidence: 0.0,
      );
    }

    // 체크디짓 검증 (가중치: 2,3,4,5,6,7,8,9,2,3,4,5)
    final digits =
        (match.group(1)! + match.group(2)!).split('').map(int.parse).toList();
    const weights = [2, 3, 4, 5, 6, 7, 8, 9, 2, 3, 4, 5];

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += digits[i] * weights[i];
    }

    final checkDigit = (11 - (sum % 11)) % 10;
    final isValid = checkDigit == digits[12];

    return PIIValidationResult(
      piiItem: ssn,
      isValid: isValid,
      reason: isValid ? '유효한 주민번호' : '체크디짓 오류',
      confidence: isValid ? 0.99 : 0.0,
    );
  }

  /// 신용카드 검증 (Luhn 알고리즘)
  static PIIValidationResult validateCreditCard(PIIItem card) {
    final cardNumber = card.value.replaceAll(RegExp(r'[-\s]'), '');

    if (!RegExp(r'^\d{16}$').hasMatch(cardNumber)) {
      return PIIValidationResult(
        piiItem: card,
        isValid: false,
        reason: '신용카드 번호 형식 오류 (16자리)',
        confidence: 0.0,
      );
    }

    // Luhn 알고리즘
    int sum = 0;
    bool isEven = false;

    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (isEven) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }

      sum += digit;
      isEven = !isEven;
    }

    final isValid = sum % 10 == 0;

    return PIIValidationResult(
      piiItem: card,
      isValid: isValid,
      reason: isValid ? '유효한 신용카드 번호' : 'Luhn 검증 실패',
      confidence: isValid ? 0.85 : 0.0,
    );
  }
}
