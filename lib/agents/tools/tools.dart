// lib/agents/tools/tools.dart
// v1 서비스들을 AgentTool 인터페이스로 래핑한 8개 툴 구현체
//
// 각 툴은 v1 서비스를 직접 수정하지 않고 '감싸는' 어댑터 패턴 사용.
// v1 서비스가 없는 환경에서도 컴파일되도록 TODO 주석으로 import 처리.

import 'tool_interface.dart';

// TODO: v1 서비스 import (Phase 1 후반 — 서비스 파일 경로 확인 후 활성화)
// import '../../src/services/whisper_service.dart';
// import '../../src/services/claude_api_service.dart';
// import '../../src/services/hive_service.dart';
// import '../../src/services/python_bridge.dart';

// ═══════════════════════════════════════════════════════
// 1. TranscribeTool — 음성/영상 → 텍스트 전사
//    v1 연결: WhisperService.transcribe()
// ═══════════════════════════════════════════════════════
class TranscribeTool extends AgentTool {
  // final WhisperService _whisper; // TODO 활성화
  // TranscribeTool(this._whisper);
  TranscribeTool();

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
    // TODO: 실제 WhisperService 호출로 교체
    // final result = await _whisper.transcribe(
    //   filePath: input['filePath'],
    //   language: input['language'] ?? 'ko',
    // );
    // return ToolResult.ok({'transcript': result.text, 'duration': result.durationSeconds}, elapsed);

    await Future.delayed(const Duration(milliseconds: 200));
    return ToolResult(
      success: true,
      output: {
        'transcript': '[전사 결과] 안녕하세요. 오늘 면담을 시작하겠습니다...',
        'duration': 3600,
        'language': input['language'] ?? 'ko',
        'filePath': input['filePath'],
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// 2. ExtractPdfTool — PDF → 텍스트 추출
//    v1 연결: PythonBridge.runScript('extract_pdf.py')
// ═══════════════════════════════════════════════════════
class ExtractPdfTool extends AgentTool {
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
    // TODO: await PythonBridge.run('extract_pdf.py', [input['filePath']]);
    await Future.delayed(const Duration(milliseconds: 100));
    return ToolResult(success: true, output: {
      'transcript': '[PDF 추출] 문서 내용...',
      'pageCount': 10,
      'filePath': input['filePath'],
    });
  }
}

// ═══════════════════════════════════════════════════════
// 3. ExtractDocxTool — DOCX → 텍스트 추출
//    v1 연결: PythonBridge.runScript('extract_docx.py')
// ═══════════════════════════════════════════════════════
class ExtractDocxTool extends AgentTool {
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
    // TODO: await PythonBridge.run('extract_docx.py', [input['filePath']]);
    await Future.delayed(const Duration(milliseconds: 100));
    return ToolResult(success: true, output: {
      'transcript': '[DOCX 추출] 문서 내용...',
      'filePath': input['filePath'],
    });
  }
}

// ═══════════════════════════════════════════════════════
// 4. SummarizeTool — 텍스트 → AI 요약
//    v1 연결: ClaudeApiService.summarize()
// ═══════════════════════════════════════════════════════
class SummarizeTool extends AgentTool {
  // final ClaudeApiService _claude; // TODO 활성화
  // SummarizeTool(this._claude);
  SummarizeTool();

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
    // TODO: 실제 ClaudeApiService 호출로 교체
    // final result = await _claude.summarize(
    //   text: input['text'],
    //   type: input['summaryType'] ?? 'brief',
    // );
    await Future.delayed(const Duration(milliseconds: 300));
    return const ToolResult(success: true, output: {
      'summary': '[AI 요약] 이 기록은 구술자의 생애 초기 경험에 관한 내용입니다.',
      'keywords': ['생애사', '유년기', '가족'],
      'period': '1950년대',
    });
  }
}

// ═══════════════════════════════════════════════════════
// 5. TagTool — 텍스트/요약 → 자동 태그 생성
//    v1 연결: ClaudeApiService.generateTags()
// ═══════════════════════════════════════════════════════
class TagTool extends AgentTool {
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
    // TODO: ClaudeApiService.generateTags(input['text'])
    await Future.delayed(const Duration(milliseconds: 200));
    return const ToolResult(success: true, output: {
      'tags': ['생애사', '구술', '면담', '1950년대'],
    });
  }
}

