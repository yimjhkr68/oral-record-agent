// 파일 목적: 음성/영상 파일 전사 서비스
// OpenAI Whisper API (multipart/form-data) 사용
// 지원: WAV, MP3, M4A, AAC, FLAC, OGG (25MB 이하)

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TranscriptionResult {
  final String text;
  final bool success;
  final String? error;

  const TranscriptionResult({
    required this.text,
    required this.success,
    this.error,
  });
}

class TranscriptionService {
  /// OpenAI Whisper API로 음성 파일 전사
  /// [filePath]: 음성 파일 절대 경로
  /// [apiKey]: OpenAI API 키 (sk-...)
  /// [mimeType]: 오디오 MIME 타입 (예: 'audio/mpeg')
  static Future<TranscriptionResult> transcribeFile({
    required String filePath,
    required String apiKey,
    required String mimeType,
  }) async {
    if (apiKey.isEmpty) {
      return const TranscriptionResult(
        text: '',
        success: false,
        error: 'OpenAI API 키가 설정되지 않았습니다. 설정 화면에서 OpenAI API 키를 입력해주세요.',
      );
    }

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final fileName = file.uri.pathSegments.last;

      // 25MB 제한 (Whisper API 제한)
      if (bytes.length > 25 * 1024 * 1024) {
        return TranscriptionResult(
          text: '',
          success: false,
          error: '파일 크기가 25MB를 초과합니다. (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB)',
        );
      }

      debugPrint('[전사 시작] $fileName (${bytes.length} bytes) → Whisper API');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
      );

      request.headers['Authorization'] = 'Bearer $apiKey';
      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'ko';
      request.fields['response_format'] = 'text';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final text = response.body.trim();
        debugPrint('[전사 완료] ${text.length}자');
        return TranscriptionResult(text: text, success: true);
      } else {
        debugPrint('[전사 실패] ${response.statusCode}: ${response.body}');
        String errorMsg = '알 수 없는 오류';
        try {
          // OpenAI 오류 응답 파싱
          final body = response.body;
          if (body.contains('"message"')) {
            final start = body.indexOf('"message":"') + 11;
            final end = body.indexOf('"', start);
            if (start > 10 && end > start) {
              errorMsg = body.substring(start, end);
            } else {
              errorMsg = body.length > 200 ? body.substring(0, 200) : body;
            }
          } else {
            errorMsg = body.length > 200 ? body.substring(0, 200) : body;
          }
        } catch (_) {}
        return TranscriptionResult(
          text: '',
          success: false,
          error: 'API 오류 (${response.statusCode}): $errorMsg',
        );
      }
    } catch (e) {
      debugPrint('[전사 오류] $e');
      return TranscriptionResult(
        text: '',
        success: false,
        error: '전사 실패: $e',
      );
    }
  }
}
