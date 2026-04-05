// test/agents/tools/tool_registry_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/agents/tools/tool_registry.dart';
import 'package:oral_record_agent/agents/tools/tools.dart';
import 'package:oral_record_agent/agents/tools/tool_interface.dart';

void main() {
  group('ToolRegistry', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry.standard();
    });

    test('standard() — 14개 툴 등록 확인', () {
      expect(registry.allNames.length, equals(14));
      expect(registry.has('transcribe'), isTrue);
      expect(registry.has('extract_pdf'), isTrue);
      expect(registry.has('extract_docx'), isTrue);
      expect(registry.has('extract_image'), isTrue);
      expect(registry.has('extract_text'), isTrue);
      expect(registry.has('check_duplicate'), isTrue);
      expect(registry.has('summarize'), isTrue);
      expect(registry.has('tag'), isTrue);
      expect(registry.has('link_person'), isTrue);
      expect(registry.has('save_record'), isTrue);
      expect(registry.has('search'), isTrue);
      expect(registry.has('smart_search'), isTrue);
      expect(registry.has('export'), isTrue);
      expect(registry.has('generate_doc'), isTrue);
    });

    test('get() — 없는 툴은 ArgumentError', () {
      expect(() => registry.get('nonexistent'), throwsArgumentError);
    });

    test('find() — 없는 툴은 null', () {
      expect(registry.find('nonexistent'), isNull);
    });

    test('run() — transcribe 실행 성공', () async {
      final result = await registry.run('transcribe', {
        'filePath': '/test/interview.mp3',
      });
      expect(result.success, isTrue);
      expect(result.output.containsKey('transcript'), isTrue);
    });

    test('run() — 필수 파라미터 누락 시 실패', () async {
      final result = await registry.run('transcribe', {}); // filePath 없음
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('filePath'));
    });

    test('preprocessToolFor() — 확장자별 툴 매핑', () {
      expect(registry.preprocessToolFor('interview.mp3'), equals('transcribe'));
      expect(registry.preprocessToolFor('video.mp4'), equals('transcribe'));
      expect(registry.preprocessToolFor('doc.pdf'), equals('extract_pdf'));
      expect(registry.preprocessToolFor('report.docx'), equals('extract_docx'));
      expect(registry.preprocessToolFor('unknown.xyz'), isNull);
    });

    test('supportsFile() — 지원 여부 확인', () {
      expect(registry.supportsFile('audio.mp3'), isTrue);
      expect(registry.supportsFile('video.mp4'), isTrue);
      expect(registry.supportsFile('document.pdf'), isTrue);
      expect(registry.supportsFile('image.png'), isTrue);
    });

    test('toClaudeTools() — Claude API 스키마 형식 확인', () {
      final schemas = registry.toClaudeTools();
      expect(schemas.length, equals(14));

      final transcribeSchema = schemas.firstWhere((s) => s['name'] == 'transcribe');
      expect(transcribeSchema['description'], isNotEmpty);
      expect(transcribeSchema['input_schema']['type'], equals('object'));
      expect(
        transcribeSchema['input_schema']['required'],
        contains('filePath'),
      );
    });

    test('toolsForIntent() — registerRecord는 6개 툴', () {
      final tools = registry.toolsForIntent('registerRecord');
      final names = tools.map((t) => t['name'] as String).toList();
      expect(names, contains('transcribe'));
      expect(names, contains('summarize'));
      expect(names, contains('save_record'));
      // 검색 툴은 포함 안 됨
      expect(names, isNot(contains('search')));
    });

    test('toolsForIntent() — searchRecord는 1개 툴', () {
      final tools = registry.toolsForIntent('searchRecord');
      expect(tools.length, equals(1));
      expect(tools.first['name'], equals('search'));
    });
  });

  group('AgentTool 인터페이스', () {
    test('TranscribeTool — toClaudeSchema() 형식 검증', () {
      final tool = TranscribeTool();
      final schema = tool.toClaudeSchema();

      expect(schema['name'], equals('transcribe'));
      expect(schema['input_schema']['properties'], isA<Map>());
      expect(
        schema['input_schema']['required'],
        contains('filePath'),
      );
    });

    test('SaveRecordTool — run() 성공 결과에 recordId 포함', () async {
      final tool = SaveRecordTool();
      final result = await tool.run({
        'transcript': '테스트 전사',
        'summary': '테스트 요약',
        'tags': ['태그1'],
      });
      expect(result.success, isTrue);
      expect(result.output['recordId'], startsWith('REC-'));
    });

    test('ToolResult.get() — 타입 안전 키 접근', () {
      const result = ToolResult(
        success: true,
        output: {'transcript': '텍스트', 'duration': 3600},
      );
      expect(result.get<String>('transcript'), equals('텍스트'));
      expect(result.get<int>('duration'), equals(3600));
      expect(result.get<String>('missing'), isNull);
    });
  });
}
