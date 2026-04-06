// lib/agents/tools/tools.dart
// v1 서비스들을 AgentTool 인터페이스로 래핑한 10개 툴 구현체
//
// 각 툴은 ToolServices를 선택적으로 받음.
// services == null (또는 해당 필드 null) → 스텁 모드 (테스트/미리보기용)
// services 주입 시 → v1 실제 서비스 호출

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../src/data/models/record.dart';
import '../../src/data/models/narrator.dart';
import '../../src/data/models/search_filters.dart';
import '../../src/data/services/local_transcription_service.dart';
import '../core/agent_system_prompt.dart';
import '../../src/data/services/document_extraction_service.dart';
import '../../src/data/services/import_export_service.dart';
import 'tool_interface.dart';
import 'tool_services.dart';

// ─── 경로 보조 ───────────────────────────────────────────
/// 상대 경로를 절대 경로로 변환한다.
/// 이미 절대 경로이면 그대로 반환.
/// 상대 경로이면 순서대로 후보를 탐색:
///   1. 홈 디렉터리 (USERPROFILE / HOME)
///   2. 현재 작업 디렉터리
/// 첫 번째로 파일이 실제 존재하는 후보를 반환하고,
/// 없으면 홈 디렉터리 기준 경로를 반환한다 (오류는 서비스에서 처리).
String _resolveFilePath(String path) {
  if (path.isEmpty) return path;
  // 이미 절대 경로
  if (File(path).isAbsolute) return path;

  final homeDir = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      '';
  final sep = Platform.pathSeparator;

  // 한국어 폴더명 → 영어 실제 폴더명 매핑 (Windows 셸 표시명 ≠ 실제 경로)
  const korFolderMap = <String, String>{
    '다운로드': 'Downloads',
    '문서': 'Documents',
    '바탕 화면': 'Desktop',
    '바탕화면': 'Desktop',
    '사진': 'Pictures',
    '음악': 'Music',
    '동영상': 'Videos',
  };
  String normPath = path;
  for (final entry in korFolderMap.entries) {
    normPath = normPath.replaceFirst(entry.key, entry.value);
  }

  final candidates = [
    if (homeDir.isNotEmpty && normPath != path) '$homeDir$sep$normPath',
    if (homeDir.isNotEmpty) '$homeDir$sep$path',
    '${Directory.current.path}$sep$path',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  // 기본: 홈 디렉터리 기준 (파일 없어도 서비스에서 에러 처리)
  return candidates.isNotEmpty ? candidates.first : path;
}

/// Documents/OralRecordAgent/outputs 폴더 경로 반환
String _outputsDir() {
  final home = Platform.environment['USERPROFILE'] ??
      Platform.environment['HOME'] ??
      Directory.current.path;
  return '$home${Platform.pathSeparator}Documents'
      '${Platform.pathSeparator}OralRecordAgent'
      '${Platform.pathSeparator}outputs';
}

/// 산출물 파일명 생성: {YYYYMMDD_HHmmss}_{suffix}.{ext}
String _outputFileName(DateTime now, String suffix, String ext) {
  final y = now.year.toString();
  final mo = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final h = now.hour.toString().padLeft(2, '0');
  final mi = now.minute.toString().padLeft(2, '0');
  final s = now.second.toString().padLeft(2, '0');
  return '${y}${mo}${d}_${h}${mi}${s}_$suffix.$ext';
}

// ═══════════════════════════════════════════════════════
// 1. TranscribeTool — 음성/영상 → 텍스트 전사
//    v1 연결: LocalTranscriptionService.transcribeFile()
// ═══════════════════════════════════════════════════════
class TranscribeTool extends AgentTool {
  final ToolServices? _services;
  TranscribeTool([this._services]);

  @override
  String get name => 'transcribe';

  @override
  String get description =>
      '음성 또는 영상 파일을 텍스트로 전사합니다. '
      'Whisper 로컬 모델을 사용하며 한국어를 지원합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'filePath',
          type: 'string',
          description: '전사할 파일의 절대 경로 (.mp3/.mp4/.wav/.m4a/.webm/.mov)',
          required: true,
        ),
        const ToolParam(
          name: 'language',
          type: 'string',
          description: '언어 코드 (기본값: ko)',
          defaultValue: 'ko',
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final filePath = _resolveFilePath(input['filePath'] as String);
    final language = input['language'] as String? ?? 'ko';

    if (_services == null) {
      return ToolResult(success: true, output: {
        'transcript': '[전사 결과] 안녕하세요. 오늘 면담을 시작하겠습니다...',
        'duration': 3600,
        'language': language,
        'filePath': filePath,
      });
    }

    final result = await LocalTranscriptionService.transcribeFile(
      filePath: filePath,
      pythonPath: _services!.pythonPath,
      model: _services!.whisperModel,
      language: language.isEmpty ? _services!.transcriptionLanguage : language,
      timeoutMinutes: _services!.transcribeTimeoutMinutes,
    );

    if (!result.success) {
      return ToolResult(success: false, errorMessage: result.error ?? '전사 실패');
    }

    return ToolResult(success: true, output: {
      'transcript': result.text,
      'language': language,
      'filePath': filePath,
      'segments': result.segments,
    });
  }
}

// ═══════════════════════════════════════════════════════
// 2. ExtractPdfTool — PDF → 텍스트 추출
//    v1 연결: DocumentExtractionService.extractText()
// ═══════════════════════════════════════════════════════
class ExtractPdfTool extends AgentTool {
  final ToolServices? _services;
  ExtractPdfTool([this._services]);

  @override
  String get name => 'extract_pdf';

