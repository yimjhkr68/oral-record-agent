// lib/agents/core/task_planner.dart
// 자연어 입력 → MultiStepTask 분해 (IntentParser의 상위 레이어)
//
// 단일 작업: MultiStepTask(steps: [단일 Intent])
// 멀티스텝: 기록 목록 조회 → 각 기록마다 Intent 생성

import 'agent_intent.dart';
import 'intent_parser.dart';
import 'multi_step_task.dart';
import '../../src/data/repositories/record_repository.dart';
import '../../src/data/models/record.dart';
import '../../src/data/models/search_filters.dart';

class TaskPlanner {
  final IntentParser _intentParser;
  final RecordRepository? _recordRepo;

  /// [claudeApiKey]: null 이면 규칙 기반 파싱만 사용
  /// [recordRepo]: null 이면 스텁 모드 (테스트/Hive 미초기화)
  TaskPlanner({
    String? claudeApiKey,
    RecordRepository? recordRepo,
  })  : _intentParser = IntentParser(claudeApiKey: claudeApiKey),
        _recordRepo = recordRepo;

  // ─── 공개 API ────────────────────────────────────────

  /// 사용자 입력을 MultiStepTask로 변환
  /// 단일 Intent도 steps=[1개] 태스크로 래핑됨
  Future<MultiStepTask> plan(String userInput) async {
    if (!_isMultiStep(userInput)) {
      final intent = await _intentParser.parse(userInput);
      return MultiStepTask(
        title: intent.typeLabel,
        steps: [TaskStep(intent: intent)],
      );
    }

    final steps = await _buildMultiSteps(userInput);
    return MultiStepTask(
      title: _extractTitle(userInput),
      steps: steps,
    );
  }

  // ─── 멀티스텝 감지 ────────────────────────────────────

  /// 복수 대상 + 동작 키워드 조합이면 멀티스텝으로 판단
  static const _multiKeywords = [
    '전부', '모두', '전체', '일괄',
    '이번 달', '이번달', '지난달',
    '이번 주', '이번주', '지난주', '올해',
    '목록',
  ];
  static const _actionKeywords = ['정리', '처리', '등록', '분석', '해줘'];

  bool _isMultiStep(String input) {
    final hasMulti = _multiKeywords.any((kw) => input.contains(kw));
    final hasAction = _actionKeywords.any((kw) => input.contains(kw));
    return hasMulti && hasAction;
  }

  // ─── 멀티스텝 분해 ────────────────────────────────────

  Future<List<TaskStep>> _buildMultiSteps(String userInput) async {
    if (_recordRepo == null) {
      // 스텁 모드: 샘플 3단계 생성 (테스트/미리보기용)
      return List.generate(
        3,
        (i) => TaskStep(
          intent: AgentIntent(
            type: IntentType.analyzeRecord,
            rawInput: userInput,
            params: {'query': '샘플 기록 ${i + 1}'},
            confidence: 0.9,
          ),
        ),
      );
    }

    final (startDate, endDate) = _parsePeriod(userInput);

    List<Record> records;
    try {
      records = await _recordRepo!.searchRecords(
        SearchFilters(startDate: startDate, endDate: endDate, limit: 20),
      );
    } catch (_) {
      records = [];
    }

    if (records.isEmpty) {
      // 해당 기간 기록이 없음을 알리는 단계 1개
      return [
        TaskStep(
          intent: AgentIntent(
            type: IntentType.unknown,
            rawInput: userInput,
            confidence: 0.0,
          ),
        ),
      ];
    }

    return records
        .map(
          (rec) => TaskStep(
            intent: AgentIntent(
              type: IntentType.analyzeRecord,
              rawInput: '${rec.title} 분석해줘',
              params: {'recordId': rec.id, 'query': rec.title},
              confidence: 1.0,
            ),
          ),
        )
        .toList();
  }

  // ─── 날짜 범위 파싱 ───────────────────────────────────

  (DateTime?, DateTime?) _parsePeriod(String input) {
    final now = DateTime.now();

    if (input.contains('이번 달') || input.contains('이번달')) {
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return (start, end);
    }
    if (input.contains('지난달')) {
      final startMonth = now.month == 1
          ? DateTime(now.year - 1, 12, 1)
          : DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (startMonth, end);
    }
    if (input.contains('이번 주') || input.contains('이번주')) {
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final start = DateTime(monday.year, monday.month, monday.day);
      final end = start.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );
      return (start, end);
    }
    if (input.contains('지난주')) {
      final lastMon = now.subtract(Duration(days: now.weekday + 6));
      final start = DateTime(lastMon.year, lastMon.month, lastMon.day);
      final end = start.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );
      return (start, end);
    }
    if (input.contains('올해')) {
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31, 23, 59, 59);
      return (start, end);
    }
    return (null, null);
  }

  // ─── 태스크 제목 추출 ─────────────────────────────────

  String _extractTitle(String input) {
    final cleaned = input
        .replaceAll('전부', '')
        .replaceAll('모두', '')
        .replaceAll('전체', '')
        .replaceAll('일괄', '')
        .replaceAll('해줘', '')
        .replaceAll('해 줘', '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? '일괄 처리' : cleaned;
  }
}
