// 파일 목적: suggestActions 도구 테스트

import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/domain/tools/suggest_actions.dart';

void main() {
  group('SuggestActionsTool 테스트', () {
    const keywords = ['회의', '일정', '계획', '사람', '날짜'];
    const category = '역사';
    const entities = ['홍길동', '서울', '한국'];

    group('규칙 기반 제안 (suggestByRules)', () {
      test('[Rules] 기본 제안 생성', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: category,
          entities: entities,
        );
        expect(suggestions, isNotEmpty);
      });

      test('[Rules] 일정 등록 제안', () {
        const scheduleKeywords = ['회의', '일정', '만남'];
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: scheduleKeywords,
          category: category,
          entities: entities,
        );
        expect(
          suggestions.any((s) => s.action == '일정 등록'),
          true,
        );
      });

      test('[Rules] 연락처 추가 제안', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: category,
          entities: entities,
        );
        expect(
          suggestions.any((s) => s.action == '연락처 추가'),
          true,
        );
      });

      test('[Rules] 역사 관련 제안', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: '역사',
          entities: entities,
        );
        expect(
          suggestions.any((s) => s.action.contains('아카이빙')),
          true,
        );
      });

      test('[Rules] 문제 해결 제안', () {
        const problemKeywords = ['문제', '이슈', '해결'];
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: problemKeywords,
          category: category,
          entities: entities,
        );
        expect(
          suggestions.any((s) => s.action.contains('해결')),
          true,
        );
      });
    });

    group('행동 제안 (ActionSuggestion)', () {
      test('[Suggestion] 기본 멘버 저장', () {
        final suggestion = ActionSuggestion(
          action: '테스트 행동',
          reason: '테스트 이유',
          priority: 0.8,
          feasibility: 0.9,
          impact: 0.7,
          relatedKeywords: ['키워드1', '키워드2'],
        );
        expect(suggestion.action, '테스트 행동');
        expect(suggestion.reason, '테스트 이유');
      });

      test('[Suggestion] 종합 점수 계산', () {
        final suggestion = ActionSuggestion(
          action: '테스트',
          reason: '이유',
          priority: 0.8,
          feasibility: 0.5,
          impact: 0.5,
          relatedKeywords: ['키워드'],
        );
        const expectedScore = 0.8 * 0.5 * 0.5;
        expect((suggestion.score - expectedScore).abs(), lessThan(0.001));
      });

      test('[Suggestion] 우선순위 범위', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: category,
          entities: entities,
        );
        for (final s in suggestions) {
          expect(s.priority, greaterThanOrEqualTo(0));
          expect(s.priority, lessThanOrEqualTo(1));
          expect(s.feasibility, greaterThanOrEqualTo(0));
          expect(s.feasibility, lessThanOrEqualTo(1));
          expect(s.impact, greaterThanOrEqualTo(0));
          expect(s.impact, lessThanOrEqualTo(1));
        }
      });

      test('[Suggestion] 관련 키워드', () {
        final suggestion = ActionSuggestion(
          action: '테스트',
          reason: '이유',
          priority: 0.8,
          feasibility: 0.8,
          impact: 0.8,
          relatedKeywords: ['키1', '키2', '키3'],
        );
        expect(suggestion.relatedKeywords.length, 3);
      });

      test('[Suggestion] 소요 시간 (선택적)', () {
        final suggestion = ActionSuggestion(
          action: '테스트',
          reason: '이유',
          priority: 0.8,
          feasibility: 0.8,
          impact: 0.8,
          relatedKeywords: [],
          estimatedTime: const Duration(hours: 2),
        );
        expect(suggestion.estimatedTime, const Duration(hours: 2));
      });
    });

    group('제안 우선순위', () {
      test('[Priority] 높은 점수순 정렬', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: category,
          entities: entities,
        );

        if (suggestions.length > 1) {
          for (int i = 0; i < suggestions.length - 1; i++) {
            expect(
              suggestions[i].score,
              greaterThanOrEqualTo(suggestions[i + 1].score),
            );
          }
        }
      });

      test('[Priority] 점수 0 이상', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: category,
          entities: entities,
        );
        for (final s in suggestions) {
          expect(s.score, greaterThanOrEqualTo(0));
        }
      });
    });

    group('엣지 케이스', () {
      test('[Edge] 빈 키워드', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: [],
          category: category,
          entities: entities,
        );
        // 일부 제안은 엔티티 기반으로 생성될 수 있음
        expect(suggestions, isNotNull);
      });

      test('[Edge] 빈 엔티티', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: category,
          entities: [],
        );
        expect(suggestions, isNotNull);
      });

      test('[Edge] 모두 빈 경우', () {
        final suggestions = SuggestActionsTool.suggestByRules(
          keywords: [],
          category: null,
          entities: [],
        );
        // 최소한 빈 리스트 반환
        expect(suggestions, isA<List<ActionSuggestion>>());
      });
    });

    group('성능 테스트', () {
      test('[성능] 제안 생성 < 50ms', () {
        final stopwatch = Stopwatch()..start();

        SuggestActionsTool.suggestByRules(
          keywords: keywords,
          category: category,
          entities: entities,
        );

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });

      test('[성능] 많은 키워드 처리', () {
        final manyKeywords = List.generate(100, (i) => 'keyword$i');
        final stopwatch = Stopwatch()..start();

        SuggestActionsTool.suggestByRules(
          keywords: manyKeywords,
          category: category,
          entities: entities,
        );

        stopwatch.stop();
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });
    });
  });
}
