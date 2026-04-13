// 파일 목적: 앱 설정(AppSettings) 데이터 모델 정의
// 사용자의 전역 설정(언어, 자동 전사, PII 감지, 내보내기 형식)을 저장
// Hive 'settings' 박스에 단일 객체로 저장

class AppSettings {
  /// 설정 고유 ID (고정값: "app_settings")
  /// Hive에서 단일 객체로 관리하기 위해 동일 ID 사용
  final String id;

  /// 앱 언어 설정 ("ko" 한국어, "en" 영어 등)
  /// UI 다국어 지원 시 사용
  final String language;

  /// 자동 전사 활성화 여부
  /// true: 음성 입력 시 자동으로 transcribeAudio 실행
  /// false: 사용자 수동 요청 시에만 전사
  final bool autoTranscribe;

  /// PII 감지 활성화 여부
  /// true: 기록 저장 시 자동으로 detectPII 실행
  /// false: PII 감지 비활성화
  final bool piiDetectionEnabled;

  /// 내보내기 기본 형식 ("json" 또는 "txt")
  /// exportRecord 도구 사용 시 기본값으로 적용
  final String exportFormat;

  /// 생성자
  AppSettings({
    this.id = 'app_settings',
    this.language = 'ko',
    this.autoTranscribe = false,
    this.piiDetectionEnabled = true,
    this.exportFormat = 'json',
  });

  /// 복사 생성자 (사본 생성 시 일부 필드 변경)
  AppSettings copyWith({
    String? language,
    bool? autoTranscribe,
    bool? piiDetectionEnabled,
    String? exportFormat,
  }) {
    return AppSettings(
      id: id,
      language: language ?? this.language,
      autoTranscribe: autoTranscribe ?? this.autoTranscribe,
      piiDetectionEnabled: piiDetectionEnabled ?? this.piiDetectionEnabled,
      exportFormat: exportFormat ?? this.exportFormat,
    );
  }

  /// 객체 동등성 비교
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// 해시 코드 생성
  @override
  int get hashCode => id.hashCode;

  /// 문자열 표현
  @override
  String toString() =>
      'AppSettings(language: $language, autoTranscribe: $autoTranscribe, piiDetection: $piiDetectionEnabled, exportFormat: $exportFormat)';
}
