// 파일 목적: transcribeAudio 도구 구현
// 로컬 Whisper Python 스크립트(scripts/transcribe.py) 실행으로 음성 전사
// Process.run(python, [scriptPath, audioPath, --language, lang]) → JSON 파싱

import 'dart:io';
import 'tool_base.dart';
import '../../data/services/local_transcription_service.dart';

/// transcribeAudio 도구
///
/// 책임:
/// 1. 음성 파일 검증 (형식: mp3, wav, m4a, aac, flac / 크기: 500MB 이하)
/// 2. scripts/transcribe.py 를 Process.run() 으로 실행
/// 3. stdout JSON 에서 text 추출
/// 4. Whisper/Python 미설치 시 안내 메시지 반환
abstract class TranscribeAudioTool {
  /// 음성 파일 전사 (로컬 Whisper Python 스크립트 사용)
  ///
  /// 파라미터:
  /// - audioPath: 음성 파일 절대 경로 (필수)
  /// - language: 음성 언어 ("ko" 기본값)
  /// - pythonPath: Python 실행파일 경로 (기본값: "python")
  /// - model: Whisper 모델 크기 (기본값: "medium")
  ///
  /// 반환:
  /// - 전사된 텍스트 (성공)
  ///
  /// 예외:
  /// - ValidationException: 파일 형식 미지원, 크기 초과, 경로 비어있음
  /// - FileException: 파일 미존재
  /// - NetworkException: Python/Whisper 미설치 (메시지에 안내 포함)
  static Future<String> execute({
    required String audioPath,
    String language = 'ko',
    String pythonPath = 'python',
    String model = 'medium',
  }) async {
    validateAudioFile(audioPath);

    final result = await LocalTranscriptionService.transcribeFile(
      filePath: audioPath,
      pythonPath: pythonPath,
      model: model,
      language: language,
    );

    if (result.success) {
      return result.text;
    }

    if (result.pythonNotFound) {
      throw NetworkException(
        'Python을 찾을 수 없습니다.\n'
        '설치: https://www.python.org/downloads/\n'
        '설치 후 설정 화면에서 Python 경로를 지정하거나 시스템 PATH에 python을 추가해주세요.',
      );
    }

    if (result.whisperNotInstalled) {
      throw NetworkException(
        'openai-whisper가 설치되지 않았습니다.\n'
        '설치 명령: pip install openai-whisper\n'
        '(첫 실행 시 선택한 모델 파일이 자동으로 다운로드됩니다)',
      );
    }

    throw NetworkException(result.error ?? '전사 실패: 알 수 없는 오류');
  }

  /// 음성 파일 검증
  static void validateAudioFile(String audioPath) {
    if (audioPath.isEmpty) {
      throw ValidationException('audioPath는 필수입니다');
    }

    final file = File(audioPath);
    if (!file.existsSync()) {
      throw FileException('음성 파일을 찾을 수 없습니다', filePath: audioPath);
    }

    final extension = audioPath.split('.').last.toLowerCase();
    const supportedFormats = ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'];
    if (!supportedFormats.contains(extension)) {
      throw ValidationException(
        '지원하지 않는 형식입니다. 지원 형식: ${supportedFormats.join(", ")}',
      );
    }

    const maxSizeBytes = 500 * 1024 * 1024;
    if (file.lengthSync() > maxSizeBytes) {
      throw ValidationException(
        '파일 크기가 너무 큽니다. 최대: 500MB, '
        '현재: ${(file.lengthSync() / 1024 / 1024).toStringAsFixed(2)}MB',
      );
    }
  }
}
