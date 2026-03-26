// lib/agents/tools/tool_services.dart
// 툴에 주입할 v1 서비스 번들
//
// ToolRegistry.withServices(ToolServices(...)) 로 사용.
// null이면 각 Tool이 스텁 모드로 동작 (테스트/미리보기용).

import '../../src/data/repositories/record_repository.dart';
import '../../src/data/repositories/narrator_repository.dart';

class ToolServices {
  /// Anthropic API 키 (SummarizeTool, TagTool 용)
  final String? claudeApiKey;

  /// Python 실행 경로 (Transcribe/Extract/GenerateDoc 용)
  final String pythonPath;

  /// Whisper 모델 크기 (tiny/base/small/medium/large)
  final String whisperModel;

  /// 전사 언어 코드 (TranscribeTool 기본값)
  final String transcriptionLanguage;

  /// 기록 저장소 (SaveRecordTool, SearchTool, ExportTool 용)
  final RecordRepository? recordRepo;

  /// 구술자 저장소 (LinkPersonTool 용)
  final NarratorRepository? narratorRepo;

  const ToolServices({
    this.claudeApiKey,
    this.pythonPath = 'python',
    this.whisperModel = 'base',
    this.transcriptionLanguage = 'ko',
    this.recordRepo,
    this.narratorRepo,
  });
}
