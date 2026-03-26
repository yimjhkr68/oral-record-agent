// lib/agents/tools/tool_registry.dart
// 에이전트가 사용할 수 있는 모든 툴을 등록하고 관리하는 레지스트리

import 'tool_interface.dart';
import 'tool_services.dart';
import 'tools.dart';

/// 파일 확장자 → 필요한 전처리 툴 이름 매핑
const Map<String, String> _extToTool = {
  'mp3': 'transcribe',
  'mp4': 'transcribe',
  'wav': 'transcribe',
  'm4a': 'transcribe',
  'webm': 'transcribe',
  'mov': 'transcribe',
  'pdf': 'extract_pdf',
  'docx': 'extract_docx',
};

/// ──────────────────────────────────────────────────────
/// ToolRegistry
///
/// 모든 AgentTool 인스턴스를 보관하고,
/// AgentCore가 이름으로 툴을 조회·실행할 수 있게 한다.
/// Claude API에 넘길 tool 스키마 목록도 여기서 생성한다.
///
/// 사용 예:
///   final registry = ToolRegistry.standard();
///   final result = await registry.run('transcribe', {'filePath': '...'});
/// ──────────────────────────────────────────────────────
class ToolRegistry {
  final Map<String, AgentTool> _tools;

  ToolRegistry(List<AgentTool> tools)
      : _tools = {for (final t in tools) t.name: t};

  /// 프로덕션용 — 10개 툴 전부 등록
  factory ToolRegistry.standard() => ToolRegistry([
        TranscribeTool(),
        ExtractPdfTool(),
        ExtractDocxTool(),
        SummarizeTool(),
        TagTool(),
        LinkPersonTool(),
        SaveRecordTool(),
        SearchTool(),
        ExportTool(),
        GenerateDocTool(),
      ]);

  /// 프로덕션용 — v1 실제 서비스 주입
  factory ToolRegistry.withServices(ToolServices services) => ToolRegistry([
        TranscribeTool(services),
        ExtractPdfTool(services),
        ExtractDocxTool(services),
        SummarizeTool(services),
        TagTool(services),
        LinkPersonTool(services),
        SaveRecordTool(services),
        SearchTool(services),
        ExportTool(services),
        GenerateDocTool(services),
      ]);

  /// 테스트용 — 원하는 툴만 주입
  factory ToolRegistry.withTools(List<AgentTool> tools) =>
      ToolRegistry(tools);

  // ─── 조회 ──────────────────────────────────────────

  /// 이름으로 툴 조회. 없으면 예외.
  AgentTool get(String name) {
    final tool = _tools[name];
    if (tool == null) throw ArgumentError('등록되지 않은 툴: $name');
    return tool;
  }

  /// 이름으로 툴 조회. 없으면 null.
  AgentTool? find(String name) => _tools[name];

  bool has(String name) => _tools.containsKey(name);

  List<String> get allNames => _tools.keys.toList();

  // ─── 실행 ──────────────────────────────────────────

  /// 툴 이름과 파라미터로 실행 (validate 포함)
  Future<ToolResult> run(String name, Map<String, dynamic> input) async {
    final tool = get(name);
    return tool.run(input);
  }

  // ─── Claude API 연동 ───────────────────────────────

  /// Claude API에 전달할 tools 배열 생성
  /// → claude_api_service.dart에서 systemPrompt와 함께 사용
  List<Map<String, dynamic>> toClaudeTools({List<String>? only}) {
    final targets = only != null
        ? _tools.values.where((t) => only.contains(t.name))
        : _tools.values;
    return targets.map((t) => t.toClaudeSchema()).toList();
  }

  /// 특정 Intent 타입에 필요한 툴만 추려서 Claude에 전달
  /// (컨텍스트 윈도우 절약)
  List<Map<String, dynamic>> toolsForIntent(String intentType) {
    const intentToolMap = {
      'registerRecord':  ['transcribe', 'extract_pdf', 'extract_docx',
                          'summarize', 'tag', 'link_person', 'save_record'],
      'searchRecord':    ['search'],
      'generateContent': ['search', 'generate_doc'],
      'analyzeRecord':   ['search', 'summarize'],
      'managePersons':   ['link_person', 'save_record'],
      'exportData':      ['export'],
    };

    final names = intentToolMap[intentType];
    if (names == null) return toClaudeTools();
    return toClaudeTools(only: names);
  }

  // ─── 파일 타입 헬퍼 ────────────────────────────────

  /// 파일 경로로 적절한 전처리 툴 이름 반환
  /// 예: '/path/file.mp3' → 'transcribe'
  String? preprocessToolFor(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _extToTool[ext];
  }

  /// 지원하는 파일 확장자 목록
  List<String> get supportedExtensions => _extToTool.keys.toList();

  bool supportsFile(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _extToTool.containsKey(ext);
  }

  @override
  String toString() => 'ToolRegistry(${_tools.length}개 툴: ${allNames.join(", ")})';
}
