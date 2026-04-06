// 파일 목적: 영상 파일에서 음성 추출 후 Whisper 전사
// ffmpeg(extract_audio.py) → WAV → LocalTranscriptionService

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'local_transcription_service.dart';

class VideoTranscriptionResult {
  final String text;
  final bool success;
  final String? error;
  final bool outOfMemory;

  const VideoTranscriptionResult({
    required this.text,
    required this.success,
    this.error,
    this.outOfMemory = false,
  });
}

class VideoTranscriptionService {
  /// 영상 파일 → ffmpeg 음성 추출 → Whisper 전사
  static Future<VideoTranscriptionResult> transcribeVideo({
    required String videoPath,
    String pythonPath = 'python',
    String model = 'base',
    String language = 'ko',
    String? scriptDir,
    void Function(String)? onProgress,
  }) async {
    // 1. extract_audio.py 경로 결정
    final extractScript = _findScript(scriptDir, 'extract_audio.py');
    if (extractScript == null) {
      return const VideoTranscriptionResult(
        text: '',
        success: false,
        error: 'scripts/extract_audio.py 파일을 찾을 수 없습니다.',
      );
    }


    String? tempWavPath;

    try {
      final env = Map<String, String>.from(Platform.environment)
        ..['PYTHONIOENCODING'] = 'utf-8'
        ..['PYTHONUTF8'] = '1';

      // 2. ffmpeg으로 음성 추출
      onProgress?.call('1/2 음성 추출 중...');
      final extractResult = await Process.run(
        pythonPath,
        ['-u', extractScript, videoPath],
        stdoutEncoding: utf8,
        stderrEncoding: latin1,
        runInShell: Platform.isWindows,
        environment: env,
      ).timeout(
        const Duration(minutes: 3),
        onTimeout: () => ProcessResult(-1, 1, '', '타임아웃: 음성 추출에 3분 이상 소요됩니다.'),
      );


      if (extractResult.exitCode == -1 ||
          extractResult.stderr.toString().contains('is not recognized') ||
          extractResult.stderr.toString().contains('No such file or directory')) {
        return const VideoTranscriptionResult(
          text: '',
          success: false,
          error: 'Python을 찾을 수 없습니다. 설정에서 Python 경로를 확인해주세요.',
        );
      }

      final stdout = extractResult.stdout.toString().trim();
      String? jsonLine;
      for (final line in stdout.split('\n').map((l) => l.trim()).toList().reversed) {
        if (line.startsWith('{') && line.endsWith('}')) {
          jsonLine = line;
          break;
        }
      }

      if (jsonLine == null) {
        return VideoTranscriptionResult(
          text: '',
          success: false,
          error: '음성 추출 결과 파싱 실패: ${stdout.isEmpty ? extractResult.stderr.toString().take(200) : stdout.take(200)}',
        );
      }

      final Map<String, dynamic> extractJson;
      try {
        extractJson = jsonDecode(jsonLine) as Map<String, dynamic>;
      } catch (e) {
        return VideoTranscriptionResult(
          text: '',
          success: false,
          error: 'JSON 파싱 오류: $e',
        );
      }

      if (extractJson.containsKey('error')) {
        return VideoTranscriptionResult(
          text: '',
          success: false,
          error: extractJson['error'] as String,
        );
      }

      tempWavPath = extractJson['audio_path'] as String?;
      if (tempWavPath == null || !File(tempWavPath).existsSync()) {
        return const VideoTranscriptionResult(
          text: '',
          success: false,
          error: '추출된 WAV 파일을 찾을 수 없습니다.',
        );
      }


      // 3. Whisper 전사
      onProgress?.call('2/2 텍스트 전사 중...');
      final transcribeResult = await LocalTranscriptionService.transcribeFile(
        filePath: tempWavPath,
        pythonPath: pythonPath,
        model: model,
        language: language,
        scriptDir: scriptDir,
      );

      if (!transcribeResult.success) {
        return VideoTranscriptionResult(
          text: '',
          success: false,
          outOfMemory: transcribeResult.outOfMemory,
          error: transcribeResult.error,
        );
      }

      return VideoTranscriptionResult(
        text: transcribeResult.text,
        success: true,
      );
    } catch (e) {
      return VideoTranscriptionResult(
        text: '',
        success: false,
        error: '영상 전사 오류: $e',
      );
    } finally {
      // 4. 임시 WAV 파일 삭제
      if (tempWavPath != null) {
        try { File(tempWavPath).deleteSync(); } catch (_) {}
      }
    }
  }

  static String? _findScript(String? scriptDir, String scriptName) {
    if (scriptDir != null) {
      final p = '$scriptDir${Platform.pathSeparator}$scriptName';
      if (File(p).existsSync()) return p;
    }
    final devPath =
        '${Directory.current.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}$scriptName';
    if (File(devPath).existsSync()) return devPath;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    var dir = Directory(exeDir);
    for (var i = 0; i < 5; i++) {
      final candidate =
          '${dir.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}$scriptName';
      if (File(candidate).existsSync()) return candidate;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}

extension _StringTake on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
