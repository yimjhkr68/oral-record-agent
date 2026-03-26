// 파일 목적: 면담자(Interviewer) 데이터 모델 정의 (v2 - 확장 필드 추가)
import 'package:uuid/uuid.dart';

class Interviewer {
  final String id;
  final String name;

  // ── 기본 정보 ──────────────────────────
  final String? affiliation;   // 소속 기관
  final String? jobTitle;      // 직위
  final String? specialization; // 전문 분야

  // ── 연락처 (선택) ──────────────────────
  final String? phone;
  final String? email;

  // ── 메모 ───────────────────────────────
  final String? notes;

  /// 사람이 읽기 쉬운 고유 식별자 (예: INT-202603-0001)
  final String? displayId;

  final DateTime createdAt;
  final DateTime updatedAt;

  Interviewer({
    String? id,
    required this.name,
    this.affiliation,
    this.jobTitle,
    this.specialization,
    this.phone,
    this.email,
    this.notes,
    this.displayId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Interviewer copyWith({
    String? name,
    String? affiliation,
    String? jobTitle,
    String? specialization,
    String? phone,
    String? email,
    String? notes,
    String? displayId,
    DateTime? updatedAt,
  }) {
    return Interviewer(
      id: id,
      name: name ?? this.name,
      affiliation: affiliation ?? this.affiliation,
      jobTitle: jobTitle ?? this.jobTitle,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      notes: notes ?? this.notes,
      displayId: displayId ?? this.displayId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Interviewer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Interviewer(id: $id, name: $name, affiliation: $affiliation)';
}
