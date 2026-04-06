// 파일 목적: 로컬 Whisper 모델로 음성 전사 (Python 스크립트 호출)
// 구조: Flutter → Process.run(python, scripts/transcribe.py) → JSON 결과 파싱
// 오류 처리: Python 미설치, whisper 미설치, 모델 다운로드 필요

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class LocalTranscriptionResult {
  final String text;
  final bool success;
  final String? error;
  final bool pythonNotFound;
  final bool whisperNotInstalled;
  final bool outOfMemory;
  final List<Map<String, dynamic>> segments;

  const LocalTranscriptionResult({
    required this.text,
    required this.success,
    this.error,
    this.pythonNotFound = false,
    this.whisperNotInstalled = false,
    this.outOfMemory = false,
    this.segments = const [],
  });
}

class LocalTranscriptionService {
  /// 로컬 Whisper Python 스크립트로 음성 파일 전사
  /// [filePath]: 음성 파일 절대 경로
  /// [pythonPath]: Python 실행파일 경로 (기본값: 'python')
  /// [model]: Whisper 모델 크기 (tiny/base/small/medium/large)
  /// [language]: 전사 언어 코드 (기본값: 'ko')
  /// [scriptDir]: scripts/ 디렉터리 절대 경로 (기본값: 자동 감지)
  static Future<LocalTranscriptionResult> transcribeFile({
    required String filePath,
    String pythonPath = 'python',
    String model = 'base',
    String language = 'ko',
    String? scriptDir,
    int timeoutMinutes = 15,
  }) async {
    // scripts/transcribe.py 경로 결정
    final String scriptPath;
    if (scriptDir != null) {
      scriptPath = '$scriptDir${Platform.pathSeparator}transcribe.py';
    } else {
      // 실행 파일 기준으로 scripts/ 찾기
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      // Windows 빌드: app.exe 는 build/windows/.../Release/ 에 위치
      // 개발 모드: flutter run 시 프로젝트 루트가 기준
      final candidates = [
        // 프로젝트 루트 기준 (개발 모드)
        '${Directory.current.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}transcribe.py',
        // 실행파일 상위 5단계 탐색 (빌드 모드)
        _findScriptFromDir(exeDir, 5),
      ].whereType<String>().toList();

      String? found;
      for (final c in candidates) {
        if (File(c).existsSync()) {
          found = c;
          break;
        }
      }
      if (found == null) {
        return const LocalTranscriptionResult(
          text: '',
          success: false,
          error: 'scripts/transcribe.py 파일을 찾을 수 없습니다. 프로젝트 루트의 scripts/ 디렉터리를 확인해주세요.',
        );
      }
      scriptPath = found;
    }


    try {
      // PYTHONIOENCODING=utf-8: Windows CP949 기본 인코딩으로 인한 한글 깨짐 방지
      // PYTHONUTF8=1: Python 3.7+ UTF-8 모드 활성화 (-X utf8 과 동일)
      final env = Map<String, String>.from(Platform.environment)
        ..['PYTHONIOENCODING'] = 'utf-8'
        ..['PYTHONUTF8'] = '1';

      final result = await Process.run(
        pythonPath,
        ['-u', scriptPath, filePath, '--model', model, '--language', language],
        stdoutEncoding: utf8,
        stderrEncoding: latin1, // whisper stderr에 비UTF-8 바이트 포함 가능
        runInShell: Platform.isWindows,
        environment: env,
      ).timeout(
        Duration(minutes: timeoutMinutes),
        onTimeout: () => ProcessResult(-1, 1, '', '타임아웃: 전사에 $timeoutMinutes분 이상 소요됩니다. 설정에서 대기 시간을 늘려보세요.'),
      );

      if (result.stderr.toString().isNotEmpty) {
      }

      final stdout = result.stdout.toString().trim();

      // Python 실행 실패 (명령어 없음)
      if (result.exitCode == -1 ||
          result.stderr.toString().contains('is not recognized') ||
          result.stderr.toString().contains('No such file or directory')) {
        return const LocalTranscriptionResult(
          text: '',
          success: false,
          pythonNotFound: true,
          error: 'Python을 찾을 수 없습니다. Python이 설치되어 있는지 확인하거나 설정에서 Python 경로를 지정해주세요.\n'
              '설치: https://www.python.org/downloads/',
        );
      }

      // OOM 감지 (stderr에서 확인)
      final stderr = result.stderr.toString();
      if (stderr.contains('not enough memory') ||
          stderr.contains('DefaultCPUAllocator') ||
          stderr.contains('out of memory') ||
          stderr.contains('MemoryError')) {
        return const LocalTranscriptionResult(
          text: '',
          success: false,
          outOfMemory: true,
          error: '메모리가 부족합니다.\n설정에서 더 작은 Whisper 모델을 선택해주세요.\n권장: base 또는 small 모델',
        );
      }

      // JSON 파싱
      if (stdout.isEmpty) {
        return LocalTranscriptionResult(
          text: '',
          success: false,
          error: '전사 스크립트가 결과를 반환하지 않았습니다.\nstderr: ${stderr.take(200)}',
        );
      }

      // stdout에서 JSON 줄 찾기 (모델 로딩 로그 등 앞에 있을 수 있음)
      final jsonLine = _extractJsonLine(stdout);
      if (jsonLine == null) {
        return LocalTranscriptionResult(
          text: '',
          success: false,
          error: '전사 결과를 파싱할 수 없습니다.\n출력: ${stdout.take(300)}',
        );
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(jsonLine) as Map<String, dynamic>;
      } catch (e) {
        return LocalTranscriptionResult(
          text: '',
          success: false,
          error: 'JSON 파싱 오류: $e\n출력: ${jsonLine.take(200)}',
        );
      }

      // 오류 응답
      if (json.containsKey('error')) {
        final errMsg = json['error'] as String;
        final isOOM = errMsg.contains('not enough memory') ||
            errMsg.contains('DefaultCPUAllocator') ||
            errMsg.contains('MemoryError') ||
            errMsg.contains('out of memory');
        if (isOOM) {
          return const LocalTranscriptionResult(
            text: '',
            success: false,
            outOfMemory: true,
            error: '메모리가 부족합니다.\n설정에서 더 작은 Whisper 모델을 선택해주세요.\n권장: base 또는 small 모델',
          );
        }
        final isWhisperMissing = errMsg.contains('openai-whisper') ||
            errMsg.contains('No module named') ||
            errMsg.contains('whisper');
        return LocalTranscriptionResult(
          text: '',
          success: false,
          whisperNotInstalled: isWhisperMissing,
          error: isWhisperMissing
              ? 'openai-whisper가 설치되지 않았습니다.\n'
                  '설치 명령: pip install openai-whisper\n'
                  '(첫 실행 시 모델 파일도 자동 다운로드됩니다)'
              : errMsg,
        );
      }

      // 성공 응답
      final text = (json['text'] as String?) ?? '';
      final rawSegments = (json['segments'] as List<dynamic>?) ?? [];
      final segments = rawSegments
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();


      return LocalTranscriptionResult(
        text: text,
        success: true,
        segments: segments,
      );
    } on ProcessException catch (e) {
      if (e.message.contains('No such file') ||
          e.errorCode == 2) {
        return LocalTranscriptionResult(
          text: '',
          success: false,
          pythonNotFound: true,
          error: 'Python 실행 파일을 찾을 수 없습니다: $pythonPath\n'
              'Python이 설치되어 있는지 확인하거나 설정에서 Python 경로를 지정해주세요.',
        );
      }
      return LocalTranscriptionResult(
        text: '',
        success: false,
        error: '프로세스 실행 오류: ${e.message}',
      );
    } catch (e) {
      return LocalTranscriptionResult(
        text: '',
        success: false,
        error: '전사 실패: $e',
      );
    }
  }

  /// stdout에서 JSON 객체 줄 추출 ({"text": ...} 또는 {"error": ...})
  static String? _extractJsonLine(String stdout) {
    final lines = stdout.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    for (final line in lines.toList().reversed) {
      if (line.startsWith('{') && line.endsWith('}')) {
        return line;
      }
    }
    return null;
  }

  /// 실행 파일 위치에서 상위 디렉터리를 탐색해 scripts/transcribe.py 경로 반환
  static String? _findScriptFromDir(String startDir, int maxDepth) {
    var dir = Directory(startDir);
    for (var i = 0; i < maxDepth; i++) {
      final candidate = '${dir.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}transcribe.py';
      if (File(candidate).existsSync()) return candidate;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
