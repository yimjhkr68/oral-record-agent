// 파일 목적: generateTranscript 도구 구현
// 음성 파일을 텍스트로 변환 (STT - Speech to Text)
// 음성 파일 경로 또는 바이너리 입력 받아 텍스트 반환

import 'dart:typed_data';

/// 필기록 생성 결과
class TranscriptResult {
  final String text;
  final double confidence;
  final Duration duration;
  final int wordCount;
  final List<TranscriptSegment> segments;

  TranscriptResult({
    required this.text,
    required this.confidence,
    required this.duration,
    required this.segments,
  }) : wordCount = text.split(' ').length;
}

/// 필기록 세그먼트 (타임스탬프 포함)
class TranscriptSegment {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final double confidence;

  TranscriptSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.confidence,
  });
}

/// GenerateTranscript 도구
///
/// 책임:
/// 1. 음성 파일 입력 (MP3, WAV, M4A 등)
/// 2. STT 엔진 호출 (Google Cloud Speech-to-Text, Azure, Whisper 등)
/// 3. 텍스트 + 타임스탬프 반환
/// 4. 신뢰도 점수 제공
///
/// 입력:
/// - filePath: 음성 파일 경로 (권장)
/// - audioData: 음성 바이너리 (대안)
///
/// 반환:
/// - TranscriptResult (text, segments with timestamp, confidence)
///
/// 예외처리:
/// - ValidationException: 파일 없음, 형식 오류
/// - NetworkException: STT API 호출 실패
/// - DatabaseException: 저장 실패
abstract class GenerateTranscriptTool {
  /// 음성을 텍스트로 변환
  ///
  /// 파라미터:
  /// - filePath: 음성 파일 경로 (선택)
  /// - audioData: 음성 바이너리 데이터 (선택)
  /// - language: 언어 코드 (기본: "ko-KR")
  /// - includeTimestamp: 타임스탬프 포함 (기본: true)
  ///
  /// 반환:
  /// - TranscriptResult
  static Future<TranscriptResult> execute({
    String? filePath,
    Uint8List? audioData,
    String language = 'ko-KR',
    bool includeTimestamp = true,
  }) async {
    throw UnimplementedError(
      'generateTranscript는 STT 엔진 통합 필요\n'
      '엔진: Google Cloud Speech-to-Text, Azure, Whisper 등\n'
      '반환: TranscriptResult(text, segments with timestamp, confidence)',
    );
  }

  /// 간단한 모의 필기록 생성 (테스트용)
  static TranscriptResult generateMockTranscript(String mockText) {
    if (mockText.isEmpty) {
      return TranscriptResult(
        text: '',
        confidence: 0.0,
        duration: Duration.zero,
        segments: [],
      );
    }

    final words = mockText.split(' ');
    final segments = <TranscriptSegment>[];

    int charCount = 0;
    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final startSec = (charCount / 150).toInt(); // 단순 계산
      final endSec = ((charCount + word.length) / 150).toInt();

      segments.add(TranscriptSegment(
        text: word,
        startTime: Duration(seconds: startSec),
        endTime: Duration(seconds: endSec),
        confidence: 0.95,
      ));

      charCount += word.length + 1;
    }

    return TranscriptResult(
      text: mockText,
      confidence: 0.92,
      duration: Duration(seconds: (charCount / 150).toInt() + 10),
      segments: segments,
    );
  }
}
