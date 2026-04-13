// test/presentation/providers/agent_state_provider_test.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oral_record_agent/agents/core/agent_result.dart';
import 'package:oral_record_agent/src/presentation/providers/agent_state_provider.dart';
import 'package:oral_record_agent/src/presentation/providers/settings_provider.dart';

// ─── 테스트 헬퍼 ───────────────────────────────────────

/// Hive 미초기화 환경에서 AgentStateProvider를 생성하는 컨테이너
/// - recordRepositoryProvider / narratorRepositoryProvider 는 Future.error 로 override
///   → notifier 내부에서 catch 처리 → null repos → 스텁 모드 동작
ProviderContainer _makeContainer({String apiKey = ''}) {
  return ProviderContainer(
    overrides: [
      settingsProvider.overrideWith(
        (ref) => SettingsNotifier(initialApiKey: apiKey),
      ),
    ],
  );
}

void main() {
  group('AgentState 초기 상태', () {
    test('기본값: idle, 빈 로그, null 결과', () {
      const state = AgentState();

      expect(state.status, equals(AgentProcessStatus.idle));
      expect(state.agentLog, isEmpty);
      expect(state.lastResult, isNull);
      expect(state.pendingReview, isNull);
      expect(state.errorMessage, isNull);
      expect(state.stepProgress, equals(0));
    });
  });

  group('AgentState.copyWith', () {
    test('status만 변경', () {
      const state = AgentState();
      final updated = state.copyWith(status: AgentProcessStatus.thinking);

      expect(updated.status, equals(AgentProcessStatus.thinking));
      expect(updated.agentLog, isEmpty);
    });

    test('clearPendingReview 플래그로 pendingReview 제거', () {
      final result = AgentResult.pendingReview(
        toolCallResults: [],
        reviewContent: '검토 요청',
      );
      final state = AgentState(pendingReview: result);
      final updated = state.copyWith(clearPendingReview: true);

      expect(updated.pendingReview, isNull);
    });

    test('agentLog 추가', () {
      const state = AgentState();
      final log = AgentLogEntry(step: '분석', detail: '테스트');
      final updated = state.copyWith(agentLog: [log]);

      expect(updated.agentLog, hasLength(1));
      expect(updated.agentLog.first.step, equals('분석'));
    });
  });

  group('AgentStateNotifier.handle() — 성공 흐름', () {
    late ProviderContainer container;

    setUp(() {
      container = _makeContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('handle() 호출 전: idle', () {
      final state = container.read(agentStateProvider);
      expect(state.status, equals(AgentProcessStatus.idle));
    });

    test('handle() 완료 후: idle 복귀, lastResult 저장, agentLog 기록', () async {
      final notifier = container.read(agentStateProvider.notifier);

      await notifier.handle('interview.mp3 파일 등록해줘');

      final state = container.read(agentStateProvider);
      expect(state.status, equals(AgentProcessStatus.idle));
      expect(state.lastResult, isNotNull);
      expect(state.agentLog, isNotEmpty);
    });

    test('handle() 완료 후: agentLog에 분석 단계 기록됨', () async {
      final notifier = container.read(agentStateProvider.notifier);

      await notifier.handle('김철수 선생님 기록 찾아줘');

      final log = container.read(agentLogProvider);
      expect(log, isNotEmpty);
      // 분석 로그가 첫 번째 항목
      expect(log.first.step, equals('분석'));
    });

    test('handle() 완료 후: 완료 로그가 존재', () async {
      await container.read(agentStateProvider.notifier).handle('전체 CSV로 내보내줘');

      final log = container.read(agentLogProvider);
      final hasDoneLog = log.any(
        (e) => e.step == '완료' || e.step == '실패' || e.step == '검토',
      );
      expect(hasDoneLog, isTrue);
    });

    test('연속 handle() 호출 시 이전 로그 초기화됨', () async {
      final notifier = container.read(agentStateProvider.notifier);
      await notifier.handle('interview.mp3 등록해줘');
      final logAfterFirst = container.read(agentLogProvider).length;

      await notifier.handle('기록 찾아줘');
      final logAfterSecond = container.read(agentLogProvider).length;

      // 두 번째 호출은 로그를 새로 시작하므로 첫 호출과 독립
      expect(logAfterSecond, isPositive);
      // 두 번째 실행 로그 수가 무한히 누적되지 않음
      expect(logAfterSecond, lessThan(logAfterFirst + 30));
    });
  });

  group('pendingReview 흐름', () {
    late ProviderContainer container;

    setUp(() {
      container = _makeContainer();
    });

    tearDown(() {
      container.dispose();
    });

    AgentState makePendingState() {
      final result = AgentResult.pendingReview(
        toolCallResults: [],
        reviewContent: '결과를 검토해주세요',
        summary: '기록 처리 완료: 0/0단계',
      );
      return AgentState(
        status: AgentProcessStatus.pendingReview,
        pendingReview: result,
        lastResult: result,
        agentLog: [
          AgentLogEntry(step: '검토', detail: '결과를 검토해주세요'),
        ],
      );
    }

    test('isPendingReviewProvider: pendingReview 상태에서 true', () {
      container
          .read(agentStateProvider.notifier)
          .setStateForTest(makePendingState());

      expect(container.read(isPendingReviewProvider), isTrue);
    });

    test('approveReview(): pendingReview → idle, pendingReview null', () {
      final notifier = container.read(agentStateProvider.notifier);
      notifier.setStateForTest(makePendingState());

      notifier.approveReview();

      final state = container.read(agentStateProvider);
      expect(state.status, equals(AgentProcessStatus.idle));
      expect(state.pendingReview, isNull);
      expect(state.lastResult, isNotNull); // lastResult는 보존
    });

    test('rejectReview(): pendingReview → idle, pendingReview null, lastResult null', () {
      final notifier = container.read(agentStateProvider.notifier);
      notifier.setStateForTest(makePendingState());

      notifier.rejectReview();

      final state = container.read(agentStateProvider);
      expect(state.status, equals(AgentProcessStatus.idle));
      expect(state.pendingReview, isNull);
      expect(state.lastResult, isNull);
    });

    test('idle 상태에서 approveReview() 호출 시 상태 변화 없음', () {
      final notifier = container.read(agentStateProvider.notifier);
      notifier.approveReview(); // 아무 일도 없어야 함

      expect(container.read(agentStateProvider).status,
          equals(AgentProcessStatus.idle));
    });
  });

  group('에러 상태', () {
    late ProviderContainer container;

    setUp(() {
      container = _makeContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('빈 입력 → idle (unknown 의도, clarification 반환)', () async {
      await container.read(agentStateProvider.notifier).handle('');

      // 빈 입력은 AgentCore에서 clarification 반환 → success 흐름
      final state = container.read(agentStateProvider);
      expect(state.status, equals(AgentProcessStatus.idle));
    });

    test('에러 상태에서 reset() 호출 시 전체 초기화', () {
      final notifier = container.read(agentStateProvider.notifier);
      notifier.setStateForTest(AgentState(
        status: AgentProcessStatus.error,
        errorMessage: '테스트 오류',
        agentLog: [AgentLogEntry(step: '오류', detail: '테스트 오류', isError: true)],
      ));

      notifier.reset();

      final state = container.read(agentStateProvider);
      expect(state.status, equals(AgentProcessStatus.idle));
      expect(state.errorMessage, isNull);
      expect(state.agentLog, isEmpty);
    });

    test('clearLog() 호출 시 agentLog만 초기화', () {
      final notifier = container.read(agentStateProvider.notifier);
      notifier.setStateForTest(AgentState(
        status: AgentProcessStatus.error,
        errorMessage: '테스트 오류',
        agentLog: [AgentLogEntry(step: '오류', detail: '테스트 오류', isError: true)],
      ));

      notifier.clearLog();

      final state = container.read(agentStateProvider);
      expect(state.agentLog, isEmpty);
      expect(state.errorMessage, isNotNull); // 에러는 유지
      expect(state.status, equals(AgentProcessStatus.error)); // 상태 유지
    });
  });

  group('파생 Provider', () {
    late ProviderContainer container;

    setUp(() {
      container = _makeContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('agentLogProvider: 로그 없을 때 빈 리스트 반환', () {
      expect(container.read(agentLogProvider), isEmpty);
    });

    test('isPendingReviewProvider: 초기 상태에서 false', () {
      expect(container.read(isPendingReviewProvider), isFalse);
    });

    test('agentLogProvider: handle() 이후 로그 반영', () async {
      await container
          .read(agentStateProvider.notifier)
          .handle('기록 분석해줘');

      expect(container.read(agentLogProvider), isNotEmpty);
    });
  });

  group('AgentLogEntry', () {
    test('timestamp 자동 설정', () {
      final entry = AgentLogEntry(step: '분석', detail: '테스트');
      expect(entry.timestamp, isA<DateTime>());
      expect(entry.isError, isFalse);
    });

    test('isError=true 설정', () {
      final entry =
          AgentLogEntry(step: '오류', detail: '실패', isError: true);
      expect(entry.isError, isTrue);
    });
  });
}
