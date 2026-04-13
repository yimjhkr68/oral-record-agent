// 파일 목적: InterviewSession Hive 어댑터
// @HiveType 데코레이터로 InterviewSession 모델을 Hive 저장소에 매핑
// typeId 2: 모든 TypeAdapter 중 고유 ID, Hive 데이터 직렬화/역직렬화 담당

import 'package:hive/hive.dart';
import '../models/interview_session.dart';

part 'interview_session_adapter.g.dart';

/// InterviewSession 모델의 Hive TypeAdapter
/// typeId: 2 (고유) - Hive에서 InterviewSession 객체를 식별하는 타입 ID
/// 이 어댑터는 build_runner로 자동 생성: dart run build_runner build
@HiveType(typeId: 2)
class InterviewSessionAdapter extends TypeAdapter<InterviewSession> {
  @override
  final int typeId = 2;

  /// InterviewSession 객체를 Hive에서 읽기 (자동 생성)
  @override
  InterviewSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InterviewSession(
      id: fields[0] as String,
      narratorId: fields[1] as String,
      interviewerId: fields[2] as String,
      sessionNo: fields[3] as int,
      interviewDate: fields[4] as DateTime,
      location: fields[5] as String?,
      interviewType: fields[6] as String,
      language: fields[7] as String? ?? 'ko',
      notes: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      updatedAt: fields[10] as DateTime,
    );
  }

  /// InterviewSession 객체를 Hive에 저장 (자동 생성)
  @override
  void write(BinaryWriter writer, InterviewSession obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.narratorId)
      ..writeByte(2)
      ..write(obj.interviewerId)
      ..writeByte(3)
      ..write(obj.sessionNo)
      ..writeByte(4)
      ..write(obj.interviewDate)
      ..writeByte(5)
      ..write(obj.location)
      ..writeByte(6)
      ..write(obj.interviewType)
      ..writeByte(7)
      ..write(obj.language)
      ..writeByte(8)
      ..write(obj.notes)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.updatedAt);
  }
}
