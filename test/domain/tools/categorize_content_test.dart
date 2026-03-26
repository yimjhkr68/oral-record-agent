// 파일 목적: categorizeContent 도구 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/domain/tools/categorize_content.dart';

void main() {
  group('CategorizeContentTool 테스트', () {
    const historyText = '조선시대 왕들의 역사와 전쟁에 관한 기록입니다.';
    const scienceText = '과학 연구를 통해 자연의 원리를 발견했습니다.';
    const economicsText = '금융 투자와 경제 정책에 대해 논의했습니다.';

    group('규칙 기반 분류 (categorizeByRules)', () {
      test('[Rules] 역사 분류', () {
        final result = CategorizeContentTool.categorizeByRules(historyText);
        expect(result.mainCategory, '역사');
        expect(result.confidence, greaterThan(0));
      });

      test('[Rules] 과학 분류', () {
        final result = CategorizeContentTool.categorizeByRules(scienceText);
        expect(result.mainCategory, '과학');
        expect(result.confidence, greaterThan(0));
      });

      test('[Rules] 경제 분류', () {
        final result = CategorizeContentTool.categorizeByRules(economicsText);
        expect(result.mainCategory, '경제');
        expect(result.confidence, greaterThan(0));
      });

      test('[Rules] 신뢰도 범위', () {
        final result = CategorizeContentTool.categorizeByRules(historyText);
        expect(result.confidence, greaterThanOrEqualTo(0));
        expect(result.confidence, lessThanOrEqualTo(1));
      });

      test('[Rules] 대안 분류 제시', () {
        final result = CategorizeContentTool.categorizeByRules(historyText);
        expect(result.alternativeCategories, isNotEmpty);
      });
    });

    group('분류 결과 (CategoryResult)', () {
      test('[Result] 기본 정보', () {
        final result = CategorizeContentTool.categorizeByRules(historyText);
        expect(result.mainCategory, isNotEmpty);
        expect(result.confidence, isNotNull);
      });

      test('[Result] 선택적 세부 분류', () {
        final result = CategorizeContentTool.categorizeByRules(historyText);
        // subCategory는 선택적 (null일 수 있음)
        expect(result, isNotNull);
      });

      test('[Result] 대안 분류 리스트', () {
        final result = CategorizeContentTool.categorizeByRules(historyText);
        expect(result.alternativeCategories, isA<List<String>>());
      });
    });

    group('미리 정의된 카테고리', () {
      test('[Predefined] 카테고리 10개 이상', () {
        expect(
          CategorizeContentTool.predefinedCategories.length,
          greaterThanOrEqualTo(10),
        );
      });

      test('[Predefined] 예상 카테고리 포함', () {
        expect(
          CategorizeContentTool.predefinedCategories,
          contains('역사'),
        );
        expect(
          CategorizeContentTool.predefinedCategories,
          contains('과학'),
        );
        expect(
          CategorizeContentTool.predefinedCategories,
          contains('경제'),
        );
      });
    });

    group('혼합 콘텐츠', () {
      test('[Mixed] 다중 주제 텍스트', () {
        const mixedText = '''
조선시대 경제 정책과 과학 발전에 대한 역사적 기록.
이는 역사, 경제, 과학이 모두 포함된 텍스트입니다.
''';
        final result = CategorizeContentTool.categorizeByRules(mixedText);
        expect(result.mainCategory, isNotEmpty);
        // 주 분류는 하나지만 신뢰도는 높아야 함
        expect(result.confidence, greaterThan(0.1));
      });

      test('[Mixed] 대안 분류도 의미 있음', () {
        const mixedText = '''
경제 정책과 과학 연구에 관한 기록.
''';
        final result = CategorizeContentTool.categorizeByRules(mixedText);
        expect(result.alternativeCategories.isNotEmpty, true);
      });
    });

    group('분류 정확도', () {
      test('[Accuracy] 중복 키워드 처리', () {
        const repeatedText = '''
역사 역사 역사 왕 전쟁 조선 역사.
''';
        final result = CategorizeContentTool.categorizeByRules(repeatedText);
        expect(result.mainCategory, '역사');
        expect(result.confidence, greaterThan(0.3));
      });

      test('[Accuracy] 약한 신호', () {
        const weakText = '국왕이 있었습니다.'; // 단 키워드 1-2개
        final result = CategorizeContentTool.categorizeByRules(weakText);
        // 분류는 하지만 신뢰도는 낮음
        expect(result.confidence, lessThan(0.5));
      });
    });

    group('성능 테스트', () {
      test('[성능] 100KB 텍스트 분류 < 100ms', () {
        final largeText = historyText * 1000;
        final stopwatch = Stopwatch()..start();

        CategorizeContentTool.categorizeByRules(largeText);

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });

    group('엣지 케이스', () {
      test('[Edge] 빈 텍스트', () {
        final result = CategorizeContentTool.categorizeByRules('');
        expect(result.mainCategory, isNotEmpty); // 기본값 반환
      });

      test('[Edge] 특수문자만', () {
        final result = CategorizeContentTool.categorizeByRules('!@#\$%^&*()');
        expect(result.mainCategory, isNotEmpty);
      });

      test('[Edge] 숫자만', () {
        final result = CategorizeContentTool.categorizeByRules('123456789');
        expect(result.mainCategory, isNotEmpty);
      });
    });
  });
}
