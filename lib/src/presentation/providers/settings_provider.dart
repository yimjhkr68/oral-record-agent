// 파일 목적: 설정 상태 관리 Provider
// 앱 전역 설정 (자동 전사, PII 감지 여부 등)

import 'package:riverpod/riverpod.dart';

/// 앱 설정 상태
class AppSettingsState {
  final bool autoTranscribe; // 자동 전사
  final bool enablePIIDetection; // PII 감지 활성화
  final String exportFormat; // "json" 또는 "txt"
  final bool darkMode; // 다크 모드
  final String language; // "ko", "en"
  final String apiKey;        // Claude API 키 (요약 생성용)
  final String openAiApiKey;  // OpenAI API 키 (음성 전사용, 미사용 시 로컬 Whisper)
  final String whisperModel;      // 로컬 Whisper 모델 크기 (tiny/base/small/medium/large)
  final String pythonPath;        // Python 실행파일 경로
  final String transcriptionLanguage; // 전사 언어 코드 (ko, en 등)
  final int generateDocTimeoutMinutes; // 산출물 생성 최대 대기 시간 (분)
  final int transcribeTimeoutMinutes;  // 전사 최대 대기 시간 (분)

  AppSettingsState({
    this.autoTranscribe = true,
    this.enablePIIDetection = true,
    this.exportFormat = 'json',
    this.darkMode = false,
    this.language = 'ko',
    this.apiKey = '',
    this.openAiApiKey = '',
    this.whisperModel = 'base',
    this.pythonPath = 'python',
    this.transcriptionLanguage = 'ko',
    this.generateDocTimeoutMinutes = 3,
    this.transcribeTimeoutMinutes = 15,
  });

  AppSettingsState copyWith({
    bool? autoTranscribe,
    bool? enablePIIDetection,
    String? exportFormat,
    bool? darkMode,
    String? language,
    String? apiKey,
    String? openAiApiKey,
    String? whisperModel,
    String? pythonPath,
    String? transcriptionLanguage,
    int? generateDocTimeoutMinutes,
    int? transcribeTimeoutMinutes,
  }) {
    return AppSettingsState(
      autoTranscribe: autoTranscribe ?? this.autoTranscribe,
      enablePIIDetection: enablePIIDetection ?? this.enablePIIDetection,
      exportFormat: exportFormat ?? this.exportFormat,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      apiKey: apiKey ?? this.apiKey,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      whisperModel: whisperModel ?? this.whisperModel,
      pythonPath: pythonPath ?? this.pythonPath,
      transcriptionLanguage: transcriptionLanguage ?? this.transcriptionLanguage,
      generateDocTimeoutMinutes: generateDocTimeoutMinutes ?? this.generateDocTimeoutMinutes,
      transcribeTimeoutMinutes: transcribeTimeoutMinutes ?? this.transcribeTimeoutMinutes,
    );
  }
}

/// 설정 상태 관리자
class SettingsNotifier extends StateNotifier<AppSettingsState> {
  SettingsNotifier({String initialApiKey = ''})
      : super(AppSettingsState(apiKey: initialApiKey));

  void toggleAutoTranscribe() {
    state = state.copyWith(autoTranscribe: !state.autoTranscribe);
  }

  void togglePIIDetection() {
    state = state.copyWith(enablePIIDetection: !state.enablePIIDetection);
  }

  void setExportFormat(String format) {
    state = state.copyWith(exportFormat: format);
  }

  void toggleDarkMode() {
    state = state.copyWith(darkMode: !state.darkMode);
  }

  void setLanguage(String lang) {
    state = state.copyWith(language: lang);
  }

  void setApiKey(String key) {
    state = state.copyWith(apiKey: key);
  }

  void setOpenAiApiKey(String key) {
    state = state.copyWith(openAiApiKey: key);
  }

  void setWhisperModel(String model) {
    state = state.copyWith(whisperModel: model);
  }

  void setPythonPath(String path) {
    state = state.copyWith(pythonPath: path);
  }

  void setTranscriptionLanguage(String lang) {
    state = state.copyWith(transcriptionLanguage: lang);
  }

  void setGenerateDocTimeout(int minutes) {
    state = state.copyWith(generateDocTimeoutMinutes: minutes);
  }

  void setTranscribeTimeout(int minutes) {
    state = state.copyWith(transcribeTimeoutMinutes: minutes);
  }
}

/// 설정 Provider
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettingsState>(
  (ref) => SettingsNotifier(),
);
