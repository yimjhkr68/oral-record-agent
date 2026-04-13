// lib/agents/tools/tool_interface.dart
// 모든 에이전트 툴이 구현해야 하는 추상 인터페이스

/// 툴 실행 결과
class ToolResult {
  final bool success;
  final Map<String, dynamic> output; // 다음 툴로 체이닝될 데이터
  final String? errorMessage;
  final Duration executionTime;

  const ToolResult({
    required this.success,
    this.output = const {},
    this.errorMessage,
    this.executionTime = Duration.zero,
  });

  factory ToolResult.ok(Map<String, dynamic> output, Duration elapsed) =>
      ToolResult(success: true, output: output, executionTime: elapsed);

  factory ToolResult.err(String message, Duration elapsed) =>
      ToolResult(success: false, errorMessage: message, executionTime: elapsed);

  /// 다음 툴로 전달할 특정 키 값 추출
  T? get<T>(String key) => output[key] as T?;

  @override
  String toString() => success
      ? 'ToolResult(ok, ${executionTime.inMilliseconds}ms, keys: ${output.keys.join(", ")})'
      : 'ToolResult(err: $errorMessage)';
}

/// 툴 파라미터 스키마 정의 (Claude API tool_use 형식과 호환)
class ToolParam {
  final String name;
  final String type;        // 'string' | 'number' | 'boolean' | 'list'
  final String description;
  final bool required;
  final dynamic defaultValue;

  const ToolParam({
    required this.name,
    required this.type,
    required this.description,
    this.required = false,
    this.defaultValue,
  });

  Map<String, dynamic> toSchema() => {
        'type': type,
        'description': description,
        if (defaultValue != null) 'default': defaultValue,
      };
}

/// 모든 에이전트 툴의 추상 기반 클래스
abstract class AgentTool {
  /// 툴 이름 (ToolRegistry 키, Claude API tool name)
  String get name;

  /// Claude에게 전달되는 툴 설명 (명확할수록 계획 품질 향상)
  String get description;

  /// 입력 파라미터 목록
  List<ToolParam> get params;

  /// 실제 툴 실행 로직
  Future<ToolResult> execute(Map<String, dynamic> input);

  /// Claude API tool_use 형식의 스키마 반환
  Map<String, dynamic> toClaudeSchema() => {
        'name': name,
        'description': description,
        'input_schema': {
          'type': 'object',
          'properties': {
            for (final p in params) p.name: p.toSchema(),
          },
          'required': params.where((p) => p.required).map((p) => p.name).toList(),
        },
      };

  /// 필수 파라미터 누락 여부 검사
  String? validate(Map<String, dynamic> input) {
    for (final p in params.where((p) => p.required)) {
      if (!input.containsKey(p.name) || input[p.name] == null) {
        return '필수 파라미터 누락: ${p.name} ($description)';
      }
    }
    return null; // null = 검증 통과
  }

  /// validate 후 execute — 외부에서 항상 이 메서드를 사용
  Future<ToolResult> run(Map<String, dynamic> input) async {
    final error = validate(input);
    if (error != null) {
      return ToolResult.err(error, Duration.zero);
    }
    final sw = Stopwatch()..start();
    try {
      final result = await execute(input);
      sw.stop();
      return ToolResult(
        success: result.success,
        output: result.output,
        errorMessage: result.errorMessage,
        executionTime: sw.elapsed,
      );
    } catch (e) {
      sw.stop();
      return ToolResult.err('$name 실행 오류: $e', sw.elapsed);
    }
  }
}
