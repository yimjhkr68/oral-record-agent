// 파일 목적: AppSettings Hive 어댑터
// @HiveType 데코레이터로 AppSettings 모델을 Hive 저장소에 매핑
// typeId 5: 모든 TypeAdapter 중 고유 ID, Hive 데이터 직렬화/역직렬화 담당

import 'package:hive/hive.dart';
import '../models/app_settings.dart';

part 'app_settings_adapter.g.dart';

/// AppSettings 모델의 Hive TypeAdapter
/// typeId: 5 (고유) - Hive에서 AppSettings 객체를 식별하는 타입 ID
/// 이 어댑터는 build_runner로 자동 생성: dart run build_runner build
@HiveType(typeId: 5)
class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 5;

  /// AppSettings 객체를 Hive에서 읽기 (자동 생성)
  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      id: fields[0] as String? ?? 'app_settings',
      language: fields[1] as String? ?? 'ko',
      autoTranscribe: fields[2] as bool? ?? false,
      piiDetectionEnabled: fields[3] as bool? ?? true,
      exportFormat: fields[4] as String? ?? 'json',
    );
  }

  /// AppSettings 객체를 Hive에 저장 (자동 생성)
  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.language)
      ..writeByte(2)
      ..write(obj.autoTranscribe)
      ..writeByte(3)
      ..write(obj.piiDetectionEnabled)
      ..writeByte(4)
      ..write(obj.exportFormat);
  }
}
