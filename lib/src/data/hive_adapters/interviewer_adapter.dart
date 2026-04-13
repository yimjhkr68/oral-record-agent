// 파일 목적: Interviewer Hive 어댑터 (v2 - 확장 필드 포함)
// typeId 1: Hive 내 고유 ID
// 필드 0-4: 기존 (하위 호환), 5-9: 신규 추가

import 'package:hive/hive.dart';
import '../models/interviewer.dart';

part 'interviewer_adapter.g.dart';

@HiveType(typeId: 1)
class InterviewerAdapter extends TypeAdapter<Interviewer> {
  @override
  final int typeId = 1;

  @override
  Interviewer read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Interviewer(
      id: fields[0] as String,
      name: fields[1] as String,
      affiliation: fields[2] as String?,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      // 신규 필드
      jobTitle: fields[5] as String?,
      specialization: fields[6] as String?,
      phone: fields[7] as String?,
      email: fields[8] as String?,
      notes: fields[9] as String?,
      displayId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Interviewer obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.affiliation)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.jobTitle)
      ..writeByte(6)
      ..write(obj.specialization)
      ..writeByte(7)
      ..write(obj.phone)
      ..writeByte(8)
      ..write(obj.email)
      ..writeByte(9)
      ..write(obj.notes)
      ..writeByte(10)
      ..write(obj.displayId);
  }
}
