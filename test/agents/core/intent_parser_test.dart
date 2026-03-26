// test/agents/core/intent_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/agents/core/intent_parser.dart';
import 'package:oral_record_agent/agents/core/agent_intent.dart';

void main() {
  // API 키 없이 규칙 기반만 사용
  late IntentParser parser;

  setUp(() {
    parser = IntentParser();
  });

  group('규칙 기반 — IntentType 분류', () {
    test('"interview.mp3 파일 등록해줘" → registerRecord', () async {
      final intent = await parser.parse('interview.mp3 파일 등록해줘');

      expect(intent.type, equals(IntentType.registerRecord));
      expect(intent.confidence, greaterThanOrEqualTo(0.9));
      expect(intent.params['filePath'], equals('interview.mp3'));
    });

    test('"김철수 선생님 기록 찾아줘" → searchRecord + 인물명 추출', () async {
      final intent = await parser.parse('김철수 선생님 기록 찾아줘');

      expect(intent.type, equals(IntentType.searchRecord));
      expect(intent.confidence, greaterThanOrEqualTo(0.75));
      expect(intent.params['narratorName'], equals('김철수'));
    });

    test('"3월 면담 보고서 만들어줘" → generateContent + 기간 추출', () async {
      final intent = await parser.parse('3월 면담 보고서 만들어줘');

      expect(intent.type, equals(IntentType.generateContent));
      expect(intent.confidence, greaterThanOrEqualTo(0.9));
      expect(intent.params['period'], equals('3월'));
    });

    test('"전체 CSV로 내보내줘" → exportData + 포맷 추출', () async {
      final intent = await parser.parse('전체 CSV로 내보내줘');

      expect(intent.type, equals(IntentType.exportData));
      expect(intent.confidence, greaterThanOrEqualTo(0.75));
      expect(intent.params['format'], equals('csv'));
    });

    test('"이 기록 분석해줘" → analyzeRecord', () async {
      final intent = await parser.parse('이 기록 분석해줘');

      expect(intent.type, equals(IntentType.analyzeRecord));
      expect(intent.confidence, greaterThanOrEqualTo(0.75));
    });

    test('"구술자 목록 보여줘" → searchRecord 또는 managePersons', () async {
      final intent = await parser.parse('구술자 목록 보여줘');

      expect(intent.type, isNot(equals(IntentType.unknown)));
      expect(intent.confidence, greaterThanOrEqualTo(0.75));
    });
  });

  group('파라미터 추출', () {
    test('Windows 경로 추출', () async {
      final intent = await parser.parse(r'C:\Users\samsung\Downloads\record.mp3 등록해줘');

      expect(intent.params['filePath'], contains('record.mp3'));
    });

    test('공백 포함 Windows 경로 추출', () async {
      final intent = await parser.parse(
          'C:\\Users\\samsung\\Documents\\소리 녹음\\어린시절 놀이.m4a 등록해줘');

      expect(intent.params['filePath'],
          equals('C:\\Users\\samsung\\Documents\\소리 녹음\\어린시절 놀이.m4a'));
    });

    test('공백 포함 경로 → registerRecord, transcribe 대상', () async {
      final intent = await parser.parse(
          'C:\\Users\\samsung\\Documents\\내 인터뷰 파일\\interview 01.mp3 등록해줘');

      expect(intent.type, equals(IntentType.registerRecord));
      expect(intent.params['filePath'],
          endsWith('interview 01.mp3'));
    });

    test('확장자 파일명 추출', () async {
      final intent = await parser.parse('document.pdf 등록해줘');

      expect(intent.params['filePath'], equals('document.pdf'));
    });

    test('연도 추출 — "2024년 면담 정리해줘"', () async {
      final intent = await parser.parse('2024년 면담 정리해줘');

      expect(intent.params['period'], equals('2024년'));
    });

    test('상대 기간 추출 — "지난달 보고서 만들어줘"', () async {
      final intent = await parser.parse('지난달 보고서 만들어줘');

      expect(intent.params['period'], equals('지난달'));
    });

    test('JSON 포맷 추출', () async {
      final intent = await parser.parse('기록 전체 JSON으로 추출해줘');

      expect(intent.params['format'], equals('json'));
    });

    test('인물 이름 + 쿼리 동시 추출', () async {
      final intent = await parser.parse('박영희 씨 기록 찾아줘');

      expect(intent.params['narratorName'], equals('박영희'));
      expect(intent.params['query'], equals('박영희'));
    });
  });

  group('낮은 confidence / unknown', () {
    test('"그거 해줘" → unknown, confidence < 0.6', () async {
      final intent = await parser.parse('그거 해줘');

      expect(intent.type, equals(IntentType.unknown));
      expect(intent.confidence, lessThan(0.6));
    });

    test('빈 문자열 → unknown, confidence 0.0', () async {
      final intent = await parser.parse('');

      expect(intent.type, equals(IntentType.unknown));
      expect(intent.confidence, equals(0.0));
    });

    test('공백만 있는 입력 → unknown', () async {
      final intent = await parser.parse('   ');

      expect(intent.type, equals(IntentType.unknown));
      expect(intent.confidence, equals(0.0));
    });

    test('needsClarification — confidence < 0.6 이면 true', () async {
      final intent = await parser.parse('그거 해줘');

      expect(intent.needsClarification, isTrue);
    });
  });

  group('파일 경로 → confidence 보너스', () {
    test('파일 경로 포함 시 confidence >= 0.9', () async {
      final intent = await parser.parse('이 파일 등록 interview.mp3');

      // filePath 있으면 +0.1 보너스
      expect(intent.params.containsKey('filePath'), isTrue);
      expect(intent.confidence, greaterThanOrEqualTo(0.75));
    });
  });

  group('rawInput 보존', () {
    test('원본 입력이 그대로 저장됨', () async {
      const input = '김철수 선생님 인터뷰 파일 등록해줘';
      final intent = await parser.parse(input);

      expect(intent.rawInput, equals(input));
    });
  });
}
