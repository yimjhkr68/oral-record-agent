// 파일 목적: Narrator Hive 어댑터 (v2 - 확장 필드 포함)
// typeId 0: Hive 내 고유 ID
// 필드 0-8: 기존 (하위 호환), 9-17: 신규 추가

import 'package:hive/hive.dart';
import '../models/narrator.dart';

part 'narrator_adapter.g.dart';

@HiveType(typeId: 0)
class NarratorAdapter extends TypeAdapter<Narrator> {
  @override
  final int typeId = 0;

  @override
  Narrator read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Narrator(
      id: fields[0] as String,
      name: fields[1] as String,
      dateOfBirth: fields[2] as DateTime?,
      gender: fields[3] as String?,
      jobTitle: fields[4] as String?,
      currentJobTitle: fields[5] as String?,
      biography: fields[6] as String?,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      // 신규 필드 (구 데이터에는 없으므로 null 기본값)
      nationality: fields[9] as String?,
      birthPlace: fields[10] as String?,
      affiliation: fields[11] as String?,
      careerList: (fields[12] as List?)?.cast<String>(),
      phone: fields[13] as String?,
      email: fields[14] as String?,
      address: fields[15] as String?,
      notes: fields[16] as String?,
      interviewNotes: fields[17] as String?,
      displayId: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Narrator obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dateOfBirth)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.jobTitle)
      ..writeByte(5)
      ..write(obj.currentJobTitle)
      ..writeByte(6)
      ..write(obj.biography)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.nationality)
      ..writeByte(10)
      ..write(obj.birthPlace)
      ..writeByte(11)
      ..write(obj.affiliation)
      ..writeByte(12)
      ..write(obj.careerList)
      ..writeByte(13)
      ..write(obj.phone)
      ..writeByte(14)
      ..write(obj.email)
      ..writeByte(15)
      ..write(obj.address)
      ..writeByte(16)
      ..write(obj.notes)
      ..writeByte(17)
      ..write(obj.interviewNotes)
      ..writeByte(18)
      ..write(obj.displayId);
  }
}
