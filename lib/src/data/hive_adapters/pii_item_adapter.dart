// 파일 목적: PIIItem Hive 어댑터
// @HiveType 데코레이터로 PIIItem 모델을 Hive 저장소에 매핑
// typeId 4: 모든 TypeAdapter 중 고유 ID, Hive 데이터 직렬화/역직렬화 담당
// PIIItem은 Record.detectedPII 리스트에 포함되는 약간의 필드 어댑터

import 'package:hive/hive.dart';
import '../models/pii_item.dart';

part 'pii_item_adapter.g.dart';

/// PIIItem 모델의 Hive TypeAdapter
/// typeId: 4 (고유) - Hive에서 PIIItem 객체를 식별하는 타입 ID
/// 이 어댑터는 build_runner로 자동 생성: dart run build_runner build
///
/// PIIItem은 Record 내 중첩 객체로 사용됨
/// - type: PII 종류 (email, phone, ssn, credit_card 등)
/// - value: 감지된 민감 정보 값
/// - startIndex, endIndex: 기록 콘텐츠 내 위치 (마스킹/하이라이팅용)
@HiveType(typeId: 4)
class PIIItemAdapter extends TypeAdapter<PIIItem> {
  @override
  final int typeId = 4;

  /// PIIItem 객체를 Hive에서 읽기 (자동 생성)
  @override
  PIIItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PIIItem(
      type: fields[0] as String,
      value: fields[1] as String,
      startIndex: fields[2] as int,
      endIndex: fields[3] as int,
    );
  }

  /// PIIItem 객체를 Hive에 저장 (자동 생성)
  @override
  void write(BinaryWriter writer, PIIItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.value)
      ..writeByte(2)
      ..write(obj.startIndex)
      ..writeByte(3)
      ..write(obj.endIndex);
  }
}
