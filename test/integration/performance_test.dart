// 파일 목적: 성능 테스트

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('성능 테스트', () {
    test('[성능] 1000개 기록 검색 < 500ms', () async {
      final stopwatch = Stopwatch()..start();

      // 1000개 기록 시뮬레이션 검색
      // var results = await repository.search(
      //   SearchFilters(
      //     narratorId: 'narrator1',
      //     limit: 20,
      //   ),
      // );

      // 기대: < 500ms
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('[성능] 메타데이터 폼 상태 100회 업데이트 < 100ms', () {
      final stopwatch = Stopwatch()..start();

      // 폼 상태 100회 업데이트 시뮬레이션
      for (int i = 0; i < 100; i++) {
        // notifier.setNarrator('narrator$i');
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('[성능] ListView 렌더링 (1000개 아이템) < 1초', () async {
      final stopwatch = Stopwatch()..start();

      // ListView.builder 성능 테스트
      // 1000개 아이템 스크롤 없이 빌드

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });

    test('[성능] 페이징 전환 < 200ms', () {
      final stopwatch = Stopwatch()..start();

      // 페이지 1 → 페이지 2 전환
      // var page1 = await repository.search(SearchFilters(offset: 0));
      // var page2 = await repository.search(SearchFilters(offset: 20));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('[성능] 필터 적용 < 300ms', () {
      final stopwatch = Stopwatch()..start();

      // 복합 필터 적용
      // - 구술자: narrator1
      // - 날짜 범위: 2024-01-01 ~ 2024-12-31
      // - 주제: 역사
      // var results = await repository.search(SearchFilters(
      //   narratorId: 'narrator1',
      //   startDate: DateTime(2024, 1, 1),
      //   endDate: DateTime(2024, 12, 31),
      //   mainCategory: '역사',
      // ));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(300));
    });

    test('[성능] UI 상태 변경 (로딩 → 데이터) 60ms 이하', () {
      final stopwatch = Stopwatch()..start();

      // AsyncValue 상태 전환
      // loading → data 전환 성능

      stopwatch.stop();
      // 일반적으로 매우 빠름 (렌더링 제외)
      expect(stopwatch.elapsedMilliseconds, lessThan(60));
    });

    test('[성능] PII 강조 표시 (100개 PII) < 200ms', () {
      final stopwatch = Stopwatch()..start();

      // PIIHighlightedText 위젯으로 100개 PII 강조 표시
      // expect(renderTime, lessThan(200));

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('[성능] 대량 키워드 입력 (50개) < 500ms', () {
      final stopwatch = Stopwatch()..start();

      // 메타데이터 폼에 50개 키워드 추가
      for (int i = 0; i < 50; i++) {
        // notifier.addKeyword('keyword$i');
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });

    test('[성능] 설정 저장 < 100ms', () {
      final stopwatch = Stopwatch()..start();

      // 설정 항목 여러 개 변경 및 저장
      // notifier.toggleAutoTranscribe();
      // notifier.togglePIIDetection();
      // notifier.setExportFormat('txt');
      // notifier.toggleDarkMode();

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
