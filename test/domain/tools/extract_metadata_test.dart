// 파일 목적: extractMetadata 도구 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/domain/tools/extract_metadata.dart';

void main() {
  group('ExtractMetadataTool 테스트', () {
    const sampleContent = '''
2024년 3월 15일 Seoul에서 Hong과 면담했습니다.
주요 내용: 회사 업무, 프로젝트 진행, 팀 협업 등을 논의했습니다.
Hong은 마케팅팀 매니저이며, Busan에서 출장 중이었습니다.
다음 메팅: 2024-03-22 추진 계획 논의 예정입니다.
''';

    group('키워드 추출 (extractKeywords)', () {
      test('[Keyword] 기본 키워드 추출', () {
        final keywords = ExtractMetadataTool.extractKeywords(sampleContent);
        expect(keywords, isNotEmpty);
        expect(keywords.length, lessThanOrEqualTo(10));
      });

      test('[Keyword] 3글자 이상만 추출', () {
        final keywords = ExtractMetadataTool.extractKeywords(sampleContent);
        for (final keyword in keywords) {
          expect(keyword.length, greaterThanOrEqualTo(3));
        }
      });

      test('[Keyword] 커스텀 topN', () {
        final keywords =
            ExtractMetadataTool.extractKeywords(sampleContent, topN: 5);
        expect(keywords.length, lessThanOrEqualTo(5));
      });

      test('[Keyword] 빈 콘텐츠 처리', () {
        final keywords = ExtractMetadataTool.extractKeywords('');
        expect(keywords, isEmpty);
      });

      test('[Keyword] 단어 빈도 정렬', () {
        const repeatedContent = '''
프로젝트 프로젝트 계획 계획 보고 보고 미팅 미팅
''';
        final keywords =
            ExtractMetadataTool.extractKeywords(repeatedContent, topN: 3);
        // "프로젝트"가 가장 빈번해야 함
        expect(keywords.first, '프로젝트');
      });
    });

    group('날짜 추출 (extractDates)', () {
      test('[Date] ISO 형식 날짜 추출', () {
        final dates = ExtractMetadataTool.extractDates('회의 날짜: 2024-03-22');
        expect(dates, contains('2024-03-22'));
      });

      test('[Date] 한글 형식 날짜 추출', () {
        final dates = ExtractMetadataTool.extractDates('면담 날짜: 2024년 3월 15일');
        expect(dates, isNotEmpty);
        expect(dates.any((d) => d.contains('2024')), true);
      });

      test('[Date] 여러 형식 혼합', () {
        final dates = ExtractMetadataTool.extractDates(sampleContent);
        expect(dates.length, greaterThanOrEqualTo(2));
      });

      test('[Date] 중복 제거', () {
        const repeatedDates = '일정: 2024-03-22, 2024-03-22, 2024-03-22';
        final dates = ExtractMetadataTool.extractDates(repeatedDates);
        expect(dates.length, 1);
      });

      test('[Date] 날짜 없음', () {
        final dates = ExtractMetadataTool.extractDates('날짜 정보 없음');
        expect(dates, isEmpty);
      });
    });

    group('엔티티 추출 (extractEntities)', () {
      test('[Entity] 대문자 시작 단어 추출', () {
        final entities = ExtractMetadataTool.extractEntities(sampleContent);
        expect(entities, isNotEmpty);
        // Seoul, Hong 등이 포함
        expect(entities.any((e) => e.contains('Seoul')), true);
      });

      test('[Entity] 중복 제거', () {
        const repeatedEntity = 'Seoul Seoul Seoul';
        final entities = ExtractMetadataTool.extractEntities(repeatedEntity);
        expect(entities.length, 1);
      });

      test('[Entity] 소문자만 있으면 빈 결과', () {
        final entities =
            ExtractMetadataTool.extractEntities('no capital letters here');
        // 영문 대문자가 없어서 empty일 수 있음
        expect(entities, isEmpty);
      });
    });

    group('메타데이터 통합 추출 (execute)', () {
      test('[통합] 메타데이터 추출', () async {
        // NOTE: 실제 구현 시
        // final result = await ExtractMetadataTool.execute(
        //   content: sampleContent,
        //   useML: false, // 규칙 기반
        // );
        // expect(result.keywords, isNotEmpty);
        // expect(result.dates, isNotEmpty);
        // expect(result.confidence, greaterThan(0.5));
      }, skip: 'execute 통합 구현 필요');
    });

    group('성능 테스트', () {
      test('[성능] 10KB 콘텐츠 추출 < 100ms', () {
        final largeContent = sampleContent * 100;
        final stopwatch = Stopwatch()..start();

        ExtractMetadataTool.extractKeywords(largeContent);
        ExtractMetadataTool.extractDates(largeContent);
        ExtractMetadataTool.extractEntities(largeContent);

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
