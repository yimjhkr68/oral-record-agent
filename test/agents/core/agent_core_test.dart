// test/agents/core/agent_core_test.dart
// AgentCore 단위 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/agents/core/agent_core.dart';
import 'package:oral_record_agent/agents/core/agent_intent.dart';
import 'package:oral_record_agent/agents/core/agent_result.dart';

void main() {
  late AgentCore agent;

  setUp(() {
    agent = AgentCore(
      claudeApiKey: 'test-key',
      onProgress: (step, detail) => print('[$step] $detail'),
    );
  });

  group('AgentCore.handle()', () {
    test('음성 파일 등록 - 전사→요약→태그→저장 순서로 실행', () async {
      const intent = AgentIntent(
        type: IntentType.registerRecord,
        rawInput: 'interview.mp3 파일 등록해줘',
        params: {'filePath': '/uploads/interview.mp3'},
        confidence: 0.95,
      );

      final result = await agent.handle(intent);

      expect(result.isSuccess, isTrue);
      expect(result.savedRecordId, isNotNull);
      expect(result.toolCallResults.length, greaterThanOrEqualTo(3));

      // 실행 순서 검증: transcribe → summarize → save_record
      final toolNames = result.toolCallResults.map((r) => r.toolName).toList();
      expect(toolNames.indexOf('transcribe'),
          lessThan(toolNames.indexOf('summarize')));
      expect(toolNames.indexOf('summarize'),
          lessThan(toolNames.indexOf('save_record')));
    });

    test('텍스트 파일 등록 - 전사 단계 없이 요약→저장', () async {
      const intent = AgentIntent(
        type: IntentType.registerRecord,
        rawInput: 'document.pdf 등록해줘',
        params: {'filePath': '/uploads/document.pdf'},
        confidence: 0.9,
      );

      final result = await agent.handle(intent);

      expect(result.isSuccess, isTrue);
      final toolNames = result.toolCallResults.map((r) => r.toolName).toList();
      expect(toolNames, contains('extract_pdf'));
      expect(toolNames, isNot(contains('transcribe')));
    });

    test('의도 불명확 - clarification 반환', () async {
      const intent = AgentIntent(
        type: IntentType.unknown,
        rawInput: '뭔가 해줘',
        confidence: 0.3,
      );

      final result = await agent.handle(intent);

      expect(result.status, equals(AgentStatus.needsClarification));
      expect(result.clarificationQuestion, isNotNull);
      expect(result.clarificationQuestion, isNotEmpty);
    });

    test('확신도 낮음 - clarification 반환', () async {
      const intent = AgentIntent(
        type: IntentType.registerRecord,
        rawInput: '그거',
        confidence: 0.4, // 0.6 미만
      );

      final result = await agent.handle(intent);
      expect(result.status, equals(AgentStatus.needsClarification));
    });

    test('음성 파일 등록 - transcript가 save_record에 전달됨', () async {
      // Bug #1 회귀 방지: transcribe → save_record transcript 체이닝
      final core = AgentCore(
        claudeApiKey: '',
        toolRegistry: null, // standard() 스텁 사용
      );

      const intent = AgentIntent(
        type: IntentType.registerRecord,
        rawInput: 'interview.mp3 파일 등록해줘',
        params: {'filePath': '/uploads/interview.mp3'},
        confidence: 0.95,
      );

      final result = await core.handle(intent);
      expect(result.isSuccess, isTrue);

      // 전사 단계 결과 확인
      final transcribeResult = result.toolCallResults
          .firstWhere((r) => r.toolName == 'transcribe');
      expect(transcribeResult.success, isTrue);
      expect(transcribeResult.output?['transcript'], isNotEmpty);

      // save_record가 실행됐는지 확인
      final saveResult = result.toolCallResults
          .firstWhere((r) => r.toolName == 'save_record');
      expect(saveResult.success, isTrue);
    });

    test('미지원 파일 형식(PNG) → 저장 안 되고 에러 반환', () async {
      const intent = AgentIntent(
        type: IntentType.registerRecord,
        rawInput: 'C:\\Users\\test\\해커톤 계획.png 등록해줘',
        params: {'filePath': 'C:\\Users\\test\\해커톤 계획.png'},
        confidence: 0.85,
      );

      final result = await agent.handle(intent);

      // 미지원 형식은 성공으로 처리되면 안 됨
      expect(result.isSuccess, isFalse);
      expect(result.savedRecordId, isNull);
      // 에러 메시지에 파일 형식 정보 포함
      final errMsg = result.errorMessage ?? result.reviewContent ?? '';
      expect(errMsg, contains('png'));
    });

    test('검색 의도 처리', () async {
      const intent = AgentIntent(
        type: IntentType.searchRecord,
        rawInput: '김철수 구술자 찾아줘',
        params: {'query': '김철수'},
        confidence: 0.9,
      );

      final result = await agent.handle(intent);

      expect(result.isSuccess, isTrue);
      expect(
        result.toolCallResults.any((r) => r.toolName == 'search'),
        isTrue,
      );
    });
  });

  group('AgentIntent', () {
    test('typeLabel 한국어 반환', () {
      expect(
        const AgentIntent(type: IntentType.registerRecord, rawInput: '').typeLabel,
        equals('기록 등록'),
      );
    });

    test('파일 경로 있으면 isFileRegistration = true', () {
      const intent = AgentIntent(
        type: IntentType.registerRecord,
        rawInput: '',
        params: {'filePath': '/path/to/file.mp3'},
      );
      expect(intent.isFileRegistration, isTrue);
    });
  });

  group('AgentResult 팩토리', () {
    test('success() 팩토리', () {
      final result = AgentResult.success(
        toolCallResults: [],
        savedRecordId: 'REC-001',
        summary: '완료',
      );
      expect(result.isSuccess, isTrue);
      expect(result.savedRecordId, equals('REC-001'));
    });

    test('clarify() 팩토리', () {
      final result = AgentResult.clarify('어떤 파일인가요?');
      expect(result.needsHumanAction, isTrue);
      expect(result.clarificationQuestion, equals('어떤 파일인가요?'));
    });

    test('failed() 팩토리', () {
      final result = AgentResult.failed('API 오류');
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, equals('API 오류'));
    });
  });
}
