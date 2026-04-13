// 파일 목적: summarizeRecord 도구 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/domain/tools/summarize_record.dart';

void main() {
  group('SummarizeRecordTool 테스트', () {
    const sampleText = '''
2024년 3월 15일 서울에서 중요한 회의가 개최되었습니다.
참석자는 홍길동, 김민수, 이순신 세 명이었습니다.
첫 번째 안건은 제품 개발 일정에 관한 것이었습니다.
핵심 내용은 3월 말까지 베타 버전을 완성해야 한다는 것입니다.
두 번째 안건은 마케팅 전략에 관한 것이었습니다.
소셜 미디어를 통한 홍보와 인플루언서 협력을 추진하기로 결정했습니다.
세 번째 안건은 팀 확대에 관한 것이었습니다.
개발팀과 마케팅팀 각각 2명씩 인원이 필요하기로 합의했습니다.
다음 회의는 2024년 4월 15일로 예정되었습니다.
''';

    group('추출형 요약 (summarizeExtractive)', () {
      test('[Extractive] 기본 요약 (40%)', () {
        final result = SummarizeRecordTool.summarizeExtractive(sampleText);
        expect(result.summary, isNotEmpty);
        expect(result.summaryRatio, lessThanOrEqualTo(0.5));
      });

      test('[Extractive] 짧은 요약 (20%)', () {
        final result = SummarizeRecordTool.summarizeExtractive(
          sampleText,
          ratio: 0.2,
        );
        expect(result.compressionRatio, equals(0.2));
      });

      test('[Extractive] 긴 요약 (70%)', () {
        final result = SummarizeRecordTool.summarizeExtractive(
          sampleText,
          ratio: 0.7,
        );
        expect(result.compressionRatio, equals(0.7));
      });

      test('[Extractive] 원본 정보 보존', () {
        final result = SummarizeRecordTool.summarizeExtractive(sampleText);
        expect(result.originalText, equals(sampleText));
        expect(result.originalLength, greaterThan(0));
      });
    });

    group('키포인트 추출 (extractKeyPoints)', () {
      test('[KeyPoint] 기본 키포인트 추출', () {
        final keyPoints = SummarizeRecordTool.extractKeyPoints(sampleText);
        expect(keyPoints, isNotEmpty);
        expect(keyPoints.length, lessThanOrEqualTo(5));
      });

      test('[KeyPoint] "핵심" 포함 문장 우선', () {
        final keyPoints = SummarizeRecordTool.extractKeyPoints(sampleText);
        // "핵심" 단어 포함 문장이 추출되어야 함
        expect(
          keyPoints.any((kp) => kp.contains('핵심')),
          true,
        );
      });

      test('[KeyPoint] 커스텀 maxPoints', () {
        final keyPoints = SummarizeRecordTool.extractKeyPoints(
          sampleText,
          maxPoints: 3,
        );
        expect(keyPoints.length, lessThanOrEqualTo(3));
      });

      test('[KeyPoint] 긴 문장 우선 추출', () {
        const longSentenceText =
            '첫 문장. 이것은 매우 긴 문장으로서 중요한 정보를 포함하고 있으며 많은 단어가 포함되어 있습니다. 짧은.';
        final keyPoints = SummarizeRecordTool.extractKeyPoints(longSentenceText,
            maxPoints: 2);
        expect(keyPoints, isNotEmpty);
      });
    });

    group('요약 결과 (SummaryResult)', () {
      test('[Result] 요약률 계산', () {
        final result = SummarizeRecordTool.summarizeExtractive(sampleText);
        expect(result.summaryRatio, greaterThan(0));
        expect(result.summaryRatio, lessThanOrEqualTo(1));
      });

      test('[Result] 압축률 저장', () {
        final result = SummarizeRecordTool.summarizeExtractive(
          sampleText,
          ratio: 0.3,
        );
        expect(result.compressionRatio, equals(0.3));
      });

      test('[Result] 길이 정보 저장', () {
        final result = SummarizeRecordTool.summarizeExtractive(sampleText);
        expect(result.originalLength, greaterThan(0));
        expect(result.summaryLength, greaterThan(0));
        expect(result.summaryLength, lessThan(result.originalLength));
      });
    });

    group('엣지 케이스', () {
      test('[Edge] 짧은 텍스트', () {
        const shortText = '첫 번째 문장. 두 번째 문장.';
        final result = SummarizeRecordTool.summarizeExtractive(shortText);
        expect(result.summary, isNotEmpty);
      });

      test('[Edge] 한 문장', () {
        const oneSentence = '이것은 한 문장입니다.';
        final result = SummarizeRecordTool.summarizeExtractive(oneSentence);
        expect(result.summary, isNotEmpty);
      });

      test('[Edge] 빈 문장 처리', () {
        const textWithEmpty = '첫 문장...두 번째 문장';
        final result = SummarizeRecordTool.summarizeExtractive(textWithEmpty);
        expect(result.summary, isNotEmpty);
      });
    });

    group('성능 테스트', () {
      test('[성능] 100KB 텍스트 요약 < 500ms', () {
        final largeText = sampleText * 200;
        final stopwatch = Stopwatch()..start();

        SummarizeRecordTool.summarizeExtractive(largeText);

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });
    });
  });
}
