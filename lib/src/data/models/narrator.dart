// 파일 목적: 구술자(Narrator) 데이터 모델 정의 (v2 - 확장 필드 추가)
import 'package:uuid/uuid.dart';

class Narrator {
  final String id;
  final String name;

  // ── 기본 정보 ──────────────────────────
  final DateTime? dateOfBirth;
  final String? gender;        // 'M' | 'F' | 'Other'
  final String? nationality;   // 국적
  final String? birthPlace;    // 출생지

  // ── 경력 정보 ──────────────────────────
  final String? jobTitle;        // 직업/직위 (당시)
  final String? currentJobTitle; // 직업/직위 (현재)
  final String? affiliation;     // 소속 기관
  final List<String> careerList; // 주요 경력 (여러 개)

  // ── 연락처 (PII) ───────────────────────
  final String? phone;
  final String? email;
  final String? address;

  // ── 메모 ───────────────────────────────
  final String? biography;       // 구술자 약전/소개
  final String? notes;           // 특이사항
  final String? interviewNotes;  // 면담 전 조사 내용

  /// 사람이 읽기 쉬운 고유 식별자 (예: NAR-202603-0001)
  final String? displayId;

  final DateTime createdAt;
  final DateTime updatedAt;

  Narrator({
    String? id,
    required this.name,
    this.dateOfBirth,
    this.gender,
    this.nationality,
    this.birthPlace,
    this.jobTitle,
    this.currentJobTitle,
    this.affiliation,
    List<String>? careerList,
    this.phone,
    this.email,
    this.address,
    this.biography,
    this.notes,
    this.interviewNotes,
    this.displayId,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        careerList = careerList ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Narrator copyWith({
    String? name,
    DateTime? dateOfBirth,
    String? gender,
    String? nationality,
    String? birthPlace,
    String? jobTitle,
    String? currentJobTitle,
    String? affiliation,
    List<String>? careerList,
    String? phone,
    String? email,
    String? address,
    String? biography,
    String? notes,
    String? interviewNotes,
    String? displayId,
    DateTime? updatedAt,
  }) {
    return Narrator(
      id: id,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      nationality: nationality ?? this.nationality,
      birthPlace: birthPlace ?? this.birthPlace,
      jobTitle: jobTitle ?? this.jobTitle,
      currentJobTitle: currentJobTitle ?? this.currentJobTitle,
      affiliation: affiliation ?? this.affiliation,
      careerList: careerList ?? this.careerList,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      biography: biography ?? this.biography,
      notes: notes ?? this.notes,
      interviewNotes: interviewNotes ?? this.interviewNotes,
      displayId: displayId ?? this.displayId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Narrator && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Narrator(id: $id, name: $name)';
}
