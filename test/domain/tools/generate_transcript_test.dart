// 파일 목적: generateTranscript 도구 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/domain/tools/generate_transcript.dart';

void main() {
  group('GenerateTranscriptTool 테스트', () {
    const mockAudioText = '''
안녕하세요. 오늘은 구술 기록 프로젝트에 대해 설명하겠습니다.
이 프로젝트는 음성 기록을 디지털화하고 관리하는 시스템입니다.
주요 기능으로는 음성 인식, PII 탐지, 자동 요약 등이 있습니다.
감사합니다.
''';

    group('필기록 결과 (TranscriptResult)', () {
      test('[Result] 기본 정보 저장', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        expect(result.text, equals(mockAudioText));
        expect(result.confidence, greaterThan(0));
        expect(result.duration, isNotNull);
      });

      test('[Result] 단어 개수 계산', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        expect(result.wordCount, greaterThan(0));
      });

      test('[Result] 타임스탬프 세그먼트', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        expect(result.segments, isNotEmpty);
        for (final seg in result.segments) {
          expect(seg.startTime, lessThanOrEqualTo(seg.endTime));
        }
      });
    });

    group('필기록 세그먼트 (TranscriptSegment)', () {
      test('[Segment] 타임스탬프 순서', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        for (int i = 0; i < result.segments.length - 1; i++) {
          expect(
            result.segments[i].endTime,
            lessThanOrEqualTo(result.segments[i + 1].startTime),
          );
        }
      });

      test('[Segment] 신뢰도 점수', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        for (final seg in result.segments) {
          expect(seg.confidence, greaterThan(0));
          expect(seg.confidence, lessThanOrEqualTo(1));
        }
      });

      test('[Segment] 텍스트 콘텐츠', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        expect(result.segments.isNotEmpty, true);
        for (final seg in result.segments) {
          expect(seg.text, isNotEmpty);
        }
      });
    });

    group('모의 필기록 생성 (generateMockTranscript)', () {
      test('[Mock] 기본 텍스트', () {
        const text = '안녕하세요. 테스트입니다.';
        final result = GenerateTranscriptTool.generateMockTranscript(text);
        expect(result.text, equals(text));
      });

      test('[Mock] 긴 텍스트 처리', () {
        final longText = mockAudioText * 10;
        final result = GenerateTranscriptTool.generateMockTranscript(longText);
        expect(result.segments.length, greaterThan(10));
      });

      test('[Mock] 신뢰도 범위', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        expect(result.confidence, greaterThanOrEqualTo(0));
        expect(result.confidence, lessThanOrEqualTo(1));
      });

      test('[Mock] 음성 길이 추정', () {
        final result =
            GenerateTranscriptTool.generateMockTranscript(mockAudioText);
        // 텍스트 길이에 비례해 음성 길이 추정
        expect(result.duration.inSeconds, greaterThan(0));
      });
    });

    group('성능 테스트', () {
      test('[성능] 모의 필기록 생성 < 100ms', () {
        final largeText = mockAudioText * 50;
        final stopwatch = Stopwatch()..start();

        GenerateTranscriptTool.generateMockTranscript(largeText);

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('엣지 케이스', () {
      test('[Edge] 빈 텍스트', () {
        final result = GenerateTranscriptTool.generateMockTranscript('');
        expect(result.text, '');
        expect(result.segments, isEmpty);
      });

      test('[Edge] 한 단어만', () {
        final result = GenerateTranscriptTool.generateMockTranscript('안녕');
        expect(result.wordCount, 1);
        expect(result.segments.length, 1);
      });

      test('[Edge] 특수문자 포함', () {
        const text = '특수문자: !@#\$%^&*() 포함';
        final result = GenerateTranscriptTool.generateMockTranscript(text);
        expect(result.text, contains('!@#'));
      });
    });
  });
}