  @override
  String get description => 'PDF 파일에서 텍스트를 추출합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'filePath',
          type: 'string',
          description: '추출할 PDF 파일의 절대 경로',
          required: true,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final filePath = _resolveFilePath(input['filePath'] as String);

    if (_services == null) {
      return ToolResult(success: true, output: {
        'transcript': '[PDF 추출] 문서 내용...',
        'extractionMethod': 'text_layer',
        'charCount': 20,
        'filePath': filePath,
      });
    }

    final result = await DocumentExtractionService.extractText(
      filePath: filePath,
      pythonPath: _services!.pythonPath,
    );

    if (!result.success) {
      return ToolResult(success: false, errorMessage: result.error ?? 'PDF 추출 실패');
    }

    final method = result.extractionMethod;
    final charCount = result.charCount;
    return ToolResult(success: true, output: {
      'transcript': result.text,
      'extractionMethod': method,
      'charCount': charCount,
      'filePath': filePath,
    });
  }
}

// ═══════════════════════════════════════════════════════
// 2b. ExtractImageTool — 이미지 → OCR 텍스트 추출
//     v1 연결: Python pytesseract (scripts/extract_image.py)
// ═══════════════════════════════════════════════════════
class ExtractImageTool extends AgentTool {
  final ToolServices? _services;
  ExtractImageTool([this._services]);

  @override
  String get name => 'extract_image';

  @override
  String get description =>
      '이미지 파일(jpg/png 등)에서 OCR로 텍스트를 추출합니다. '
      'Tesseract를 사용하며 한국어+영어를 지원합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'filePath',
          type: 'string',
          description: '추출할 이미지 파일의 절대 경로 (.jpg/.jpeg/.png/.bmp/.tiff/.webp)',
          required: true,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final filePath = _resolveFilePath(input['filePath'] as String);

    if (_services == null) {
      return ToolResult(success: true, output: {
        'transcript': '[이미지 OCR] 이미지에서 추출된 텍스트...',
        'extractionMethod': 'ocr',
        'charCount': 20,
        'filePath': filePath,
      });
    }

    try {
      final scriptDir = Directory.current.path;
      final scriptPath =
          '$scriptDir${Platform.pathSeparator}scripts${Platform.pathSeparator}extract_image.py';

      // stdoutEncoding: utf8 — Python 스크립트가 UTF-8로 출력하므로 강제 지정
      // (Windows 기본 systemEncoding이 CP949일 경우 한글이 깨짐)
      final result = await Process.run(
        _services!.pythonPath,
        [scriptPath, filePath],
        runInShell: Platform.isWindows,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(minutes: 2));

      if (result.exitCode != 0) {
        return ToolResult(
          success: false,
          errorMessage: '이미지 OCR 실패: ${result.stderr}',
        );
      }

      final stdout = result.stdout as String;
      final start = stdout.indexOf('{');
      final end = stdout.lastIndexOf('}');

      // JSON 파싱 성공 경로
      if (start >= 0 && end > start) {
        try {
          final parsed =
              jsonDecode(stdout.substring(start, end + 1)) as Map<String, dynamic>;
          if (parsed['success'] == false) {
            return ToolResult(
              success: false,
              errorMessage: parsed['error'] as String? ?? 'OCR 실패',
            );
          }
          return ToolResult(success: true, output: {
            'transcript': parsed['text'] as String? ?? '',
            'extractionMethod': 'ocr',
            'charCount': parsed['char_count'] as int? ?? 0,
            'filePath': filePath,
          });
        } catch (_) {
          // JSON 파싱 실패 시 stdout 원문을 텍스트로 fallback
        }
      }

      // Fallback: stdout 전체를 텍스트로 사용
      final rawText = stdout.trim();
      return ToolResult(success: true, output: {
        'transcript': rawText,
        'extractionMethod': 'ocr_raw',
        'charCount': rawText.length,
        'filePath': filePath,
      });
    } catch (e) {
      return ToolResult(success: false, errorMessage: '이미지 OCR 실패: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// 3. ExtractDocxTool — DOCX → 텍스트 추출
//    v1 연결: DocumentExtractionService.extractText()
// ═══════════════════════════════════════════════════════
class ExtractDocxTool extends AgentTool {
  final ToolServices? _services;
  ExtractDocxTool([this._services]);

  @override
  String get name => 'extract_docx';

  @override
  String get description => 'Word(.docx) 파일에서 텍스트를 추출합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'filePath',
          type: 'string',
          description: '추출할 DOCX 파일의 절대 경로',
          required: true,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final filePath = _resolveFilePath(input['filePath'] as String);

    if (_services == null) {
      return ToolResult(success: true, output: {
        'transcript': '[DOCX 추출] 문서 내용...',
        'filePath': filePath,
      });
    }

    final result = await DocumentExtractionService.extractText(
      filePath: filePath,
      pythonPath: _services!.pythonPath,
    );

    if (!result.success) {
      return ToolResult(success: false, errorMessage: result.error ?? 'DOCX 추출 실패');
    }

    return ToolResult(success: true, output: {
      'transcript': result.text,
      'filePath': filePath,
    });
  }
}

// ═══════════════════════════════════════════════════════
// 3-D. ExtractTextTool — .txt/.md/.csv 파일 텍스트 직접 읽기
// ═══════════════════════════════════════════════════════
class ExtractTextTool extends AgentTool {
  final ToolServices? _services;
  ExtractTextTool([this._services]);

  @override
  String get name => 'extract_text';

  @override
  String get description => '텍스트 파일(.txt, .md, .csv)에서 내용을 읽어옵니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'filePath',
          type: 'string',
          description: '읽을 텍스트 파일의 절대 경로 (.txt/.md/.csv)',
          required: true,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final filePath = _resolveFilePath(input['filePath'] as String);

    if (_services == null) {
      return ToolResult(success: true, output: {
        'transcript': '[텍스트 추출] 파일 내용...',
        'inputType': 'document',
        'filePath': filePath,
      });
    }

    final file = File(filePath);
    if (!await file.exists()) {
      return ToolResult(
          success: false, errorMessage: '파일을 찾을 수 없습니다: $filePath');
    }

    try {
      // UTF-8 시도
      final text = await file.readAsString(encoding: utf8);
      if (text.trim().isEmpty) {
        return ToolResult(success: false, errorMessage: '파일이 비어있습니다.');
      }
      return ToolResult(success: true, output: {
        'transcript': text,
        'charCount': text.length,
        'extractionMethod': 'text_read_utf8',
        'inputType': 'document',
        'filePath': filePath,
      });
    } catch (_) {
      // UTF-8 실패 → latin1 폴백 (EUC-KR 근사)
      try {
        final bytes = await file.readAsBytes();
        final text = latin1.decode(bytes);
        return ToolResult(success: true, output: {
          'transcript': text,
          'charCount': text.length,
          'extractionMethod': 'text_read_latin1',
          'inputType': 'document',
          'filePath': filePath,
        });
      } catch (e2) {
        return ToolResult(
            success: false,
            errorMessage: '파일 읽기 실패: 인코딩을 확인해주세요. ($e2)');
      }
    }
  }
}

// ═══════════════════════════════════════════════════════
// 4. SummarizeTool — 텍스트 → AI 요약
//    v1 연결: Claude API 직접 HTTP 호출
// ═══════════════════════════════════════════════════════
class SummarizeTool extends AgentTool {
  final ToolServices? _services;
  SummarizeTool([this._services]);

