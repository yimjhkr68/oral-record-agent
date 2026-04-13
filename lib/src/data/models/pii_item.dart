// 파일 목적: PII(개인식별정보) 항목 데이터 모델 정의
// 기록에서 감지된 민감한 정보(이메일, 전화, 주민번호 등)를 저장
// Record.detectedPII 리스트에 포함

class PIIItem {
  /// PII 유형 (예: "email", "phone", "ssn", "credit_card", "person_name")
  /// detectPII 도구에서 설정
  final String type;

  /// 감지된 PII 값 (예: "user@example.com", "010-1234-5678")
  final String value;

  /// 기록 콘텐츠에서의 시작 인덱스 (0부터 시작)
  /// 마스킹 또는 하이라이팅에 사용
  final int startIndex;

  /// 기록 콘텐츠에서의 종료 인덱스
  /// UI에서 텍스트 범위 선택: content.substring(startIndex, endIndex)
  final int endIndex;

  /// 생성자
  PIIItem({
    required this.type,
    required this.value,
    required this.startIndex,
    required this.endIndex,
  });

  /// 복사 생성자 (사본 생성)
  PIIItem copyWith({
    String? type,
    String? value,
    int? startIndex,
    int? endIndex,
  }) {
    return PIIItem(
      type: type ?? this.type,
      value: value ?? this.value,
      startIndex: startIndex ?? this.startIndex,
      endIndex: endIndex ?? this.endIndex,
    );
  }

  /// 객체 동등성 비교
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PIIItem &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value &&
          startIndex == other.startIndex &&
          endIndex == other.endIndex;

  /// 해시 코드 생성
  @override
  int get hashCode =>
      type.hashCode ^ value.hashCode ^ startIndex.hashCode ^ endIndex.hashCode;

  /// 문자열 표현
  @override
  String toString() =>
      'PIIItem(type: $type, value: ***, position: $startIndex-$endIndex)';
}