// ═══════════════════════════════════════════════════════
// 6. LinkPersonTool — 텍스트에서 인물 추출 → 인물사전 연결
//    v1 연결: HiveService.findOrCreatePerson()
// ═══════════════════════════════════════════════════════
class LinkPersonTool extends AgentTool {
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
    // TODO: HiveService.findOrCreatePerson(extractedNames)
    await Future.delayed(const Duration(milliseconds: 150));
    return const ToolResult(success: true, output: {
      'linkedPersonIds': <String>[],
      'newPersons': <Map<String, dynamic>>[],
    });
  }
}

// ═══════════════════════════════════════════════════════
// 7. SaveRecordTool — 처리된 기록 → Hive DB 저장
//    v1 연결: HiveService.saveRecord()
// ═══════════════════════════════════════════════════════
class SaveRecordTool extends AgentTool {
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
    // TODO: HiveService.saveRecord(OralRecord.fromMap(input))
    final now = DateTime.now();
    final recordId =
        'REC-${now.year}${now.month.toString().padLeft(2, '0')}-'
        '${now.millisecondsSinceEpoch.toString().substring(8)}';

    await Future.delayed(const Duration(milliseconds: 100));
    return ToolResult(success: true, output: {
      'recordId': recordId,
      'savedAt': now.toIso8601String(),
    });
  }
}

// ═══════════════════════════════════════════════════════
// 8. SearchTool — Hive DB 기록 검색
//    v1 연결: HiveService.searchRecords()
// ═══════════════════════════════════════════════════════
class SearchTool extends AgentTool {
  @override
  String get name => 'search';

  @override
  String get description =>
      '구술 기록을 키워드·인물·날짜·태그로 검색합니다.';

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
    // TODO: HiveService.searchRecords(query: input['query'], ...)
    await Future.delayed(const Duration(milliseconds: 100));
    return ToolResult(success: true, output: {
      'results': <Map<String, dynamic>>[],
      'total': 0,
      'query': input['query'],
    });
  }
}

// ═══════════════════════════════════════════════════════
// 9. ExportTool — 기록 → CSV/JSON 내보내기
//    v1 연결: ExportService.export()
// ═══════════════════════════════════════════════════════
class ExportTool extends AgentTool {
  @override
  String get name => 'export';

  @override
  String get description =>
      '선택한 기록들을 CSV 또는 JSON 형식으로 내보냅니다.';

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
    // TODO: ExportService.export(format: input['format'], ids: input['recordIds'])
    final format = input['format'] ?? 'csv';
    final now = DateTime.now();
    final fileName =
        'export_${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.$format';

    await Future.delayed(const Duration(milliseconds: 150));
    return ToolResult(success: true, output: {
      'filePath': 'C:\\Users\\OralRecordAgent\\exports\\$fileName',
      'recordCount': 0,
      'format': format,
    });
  }
}

// ═══════════════════════════════════════════════════════
// 10. GenerateDocTool — 기록 → 책/보고서 자동 생성
//     v1 연결: PythonBridge.runScript('create_docx.py')
// ═══════════════════════════════════════════════════════
class GenerateDocTool extends AgentTool {
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
          required: true,
        ),
        const ToolParam(
          name: 'recordIds',
          type: 'list',
          description: '포함할 기록 ID 목록',
          required: true,
        ),
        const ToolParam(
          name: 'title',
          type: 'string',
          description: '문서 제목',
        ),
      ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> input) async {
    // TODO: PythonBridge.run('create_docx.py', [input['docType'], ...])
    final docType = input['docType'] ?? 'report';
    final title = input['title'] ?? '구술기록 $docType';

    await Future.delayed(const Duration(milliseconds: 500));
    return ToolResult(success: true, output: {
      'filePath':
          'C:\\Users\\OralRecordAgent\\outputs\\$title.docx',
      'docType': docType,
      'pageCount': 0,
    });
  }
}
