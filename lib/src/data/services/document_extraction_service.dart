// 파일 목적: Python 스크립트로 PDF/DOCX 텍스트 추출
// scripts/extract_pdf.py  → pdfplumber
// scripts/extract_docx.py → python-docx
// LocalTranscriptionService와 동일한 구조 사용

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class DocumentExtractionResult {
  final String text;
  final bool success;
  final String? error;
  final String extractionMethod;
  final int charCount;

  const DocumentExtractionResult({
    required this.text,
    required this.success,
    this.error,
    this.extractionMethod = 'text_layer',
    this.charCount = 0,
  });
}

class DocumentExtractionService {
  /// PDF 또는 DOCX 파일에서 텍스트 추출
  static Future<DocumentExtractionResult> extractText({
    required String filePath,
    String pythonPath = 'python',
    String? scriptDir,
  }) async {
    final ext = filePath.split('.').last.toLowerCase();

    // TXT: Python 불필요, Dart에서 직접 읽기
    if (ext == 'txt') {
      try {
        final text = await File(filePath).readAsString();
        return DocumentExtractionResult(text: text, success: true);
      } catch (e) {
        return DocumentExtractionResult(
          text: '',
          success: false,
          error: 'TXT 파일 읽기 실패: $e',
        );
      }
    }

    if (ext != 'pdf' && ext != 'docx') {
      return const DocumentExtractionResult(
        text: '',
        success: false,
        error: 'PDF, DOCX, TXT 파일만 지원합니다.',
      );
    }

    final scriptName = ext == 'pdf' ? 'extract_pdf.py' : 'extract_docx.py';
    final scriptPath = _findScript(scriptDir, scriptName);

    if (scriptPath == null) {
      return DocumentExtractionResult(
        text: '',
        success: false,
        error: 'scripts/$scriptName 파일을 찾을 수 없습니다. 프로젝트 루트의 scripts/ 디렉터리를 확인해주세요.',
      );
    }


    try {
      final env = Map<String, String>.from(Platform.environment)
        ..['PYTHONIOENCODING'] = 'utf-8'
        ..['PYTHONUTF8'] = '1';

      final result = await Process.run(
        pythonPath,
        [scriptPath, filePath],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
        runInShell: Platform.isWindows,
        environment: env,
      ).timeout(
        const Duration(minutes: 2),
        onTimeout: () => ProcessResult(-1, 1, '', '타임아웃: 텍스트 추출에 2분 이상 소요됩니다.'),
      );

      if (result.stderr.toString().isNotEmpty) {
      }

      final stdout = result.stdout.toString().trim();

      if (result.exitCode == -1 ||
          result.stderr.toString().contains('is not recognized') ||
          result.stderr.toString().contains('No such file or directory')) {
        return const DocumentExtractionResult(
          text: '',
          success: false,
          error: 'Python을 찾을 수 없습니다. 설정에서 Python 경로를 확인해주세요.',
        );
      }

      if (stdout.isEmpty) {
        return DocumentExtractionResult(
          text: '',
          success: false,
          error: '스크립트가 결과를 반환하지 않았습니다.\nstderr: ${result.stderr.toString().take(200)}',
        );
      }

      // stdout에서 JSON 줄 찾기
      String? jsonLine;
      for (final line in stdout.split('\n').map((l) => l.trim()).toList().reversed) {
        if (line.startsWith('{') && line.endsWith('}')) {
          jsonLine = line;
          break;
        }
      }

      if (jsonLine == null) {
        return DocumentExtractionResult(
          text: '',
          success: false,
          error: '결과 파싱 실패: ${stdout.take(300)}',
        );
      }

      final Map<String, dynamic> json;
      try {
        json = jsonDecode(jsonLine) as Map<String, dynamic>;
      } catch (e) {
        return DocumentExtractionResult(
          text: '',
          success: false,
          error: 'JSON 파싱 오류: $e',
        );
      }

      if (json.containsKey('error')) {
        final errMsg = json['error'] as String;
        return DocumentExtractionResult(text: '', success: false, error: errMsg);
      }

      final text = (json['text'] as String?) ?? '';
      final extractionMethod = (json['extraction_method'] as String?) ?? 'text_layer';
      final charCount = (json['char_count'] as int?) ?? text.length;
      return DocumentExtractionResult(
        text: text,
        success: true,
        extractionMethod: extractionMethod,
        charCount: charCount,
      );
    } on ProcessException catch (e) {
      return DocumentExtractionResult(
        text: '',
        success: false,
        error: '프로세스 실행 오류: ${e.message}',
      );
    } catch (e) {
      return DocumentExtractionResult(
        text: '',
        success: false,
        error: '추출 실패: $e',
      );
    }
  }

  static String? _findScript(String? scriptDir, String scriptName) {
    if (scriptDir != null) {
      final p = '$scriptDir${Platform.pathSeparator}$scriptName';
      if (File(p).existsSync()) return p;
    }
    // 개발 모드: 프로젝트 루트 기준
    final devPath =
        '${Directory.current.path}${Platform.pathSeparator}scripts${Platform.pathSeparator}$scriptName';
    if (File(devPath).existsSync()) return devPath;

    // 빌드 모드: 실행파일 상위 탐색
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

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