  @override
  String get name => 'summarize';

  @override
  String get description =>
      '구술 텍스트를 분석하여 핵심 내용 요약, 주요 키워드, '
      '시대적 맥락을 추출합니다. Claude API를 사용합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'text',
          type: 'string',
          description: '요약할 텍스트 (전사 결과 또는 입력 텍스트)',
          required: true,
        ),
        const ToolParam(
          name: 'summaryType',
          type: 'string',
          description: '요약 유형: brief(단문) | detailed(상세) | academic(학술)',
          defaultValue: 'brief',
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final text = (input['text'] as String? ?? '').trim();
    final summaryType = input['summaryType'] as String? ?? 'brief';
    final apiKey = _services?.claudeApiKey;

    // 빈 텍스트 조기 반환
    if (text.isEmpty) {
      return const ToolResult(
        success: false,
        errorMessage: '요약할 텍스트가 없습니다. 콘텐츠가 있는 기록을 선택해주세요.',
      );
    }
    if (text.length < 10) {
      return ToolResult(
        success: false,
        errorMessage: '텍스트가 너무 짧습니다 (${text.length}자). 의미있는 요약을 생성할 수 없습니다.',
      );
    }

    if (apiKey == null || apiKey.isEmpty) {
      return const ToolResult(success: true, output: {
        'summary': '[AI 요약] 이 기록은 구술자의 생애 초기 경험에 관한 내용입니다.',
        'keywords': ['생애사', '유년기', '가족'],
        'period': '1950년대',
      });
    }

    try {
      const systemPrompt =
          '당신은 구술기록 전문 요약가입니다. 주어진 텍스트를 분석하여 '
          'JSON 형식으로만 응답하세요 (설명 없이):\n'
          '{"summary": "핵심 내용 요약", "keywords": ["키워드1", "키워드2"], "period": "시대적 맥락"}';

      final userContent = summaryType == 'detailed'
          ? '다음 구술 텍스트를 상세히 요약해주세요:\n\n$text'
          : summaryType == 'academic'
              ? '다음 구술 텍스트를 학술적으로 분석·요약해주세요:\n\n$text'
              : '다음 구술 텍스트를 간결하게 요약해주세요:\n\n$text';

      final response = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5-20251001',
              'max_tokens': 512,
              'system': systemPrompt,
              'messages': [
                {'role': 'user', 'content': userContent},
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return ToolResult(
            success: false,
            errorMessage: 'Claude API 오류: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final responseText =
          (body['content'] as List).first['text'] as String;

      final start = responseText.indexOf('{');
      final end = responseText.lastIndexOf('}');

      // JSON 파싱 시도, 실패 시 raw 텍스트를 요약으로 fallback
      Map<String, dynamic>? parsed;
      if (start != -1 && end != -1) {
        try {
          parsed = jsonDecode(responseText.substring(start, end + 1))
              as Map<String, dynamic>;
        } catch (_) {
          // JSON 파싱 실패 → fallback
        }
      }

      return ToolResult(success: true, output: {
        'summary': parsed?['summary'] as String? ??
            responseText.trim(),
        'keywords': (parsed?['keywords'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        'period': parsed?['period'] as String? ?? '',
      });
    } catch (e) {
      return ToolResult(success: false, errorMessage: '요약 실패: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// 5. TagTool — 텍스트/요약 → 자동 태그 생성
//    v1 연결: Claude API 직접 HTTP 호출
// ═══════════════════════════════════════════════════════
class TagTool extends AgentTool {
  final ToolServices? _services;
  TagTool([this._services]);

  @override
  String get name => 'tag';

  @override
  String get description =>
      '기록 내용을 분석하여 분류 태그를 자동 생성합니다. '
      '주제, 시대, 지역, 인물 유형 태그를 포함합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'text',
          type: 'string',
          description: '태그를 생성할 텍스트 (요약 또는 전사본)',
          required: true,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final text = input['text'] as String? ?? '';
    final apiKey = _services?.claudeApiKey;

    if (apiKey == null || apiKey.isEmpty) {
      return const ToolResult(success: true, output: {
        'tags': ['생애사', '구술', '면담', '1950년대'],
      });
    }

    try {
      const systemPrompt =
          '당신은 구술기록 분류 전문가입니다. '
          '텍스트를 분석하여 JSON 형식으로만 응답하세요 (설명 없이):\n'
          '{"tags": ["태그1", "태그2", "태그3"]}';

      final response = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': 'claude-haiku-4-5-20251001',
              'max_tokens': 256,
              'system': systemPrompt,
              'messages': [
                {'role': 'user', 'content': '다음 텍스트에 태그를 붙여주세요:\n\n$text'},
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return ToolResult(
            success: false,
            errorMessage: 'Claude API 오류: ${response.statusCode}');
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final responseText =
          (body['content'] as List).first['text'] as String;

      final start = responseText.indexOf('{');
      final end = responseText.lastIndexOf('}');
      if (start == -1 || end == -1) {
        return const ToolResult(success: false, errorMessage: '태그 응답 파싱 실패');
      }

      final parsed =
          jsonDecode(responseText.substring(start, end + 1)) as Map<String, dynamic>;

      return ToolResult(success: true, output: {
        'tags': (parsed['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      });
    } catch (e) {
      return ToolResult(success: false, errorMessage: '태그 생성 실패: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// 6. LinkPersonTool — 텍스트에서 인물 추출 → 인물사전 연결
//    v1 연결: NarratorRepository.getAllNarrators() + 이름 매칭
// ═══════════════════════════════════════════════════════
class LinkPersonTool extends AgentTool {
  final ToolServices? _services;
  LinkPersonTool([this._services]);

  @override
  String get name => 'link_person';

  @override
  String get description =>
      '기록 텍스트에서 구술자·면담자 이름을 추출하고 '
      '인물사전에 자동 연결하거나 새 항목을 생성합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'text',
          type: 'string',
          description: '인물을 추출할 텍스트',
          required: true,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final narratorRepo = _services?.narratorRepo;

    if (narratorRepo == null) {
      return const ToolResult(success: true, output: {
        'linkedPersonIds': <String>[],
        'newPersons': <Map<String, dynamic>>[],
      });
    }

    final text = input['text'] as String? ?? '';

    // 한국어 이름 패턴으로 후보 추출 (2~4글자 한국어)
    final namePattern = RegExp(r'[가-힣]{2,4}');
    final candidates = namePattern
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toSet()
        .toList();

    final allNarrators = await narratorRepo.getAllNarrators();
    final narratorByName = <String, Narrator>{
      for (final n in allNarrators) n.name: n,
    };

    final linkedIds = <String>[];
    final newPersons = <Map<String, dynamic>>[];

    for (final name in candidates) {
      if (narratorByName.containsKey(name)) {
        linkedIds.add(narratorByName[name]!.id);
      }
    }

    return ToolResult(success: true, output: {
      'linkedPersonIds': linkedIds,
      'newPersons': newPersons,
    });
  }
}

// ═══════════════════════════════════════════════════════
// 6b. CheckDuplicateTool — 파일 해시로 중복 등록 여부 확인
//     파일 드롭 직후 첫 번째로 실행 → 중복이면 즉시 중단
// ═══════════════════════════════════════════════════════
class CheckDuplicateTool extends AgentTool {
  final ToolServices? _services;
  CheckDuplicateTool([this._services]);

  @override
  String get name => 'check_duplicate';

  @override
  String get description => '파일 SHA-256 해시로 중복 등록 여부를 확인합니다. '
      '중복이면 success=false, output.isDuplicate=true를 반환합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'filePath',
          type: 'string',
          description: '확인할 파일의 절대 경로',
          required: true,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final filePath = _resolveFilePath(input['filePath'] as String);

    if (_services?.recordRepo == null) {
      return ToolResult(success: true, output: {
        'isDuplicate': false,
        'fileHash': 'stub-hash',
      });
    }

    try {
      final bytes = await File(filePath).readAsBytes();
      final fileHash = sha256.convert(bytes).toString();
      final existing = await _services!.recordRepo!.findByFileHash(fileHash);

      if (existing != null) {
        return ToolResult(success: false, output: {
          'isDuplicate': true,
          'filePath': filePath,
          'existingRecordId': existing.id,
          'existingTitle': existing.title,
          'existingDisplayId': existing.displayId,
          'existingDate': existing.createdAt.toIso8601String(),
          'fileHash': fileHash,
        }, errorMessage:
            '이미 등록된 파일이에요.\n기존 기록: ${existing.title} (${existing.displayId ?? existing.id})\n등록일: ${existing.createdAt.toString().substring(0, 10)}');
      }

      return ToolResult(success: true, output: {
        'isDuplicate': false,
        'fileHash': fileHash,
      });
    } catch (_) {
      // 해시 계산 실패 → 중복 체크 건너뜀 (성공으로 처리)
      return ToolResult(success: true, output: {
        'isDuplicate': false,
        'fileHash': null,
      });
    }
  }
}

// ═══════════════════════════════════════════════════════
// 7. SaveRecordTool — 처리된 기록 → Hive DB 저장
//    v1 연결: RecordRepository.createRecord()
// ═══════════════════════════════════════════════════════
class SaveRecordTool extends AgentTool {
  final ToolServices? _services;
  SaveRecordTool([this._services]);

  @override
  String get name => 'save_record';

  @override
  String get description =>
      '처리 완료된 구술 기록을 로컬 데이터베이스에 저장합니다. '
      '고유 식별자(REC-YYYYMM-XXXX)를 자동 생성합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'transcript',
          type: 'string',
          description: '전사 텍스트',
        ),
        const ToolParam(
          name: 'summary',
          type: 'string',
          description: 'AI 요약',
        ),
        const ToolParam(
          name: 'tags',
          type: 'list',
          description: '분류 태그 목록',
        ),
        const ToolParam(
          name: 'filePath',
          type: 'string',
          description: '원본 파일 경로',
        ),
        const ToolParam(
          name: 'narratorId',
          type: 'string',
          description: '구술자 ID (인물사전)',
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final now = DateTime.now();

    if (_services?.recordRepo == null) {
      final recordId =
          'REC-${now.year}${now.month.toString().padLeft(2, '0')}-'
          '${now.millisecondsSinceEpoch.toString().substring(8)}';
      return ToolResult(success: true, output: {
        'recordId': recordId,
        'savedAt': now.toIso8601String(),
      });
    }

    final filePath = input['filePath'] as String?;
    final inputType = _inputTypeFromPath(filePath);
    final transcript = input['transcript'] as String? ?? '';
    final summary = input['summary'] as String?;
    final rawTags = input['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : <String>[];
    final narratorId = input['narratorId'] as String? ?? 'unknown';
    // check_duplicate 단계에서 미리 계산된 해시 사용 (강제 등록 시 null)
    final fileHash = input['fileHash'] as String?;

    // ── 업데이트 모드: 기존 기록 ID가 있으면 create 대신 update ──
    final updateRecordId = input['updateRecordId'] as String?;
    if (updateRecordId != null) {
      try {
        final existing = await _services!.recordRepo!.getRecord(updateRecordId);
        if (existing == null) {
          return ToolResult(success: false, errorMessage: '업데이트할 기록을 찾을 수 없습니다: $updateRecordId');
        }
        final newFileName = filePath != null
            ? p.basenameWithoutExtension(filePath)
            : null;
        final newTitle = (newFileName != null && newFileName.isNotEmpty)
            ? newFileName
            : existing.title;
        final updated = existing.copyWith(
          title: newTitle,
          originalFileName: filePath != null
              ? p.basename(filePath)
              : null,
          fileHash: fileHash,
          content: transcript.isNotEmpty ? transcript : null,
          summary: summary,
          tags: tags.isNotEmpty ? tags : null,
          createdAt: now,
          updatedAt: now,
        );
        await _services!.recordRepo!.updateRecord(updateRecordId, updated);
        return ToolResult(success: true, output: {
          'recordId': updateRecordId,
          'displayId': existing.displayId,
          'oldTitle': existing.title,
          'newTitle': newTitle,
          'savedAt': now.toIso8601String(),
          'wasUpdate': true,
        });
      } catch (e) {
        return ToolResult(success: false, errorMessage: '기록 업데이트 실패: $e');
      }
    }

    // ── 신규 등록 모드 ──
    final sessionId = 'agent-session-${now.millisecondsSinceEpoch}';
    final title = _buildTitle(filePath, narratorId, now);

    final record = Record(
      title: title,
      content: transcript,
      inputType: inputType,
      sessionId: sessionId,
      narratorId: narratorId,
      mainCategory: '기타',
      visibility: 'public',
      recordedBy: 'agent',
      summary: summary,
      tags: tags,
      originalFileName: filePath?.split(Platform.pathSeparator).last,
      fileHash: fileHash,
    );

    try {
      final id = await _services!.recordRepo!.createRecord(record);
      return ToolResult(success: true, output: {
        'recordId': id,
        'savedAt': now.toIso8601String(),
      });
    } catch (e) {
      return ToolResult(success: false, errorMessage: '기록 저장 실패: $e');
    }
  }

  String _inputTypeFromPath(String? path) {
    if (path == null) return 'text';
    final ext = path.split('.').last.toLowerCase();
    if (['mp3', 'wav', 'm4a', 'webm'].contains(ext)) return 'audio';
    if (['mp4', 'mov'].contains(ext)) return 'video';
    if (['pdf', 'docx', 'txt'].contains(ext)) return 'document';
    if (['jpg', 'jpeg', 'png', 'bmp', 'tiff', 'tif', 'webp'].contains(ext)) return 'image';
    return 'text';
  }

  String _buildTitle(String? filePath, String narratorId, DateTime now) {
    if (filePath != null && filePath.isNotEmpty) {
      // p.basenameWithoutExtension: / \ 모두 처리하며 확장자까지 제거
      final stem = p.basenameWithoutExtension(filePath);
      if (stem.isNotEmpty) {
        // 타임스탬프 패턴 제거: YYYYMMDD_HHmmss_ / YYYYMMDD_ 접두어
        final cleaned = stem
            .replaceFirst(RegExp(r'^\d{8}[_-]\d{6}[_-]?'), '')
            .replaceFirst(RegExp(r'^\d{8}[_-]'), '')
            .trim();
        return cleaned.isNotEmpty ? cleaned : stem;
      }
    }
    return '에이전트 기록 ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════
// 8. SearchTool — Hive DB 기록 검색
//    v1 연결: RecordRepository.searchRecords()
// ═══════════════════════════════════════════════════════
class SearchTool extends AgentTool {
  final ToolServices? _services;
  SearchTool([this._services]);

  @override
  String get name => 'search';

  @override
  String get description => '구술 기록을 키워드·인물·날짜·태그로 검색합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'query',
          type: 'string',
          description: '검색 키워드',
          required: true,
        ),
        const ToolParam(
          name: 'filterType',
          type: 'string',
          description: '필터 유형: all | narrator | interviewer | tag | date',
          defaultValue: 'all',
        ),
        const ToolParam(
          name: 'limit',
          type: 'number',
          description: '최대 결과 수 (기본: 20)',
          defaultValue: 20,
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final query = input['query'] as String? ?? '';

    if (_services?.recordRepo == null) {
      return ToolResult(success: true, output: {
        'results': <Map<String, dynamic>>[],
        'total': 0,
        'query': query,
      });
    }

    final limit = (input['limit'] as num?)?.toInt() ?? 20;

    try {
      final filters = SearchFilters(query: query, limit: limit);
      final records =
          await _services!.recordRepo!.searchRecords(filters);

      final results = records
          .map((r) => {
                'id': r.id,
                'displayId': r.displayId,
                'title': r.title,
                'summary': r.summary,
                'inputType': r.inputType,
                'mainCategory': r.mainCategory,
                'narratorId': r.narratorId,
                'createdAt': r.createdAt.toIso8601String(),
              })
          .toList();

      return ToolResult(success: true, output: {
        'results': results,
        'total': results.length,
        'query': query,
      });
    } catch (e) {
      return ToolResult(success: false, errorMessage: '검색 실패: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// 9. ExportTool — 기록 → CSV/JSON 내보내기
//    v1 연결: ImportExportService.exportAllJson() / exportRecordsCsv()
// ═══════════════════════════════════════════════════════
class ExportTool extends AgentTool {
  final ToolServices? _services;
  ExportTool([this._services]);

  @override
  String get name => 'export';

  @override
  String get description => '선택한 기록들을 CSV 또는 JSON 형식으로 내보냅니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'format',
          type: 'string',
          description: '내보내기 형식: csv | json',
          defaultValue: 'csv',
          required: true,
        ),
        const ToolParam(
          name: 'recordIds',
          type: 'list',
          description: '내보낼 기록 ID 목록 (비어있으면 전체)',
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final format = input['format'] as String? ?? 'csv';
    final now = DateTime.now();
    final fileName = _outputFileName(now, 'export', format);
    final outputType = 'export_$format';

    final outputsDirPath = _outputsDir();
    if (_services?.recordRepo == null) {
      final stubPath = '$outputsDirPath${Platform.pathSeparator}$fileName';
      return ToolResult(success: true, output: {
        'filePath': stubPath,
        'fileName': fileName,
        'fileSizeKb': 0,
        'outputsDir': outputsDirPath,
        'recordCount': 0,
        'format': format,
        'outputType': outputType,
      });
    }

    try {
      final allFilters = SearchFilters(limit: 999999);
      final records =
          await _services!.recordRepo!.searchRecords(allFilters);

      final rawIds = input['recordIds'];
      final filterIds = rawIds is List
          ? rawIds.map((e) => e.toString()).toSet()
          : null;
      final targetRecords = filterIds != null
          ? records.where((r) => filterIds.contains(r.id)).toList()
          : records;

      String content;
      if (format == 'json') {
        final narrators = await (_services?.narratorRepo
                ?.getAllNarrators() ??
            Future.value(<Narrator>[]));
        content = ImportExportService.exportAllJson(
            targetRecords, narrators, [], []);
      } else {
        content = ImportExportService.exportRecordsCsv(
          targetRecords,
          {},
          {},
          {},
          includeContent: false,
          includeSummary: true,
        );
      }

      // outputs 폴더에 파일 저장
      final outputDir = Directory(outputsDirPath);
      await outputDir.create(recursive: true);
      final filePath = '${outputDir.path}${Platform.pathSeparator}$fileName';
      await File(filePath).writeAsString(content, flush: true);

      int fileSizeKb = 0;
      try {
        fileSizeKb = (await File(filePath).length() / 1024).ceil();
      } catch (_) {}

      return ToolResult(success: true, output: {
        'filePath': filePath,
        'fileName': fileName,
        'fileSizeKb': fileSizeKb,
        'outputsDir': outputsDirPath,
        'recordCount': targetRecords.length,
        'format': format,
        'outputType': outputType,
      });
    } catch (e) {
      return ToolResult(success: false, errorMessage: '내보내기 실패: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════
// 10. GenerateDocTool — 기록 → 책/보고서 자동 생성
//     v1 연결: Process.run(python, ['scripts/create_docx.py', ...])
// ═══════════════════════════════════════════════════════
class GenerateDocTool extends AgentTool {
  final ToolServices? _services;
  GenerateDocTool([this._services]);

  @override
  String get name => 'generate_doc';

  @override
  String get description =>
      '구술 기록을 바탕으로 보고서, 생애사 책, 연구 자료를 자동 생성합니다.';

  @override
  List<ToolParam> get params => [
        const ToolParam(
          name: 'docType',
          type: 'string',
          description: '생성 유형: report(보고서) | book(생애사 책) | summary(요약집)',
          required: false,
          defaultValue: 'report',
        ),
        const ToolParam(
          name: 'recordIds',
          type: 'list',
          description: '포함할 기록 ID 목록',
          required: false,
          defaultValue: <String>[],
        ),
        const ToolParam(
          name: 'title',
          type: 'string',
          description: '문서 제목',
        ),
        const ToolParam(
          name: 'requirements',
          type: 'string',
          description: '사용자 요구사항 (분석 관점/방법론)',
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    final docType = input['docType'] as String? ?? 'report';
    final outputMode = input['outputType'] as String? ?? 'report';
    final title = input['title'] as String? ?? '구술기록 $docType';
    final requirements = input['requirements'] as String?;
    final now = DateTime.now();
    final fileName = _outputFileName(now, docType, 'docx');

    final outputsDir = _outputsDir();
    if (_services == null) {
      final stubPath = '$outputsDir${Platform.pathSeparator}$fileName';
      return ToolResult(success: true, output: {
        'filePath': stubPath,
        'fileName': fileName,
        'fileSizeKb': 0,
        'outputsDir': outputsDir,
        'docType': docType,
        'outputType': outputMode,
        'pageCount': 0,
      });
    }

    final rawIds = input['recordIds'];
    final recordIds = rawIds is List
        ? rawIds.map((e) => e.toString()).toList()
        : <String>[];

    // 기록 데이터 수집
    final records = <Record>[];
    if (_services?.recordRepo != null) {
      for (final id in recordIds) {
        final r = await _services!.recordRepo!.getRecord(id);
        if (r != null) records.add(r);
      }
    }

    // outputs 폴더에 파일 저장
    final outputDir = Directory(outputsDir);
    await outputDir.create(recursive: true);
    final outputPath = '${outputDir.path}${Platform.pathSeparator}$fileName';

    // ── 2단계 AI 분석 챕터 생성 ─────────────────────────
    String? aiAnalysisChapter;
    final apiKey = _services?.claudeApiKey;
    final timeoutMin = _services?.generateDocTimeoutMinutes ?? 3;
    final httpTimeout = Duration(seconds: timeoutMin * 60);

    final hasRequirements = requirements != null && requirements.isNotEmpty;
    if (apiKey != null && apiKey.isNotEmpty && (records.isNotEmpty || hasRequirements)) {
      // 입력 텍스트 수집 (기록당 최대 2000자, 전체 최대 8000자)
      var combinedText = records
          .where((r) => r.content.isNotEmpty || r.summary?.isNotEmpty == true)
          .map((r) {
            final parts = <String>['[${r.title}]'];
            if (r.summary?.isNotEmpty == true) parts.add(r.summary!);
            if (r.content.isNotEmpty) {
              final preview = r.content.length > 2000
                  ? r.content.substring(0, 2000)
                  : r.content;
              parts.add(preview);
            }
            return parts.join('\n');
          })
          .join('\n\n---\n\n');

      // 전체 8000자 초과 시 앞 8000자만 사용
      if (combinedText.length > 8000) {
        combinedText = combinedText.substring(0, 8000);
        _services?.onProgress?.call('안내', '텍스트가 길어 앞 8000자만 분석에 사용합니다.');
      }

      // 기록 없이 요구사항만으로 실행 시 안내
      if (records.isEmpty) {
        _services?.onProgress?.call('안내', '관련 구술 기록 없음 — 요구사항을 바탕으로 생성합니다.');
      }

      if (combinedText.isNotEmpty || hasRequirements) {
        try {
          final systemPrompt = DocModePrompt.fromMode(outputMode);

          final reqText = requirements != null && requirements.isNotEmpty
              ? '분석 요구사항: $requirements\n\n'
              : '';
          final userContent = combinedText.isNotEmpty
              ? '${reqText}다음 구술 기록들을 바탕으로 분석 보고서를 작성하세요:\n\n'
                '$combinedText'
              : '${reqText}관련 구술 기록이 없습니다. 위 요구사항만을 바탕으로 최대한 보고서를 작성하세요.\n'
                '작성한 보고서에 "※ 관련 구술 기록 없음 — 요구사항 기반 작성" 문구를 포함하세요.';

          // ── 1단계: 초안 생성 ────────────────────────────
          _services?.onProgress?.call('실행', '1/2단계: 보고서 초안 생성 중...');
          final draftStopwatch = Stopwatch()..start();
          Timer? draftProgressTimer;
          Timer? draftWarnTimer;

          draftProgressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
            final s = draftStopwatch.elapsed.inSeconds;
            _services?.onProgress?.call('실행', '1/2단계: 초안 생성 중... ($s초 경과)');
          });
          if (timeoutMin > 1) {
            draftWarnTimer = Timer(const Duration(minutes: 1), () {
              _services?.onProgress?.call('실행',
                  '⚠️ 1분 경과 — 보고서 생성 중 (최대 $timeoutMin분)\n'
                  '응답이 없으면 설정에서 대기 시간을 늘려보세요.');
            });
          }

          http.Response? draftResponse;
          try {
            draftResponse = await http
                .post(
                  Uri.parse('https://api.anthropic.com/v1/messages'),
                  headers: {
                    'Content-Type': 'application/json',
                    'x-api-key': apiKey,
                    'anthropic-version': '2023-06-01',
                  },
                  body: jsonEncode({
                    'model': 'claude-haiku-4-5-20251001',
                    'max_tokens': 2048,
                    'system': systemPrompt,
                    'messages': [
                      {'role': 'user', 'content': userContent},
                    ],
                  }),
                )
                .timeout(httpTimeout);
          } finally {
            draftProgressTimer.cancel();
            draftWarnTimer?.cancel();
          }

          if (draftResponse.statusCode == 200) {
            final body =
                jsonDecode(draftResponse.body) as Map<String, dynamic>;
            final draft =
                (body['content'] as List).first['text'] as String;

            // ── 2단계: 교정 ──────────────────────────────
            _services?.onProgress?.call('실행', '2/2단계: 문장 품질 검토 및 수정 중...');
            const reviewSystem = '당신은 전문 교정 편집자입니다. '
                '비문 수정, 어색한 표현 개선, 용어 일관성 확인을 수행합니다.';
            final reviewPrompt = '다음 보고서 초안을 검토하여 비문·어색한 표현을 수정하고 '
                '최종본만 출력하세요:\n\n$draft';

            http.Response? reviewResponse;
            try {
              reviewResponse = await http
                  .post(
                    Uri.parse('https://api.anthropic.com/v1/messages'),
                    headers: {
                      'Content-Type': 'application/json',
                      'x-api-key': apiKey,
                      'anthropic-version': '2023-06-01',
                    },
                    body: jsonEncode({
                      'model': 'claude-haiku-4-5-20251001',
                      'max_tokens': 2048,
                      'system': reviewSystem,
                      'messages': [
                        {'role': 'user', 'content': reviewPrompt},
                      ],
                    }),
                  )
                  .timeout(httpTimeout);
            } catch (_) {
              // 교정 실패 → 초안 그대로 사용
              reviewResponse = null;
            }

            if (reviewResponse != null && reviewResponse.statusCode == 200) {
              final rb =
                  jsonDecode(reviewResponse.body) as Map<String, dynamic>;
              aiAnalysisChapter =
                  (rb['content'] as List).first['text'] as String;
            } else {
              aiAnalysisChapter = draft;
            }
          }
        } on TimeoutException {
          _services?.onProgress?.call('안내',
              '⚠️ 보고서 생성 시간이 초과됐어요 ($timeoutMin분).\n'
              '설정 > 에이전트 설정에서 대기 시간을 늘리거나\n'
              '더 적은 기록으로 다시 시도해주세요.');
          // AI 챕터 없이 계속 진행 (기본 구조로 폴백)
        } catch (_) {
          // 기타 AI 생성 실패 → 기본 구조로 폴백
        }
      }
    }

    // create_docx.py 가 기대하는 chapters 구조로 변환
    final dateStr =
        '${now.year}년 ${now.month}월 ${now.day}일';
    final chapters = <Map<String, dynamic>>[];

    // 목차
    if (records.isNotEmpty) {
      final tocLines = records
          .asMap()
          .entries
          .map((e) => '${e.key + 2}. ${e.value.title}')
          .join('\n');
      chapters.add({
        'title': '목차',
        'content': '1. 개요\n$tocLines',
        'type': 'toc',
      });
    }

    // 개요
    final overviewParts = <String>[
      '생성일: $dateStr',
      '기록 수: ${records.length}건',
    ];
    if (requirements != null && requirements.isNotEmpty) {
      overviewParts.add('분석 요구사항: $requirements');
    }
    if (records.isNotEmpty) {
      overviewParts.add(
          '수록 기록:\n${records.map((r) => '  • ${r.title}').join('\n')}');
    }
    chapters.add({
      'title': '1. 개요',
      'content': overviewParts.join('\n\n'),
      'type': 'chapter',
    });

    // AI 분석 챕터 (2단계 생성 성공 시)
    if (aiAnalysisChapter != null && aiAnalysisChapter.isNotEmpty) {
      chapters.add({
        'title': '2. AI 분석',
        'content': aiAnalysisChapter,
        'type': 'chapter',
      });
    }

    // 기록별 챕터
    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      final parts = <String>[];

      if (r.summary?.isNotEmpty == true) {
        parts.add('요약');
        parts.add(r.summary!);
      }

      if (r.content.isNotEmpty) {
        parts.add('주요 내용');
        final preview = r.content.length > 3000
            ? '${r.content.substring(0, 3000)}...'
            : r.content;
        parts.add(preview);
      }

      final allTags = [...r.tags, ...r.keywordTags];
      if (allTags.isNotEmpty) {
        parts.add('태그: ${allTags.map((t) => '#$t').join(' ')}');
      }

      chapters.add({
        'title': '${i + 2}. ${r.title}',
        'content': parts.join('\n\n'),
        'type': 'chapter',
      });
    }

    final jsonData = jsonEncode({
      'docType': docType,
      'mode': outputMode,
      'title': title,
      'generatedAt': now.toIso8601String(),
      'chapters': chapters,
    });

    final tmpFile = File(
        '${outputDir.path}${Platform.pathSeparator}tmp_${now.millisecondsSinceEpoch}.json');
    await tmpFile.writeAsString(jsonData);

    try {
      final scriptDir = Directory.current.path;
      final scriptPath =
          '$scriptDir${Platform.pathSeparator}scripts${Platform.pathSeparator}create_docx.py';

      final result = await Process.run(
        _services!.pythonPath,
        [scriptPath, tmpFile.path, outputPath, '--mode', outputMode],
        runInShell: Platform.isWindows,
      ).timeout(const Duration(minutes: 5));

      try { await tmpFile.delete(); } catch (_) {}

      if (result.exitCode != 0) {
        return ToolResult(
          success: false,
          errorMessage: '문서 생성 실패: ${result.stderr}',
        );
      }

      int fileSizeKb = 0;
      try {
        fileSizeKb = (await File(outputPath).length() / 1024).ceil();
      } catch (_) {}

      return ToolResult(success: true, output: {
        'filePath': outputPath,
        'fileName': fileName,
        'fileSizeKb': fileSizeKb,
        'outputsDir': outputsDir,
        'docType': docType,
        'outputType': outputMode,
        'pageCount': records.length,
      });
    } catch (e) {
      try { await tmpFile.delete(); } catch (_) {}
      return ToolResult(success: false, errorMessage: '문서 생성 실패: $e');
    }
  }
}
