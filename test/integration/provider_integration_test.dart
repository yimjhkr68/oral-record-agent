// 파일 목적: Provider 통합 테스트

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/src/presentation/providers/metadata_form_provider.dart';
import 'package:oral_record_agent/src/presentation/providers/search_filter_provider.dart';
import 'package:oral_record_agent/src/presentation/providers/settings_provider.dart';

void main() {
  group('Provider 통합 테스트', () {
    test('[통합] 메타데이터 폼 상태 관리', () {
      final container = ProviderContainer();

      // 초기 상태 확인
      var formState = container.read(metadataFormProvider);
      expect(formState.narratorId, isNull);
      expect(formState.interviewerId, isNull);
      expect(formState.isValid, false);

      // 구술자 설정
      container.read(metadataFormProvider.notifier).setNarrator('narrator1');
      formState = container.read(metadataFormProvider);
      expect(formState.narratorId, 'narrator1');
      expect(formState.isValid, false); // 아직 필수 필드 미완성

      // 면담자 설정 (interviewDate는 DateTime.now()로 초기화됨 → isValid=true)
      container
          .read(metadataFormProvider.notifier)
          .setInterviewer('interviewer1');
      formState = container.read(metadataFormProvider);
      expect(formState.interviewerId, 'interviewer1');
      expect(formState.isValid, true); // narratorId+interviewerId+interviewDate 모두 설정됨

      // 면담 일시 재설정
      final now = DateTime.now();
      container.read(metadataFormProvider.notifier).setInterviewDate(now);
      formState = container.read(metadataFormProvider);
      expect(formState.interviewDate, now);
      expect(formState.isValid, true); // 주제는 선택 필드이므로 유효

      // 주제 설정 (선택 필드)
      container.read(metadataFormProvider.notifier).setMainCategory('역사');
      formState = container.read(metadataFormProvider);
      expect(formState.mainCategory, '역사');
      expect(formState.isValid, true);

      // 키워드 추가
      container.read(metadataFormProvider.notifier).addKeyword('조선');
      formState = container.read(metadataFormProvider);
      expect(formState.keywords, contains('조선'));

      // 리셋
      container.read(metadataFormProvider.notifier).reset();
      formState = container.read(metadataFormProvider);
      expect(formState.narratorId, isNull);
      expect(formState.keywords, isEmpty);
    });

    test('[통합] 검색 필터 상태 관리', () {
      final container = ProviderContainer();

      // 초기 상태
      var filters = container.read(searchFilterProvider);
      expect(filters.narratorId, isNull);
      expect(filters.startDate, isNull);
      expect(filters.offset, 0);

      // 구술자 필터 설정
      container.read(searchFilterProvider.notifier).setNarrator('narrator1');
      filters = container.read(searchFilterProvider);
      expect(filters.narratorId, 'narrator1');

      // 날짜 범위 설정
      final start = DateTime(2024, 1, 1);
      final end = DateTime(2024, 12, 31);
      container.read(searchFilterProvider.notifier).setDateRange(start, end);
      filters = container.read(searchFilterProvider);
      expect(filters.startDate, start);
      expect(filters.endDate, end);

      // 주제 설정
      container.read(searchFilterProvider.notifier).setMainCategory('역사');
      filters = container.read(searchFilterProvider);
      expect(filters.mainCategory, '역사');

      // 페이지 설정 (페이징)
      container.read(searchFilterProvider.notifier).setPage(2);
      filters = container.read(searchFilterProvider);
      expect(filters.offset, 20); // page 2 = offset 20 (page size 20)

      // 리셋
      container.read(searchFilterProvider.notifier).reset();
      filters = container.read(searchFilterProvider);
      expect(filters.narratorId, isNull);
      expect(filters.offset, 0);
    });

    test('[통합] 설정 상태 관리', () {
      final container = ProviderContainer();

      // 초기 상태
      var settings = container.read(settingsProvider);
      expect(settings.autoTranscribe, true);
      expect(settings.enablePIIDetection, true);
      expect(settings.exportFormat, 'json');

      // 자동 전사 토글
      container.read(settingsProvider.notifier).toggleAutoTranscribe();
      settings = container.read(settingsProvider);
      expect(settings.autoTranscribe, false);

      // PII 감지 토글
      container.read(settingsProvider.notifier).togglePIIDetection();
      settings = container.read(settingsProvider);
      expect(settings.enablePIIDetection, false);

      // 내보내기 형식 변경
      container.read(settingsProvider.notifier).setExportFormat('txt');
      settings = container.read(settingsProvider);
      expect(settings.exportFormat, 'txt');

      // 다크 모드 토글
      container.read(settingsProvider.notifier).toggleDarkMode();
      settings = container.read(settingsProvider);
      expect(settings.darkMode, true);

      // 언어 변경
      container.read(settingsProvider.notifier).setLanguage('en');
      settings = container.read(settingsProvider);
      expect(settings.language, 'en');
    });

    test('[통합] 메타데이터 유효성 Provider', () {
      final container = ProviderContainer();

      // 초기: 무효
      var isValid = container.read(metadataFormValidProvider);
      expect(isValid, false);

      // 필드 채우기
      container.read(metadataFormProvider.notifier).setNarrator('n1');
      container.read(metadataFormProvider.notifier).setInterviewer('i1');
      container
          .read(metadataFormProvider.notifier)
          .setInterviewDate(DateTime.now());
      container.read(metadataFormProvider.notifier).setMainCategory('역사');

      // 이후: 유효
      isValid = container.read(metadataFormValidProvider);
      expect(isValid, true);
    });

    test('[통합] 여러 Provider 간 상태 동기화', () {
      final container = ProviderContainer();

      // 메타데이터에서 구술자 선택
      container.read(metadataFormProvider.notifier).setNarrator('narrator1');

      // 검색 필터에서도 같은 구술자로 필터링
      container.read(searchFilterProvider.notifier).setNarrator('narrator1');

      // 두 Provider의 구술자 ID 일치 확인
      final formNarrator = container.read(metadataFormProvider).narratorId;
      final filterNarrator = container.read(searchFilterProvider).narratorId;

      expect(formNarrator, filterNarrator);
      expect(formNarrator, 'narrator1');
    });
  });
}
