// 파일 목적: Record Hive 어댑터
// @HiveType 데코레이터로 Record 모델을 Hive 저장소에 매핑
// typeId 3: 모든 TypeAdapter 중 고유 ID, Hive 데이터 직렬화/역직렬화 담당
// Record는 가장 많은 필드(19개)를 포함하는 핵심 어댑터

import 'package:hive/hive.dart';
import '../models/record.dart';
import '../models/pii_item.dart';

part 'record_adapter.g.dart';

/// Record 모델의 Hive TypeAdapter
/// typeId: 3 (고유) - Hive에서 Record 객체를 식별하는 타입 ID
/// 이 어댑터는 build_runner로 자동 생성: dart run build_runner build
/// 
/// Record 어댑터에 포함된 필드 (19개):
/// - 기본정보: id, title, content, inputType(필수)
/// - 파일경로: originalAudioPath?, originalDocPath?
/// - 메타데이터: sessionId, narratorId, mainCategory(필수), subCategory?, keywordTags, visibility(필수), recordedBy(필수)
/// - AI결과: detectedPII, classification?, summary?
/// - 태그/시간: tags, createdAt, updatedAt
@HiveType(typeId: 3)
class RecordAdapter extends TypeAdapter<Record> {
  @override
  final int typeId = 3;

  /// Record 객체를 Hive에서 읽기 (자동 생성)
  @override
  Record read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Record(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      inputType: fields[3] as String,
      originalAudioPath: fields[4] as String?,
      originalDocPath: fields[5] as String?,
      originalFileName: fields[19] as String?,
      fileSize: fields[20] as int?,
      mimeType: fields[21] as String?,
      duration: fields[22] as int?,
      sessionId: fields[6] as String,
      narratorId: fields[7] as String,
      mainCategory: fields[8] as String,
      subCategory: fields[9] as String?,
      keywordTags: (fields[10] as List?)?.cast<String>() ?? [],
      visibility: fields[11] as String,
      recordedBy: fields[12] as String,
      detectedPII: (fields[13] as List?)?.cast<PIIItem>() ?? [],
      classification: fields[14] as String?,
      summary: fields[15] as String?,
      tags: (fields[16] as List?)?.cast<String>() ?? [],
      createdAt: fields[17] as DateTime,
      updatedAt: fields[18] as DateTime,
      displayId: fields[23] as String?,
      fileHash: fields[24] as String?,
    );
  }

  /// Record 객체를 Hive에 저장 (자동 생성)
  @override
  void write(BinaryWriter writer, Record obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.inputType)
      ..writeByte(4)
      ..write(obj.originalAudioPath)
      ..writeByte(5)
      ..write(obj.originalDocPath)
      ..writeByte(6)
      ..write(obj.sessionId)
      ..writeByte(7)
      ..write(obj.narratorId)
      ..writeByte(8)
      ..write(obj.mainCategory)
      ..writeByte(9)
      ..write(obj.subCategory)
      ..writeByte(10)
      ..write(obj.keywordTags)
      ..writeByte(11)
      ..write(obj.visibility)
      ..writeByte(12)
      ..write(obj.recordedBy)
      ..writeByte(13)
      ..write(obj.detectedPII)
      ..writeByte(14)
      ..write(obj.classification)
      ..writeByte(15)
      ..write(obj.summary)
      ..writeByte(16)
      ..write(obj.tags)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt)
      ..writeByte(19)
      ..write(obj.originalFileName)
      ..writeByte(20)
      ..write(obj.fileSize)
      ..writeByte(21)
      ..write(obj.mimeType)
      ..writeByte(22)
      ..write(obj.duration)
      ..writeByte(23)
      ..write(obj.displayId)
      ..writeByte(24)
      ..write(obj.fileHash);
  }
}
