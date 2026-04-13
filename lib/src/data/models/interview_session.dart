// 파일 목적: 면담 세션(InterviewSession) 데이터 모델 정의
// 각 구술자와 면담자의 면담 기록을 추적하는 메타데이터
// 같은 구술자의 여러 회차 면담을 sessionNo로 구분

import 'package:uuid/uuid.dart';

class InterviewSession {
  /// 면담 세션 고유 ID (UUID)
  final String id;

  /// 구술자 ID (필수, Narrator 참조)
  /// 같은 구술자의 여러 세션은 narratorId로 연결
  final String narratorId;

  /// 면담자 ID (필수, Interviewer 참조)
  final String interviewerId;

  /// 회차 번호 (필수, 예: 1차, 2차, 3차...)
  /// 같은 구술자의 여러 면담 회차를 구분하는 핵심 필드
  final int sessionNo;

  /// 면담 일시 (필수)
  final DateTime interviewDate;

  /// 면담 장소 (선택)
  final String? location;

  /// 면담 유형 (필수, 예: "oral", "document", "phone")
  final String interviewType;

  /// 사용 언어 (기본값: "ko" 한국어)
  final String language;

  /// 면담 노트/메모 (선택)
  final String? notes;

  /// 레코드 생성 시각
  final DateTime createdAt;

  /// 레코드 마지막 수정 시각
  final DateTime updatedAt;

  /// 생성자
  InterviewSession({
    String? id,
    required this.narratorId,
    required this.interviewerId,
    required this.sessionNo,
    required this.interviewDate,
    this.location,
    required this.interviewType,
    this.language = 'ko',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 복사 생성자 (사본 생성 시 일부 필드 변경)
  InterviewSession copyWith({
    String? interviewType,
    String? location,
    String? language,
    String? notes,
    DateTime? updatedAt,
  }) {
    return InterviewSession(
      id: id,
      narratorId: narratorId,
      interviewerId: interviewerId,
      sessionNo: sessionNo,
      interviewDate: interviewDate,
      location: location ?? this.location,
      interviewType: interviewType ?? this.interviewType,
      language: language ?? this.language,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 객체 동등성 비교
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InterviewSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// 해시 코드 생성
  @override
  int get hashCode => id.hashCode;

  /// 문자열 표현
  @override
  String toString() =>
      'InterviewSession(id: $id, narratorId: $narratorId, sessionNo: $sessionNo, date: $interviewDate)';
}
