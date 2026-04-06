# 구술기록관리 에이전트 v2.0 아키텍처 문서

**버전**: 2.0.0-draft
**브랜치**: v2-agent
**작성일**: 2026-03-26
**기반**: v1.0 완성본 (tag: v1.0)

---

## 1. v1 → v2 전환 원칙

### 핵심 철학 변화

| 구분 | v1 (시스템) | v2 (에이전트) |
|------|------------|--------------|
| 중심 | UI 화면 | AgentCore 루프 |
| 사용자 역할 | 기능을 직접 조작 | 의도(Intent)를 전달 |
| 실행 주체 | 사람 | 에이전트 |
| Claude API 역할 | 요약 생성 도구 | 판단·계획·실행의 두뇌 |
| 결과 검증 | 사람이 확인 | 에이전트가 자동 검증 후 사람이 최종 승인 |

### 재활용 vs 신규 개발

- **재활용 (그대로 유지)**: Whisper 전사, Claude API 서비스, Hive DB, Python 스크립트 6종, 인물사전, 식별자 체계, CSV/JSON 내보내기
- **리팩토링**: Flutter UI (에이전트 인터페이스로 개편), Riverpod Provider 구조
- **신규 개발**: AgentCore, ToolRegistry, IntentParser, AgentMemory, TaskQueue

---

## 2. 전체 아키텍처 개요

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                      │
│  IntentInput  │  AgentChatPanel  │  ReviewPanel          │
└──────────────────────┬──────────────────────────────────┘
                       │ Intent
┌──────────────────────▼──────────────────────────────────┐
│                   AgentCore (신규)                       │
│                                                         │
│  IntentParser → Planner → Executor → Reflector          │
│        └─────────── AgentMemory ──────────┘             │
└──────┬───────────────────────────────────┬──────────────┘
       │ Tool calls                        │ State
┌──────▼──────────┐               ┌────────▼──────────────┐
│  ToolRegistry   │               │   AgentState          │
│  (신규)         │               │   (Riverpod)          │
│ - transcribe    │               │ - taskQueue           │
│ - summarize     │               │ - currentTask         │
│ - tag           │               │ - agentLog            │
│ - link_person   │               │ - pendingReview       │
│ - save_record   │               └───────────────────────┘
│ - export        │
│ - generate      │
│ - search        │
└──────┬──────────┘
       │
┌──────▼──────────────────────────────────────────────────┐
│                  기존 서비스 레이어 (v1 재활용)           │
│  WhisperService │ ClaudeApiService │ HiveDB │ PythonBridge│
└─────────────────────────────────────────────────────────┘
```

---

## 3. 핵심 컴포넌트 상세 설계

### 3-1. AgentCore

에이전트의 두뇌. 모든 작업 요청이 이곳을 통과한다.

```dart
// lib/agents/core/agent_core.dart
class AgentCore {
  final ToolRegistry _tools;
  final AgentMemory _memory;
  final ClaudeApiService _claude;

  /// 사용자의 의도를 받아 전체 에이전트 루프 실행
  Future<AgentResult> handle(AgentIntent intent) async {
    // 1. Plan: Claude가 실행 계획 수립
    final plan = await _plan(intent);

    // 2. Do: 계획에 따라 툴 순차 실행
    final results = await _execute(plan);

    // 3. Check: 결과 품질 자동 검증
    final verified = await _verify(results, intent);

    // 4. Act: 검증 통과 시 저장, 실패 시 재시도 또는 사용자에게 질문
    return await _act(verified);
  }
}
```

**AgentCore의 4단계 루프 (PDCA 런타임 구현)**

| 단계 | 메서드 | 역할 |
|------|--------|------|
| Plan | `_plan()` | Claude API로 실행 계획 JSON 생성 |
| Do | `_execute()` | ToolRegistry에서 툴 순차 호출 |
| Check | `_verify()` | 결과 완전성·품질 자동 검증 |
| Act | `_act()` | 저장 or 재시도 or 사용자 질문 |

---

### 3-2. IntentParser

사용자 입력을 구조화된 의도(Intent) 객체로 변환한다.

```dart
// lib/agents/core/intent_parser.dart
class AgentIntent {
  final IntentType type;         // REGISTER, SEARCH, GENERATE, ANALYZE, MANAGE
  final Map<String, dynamic> params;
  final String rawInput;
  final double confidence;       // 0.0 ~ 1.0
}

enum IntentType {
  registerRecord,   // "이 파일 등록해줘"
  searchRecord,     // "김철수 구술자 찾아줘"
  generateContent,  // "3월 면담 보고서 만들어줘"
  analyzeRecord,    // "이 기록 분석해줘"
  managePersons,    // "인물사전 업데이트해줘"
  exportData,       // "CSV로 내보내줘"
}
```

---

### 3-3. ToolRegistry

에이전트가 호출할 수 있는 모든 도구를 등록·관리한다.
v1의 서비스들을 Tool 인터페이스로 감싸는 어댑터 패턴 사용.

```dart
// lib/agents/tools/tool_registry.dart
abstract class AgentTool {
  String get name;
  String get description;         // Claude에게 전달되는 툴 설명
  Map<String, dynamic> get schema; // 입력 파라미터 스키마

  Future<ToolResult> execute(Map<String, dynamic> params);
}

// 등록되는 툴 목록
class ToolRegistry {
  final tools = {
    'transcribe':    TranscribeTool(),    // WhisperService 래핑
    'summarize':     SummarizeTool(),     // ClaudeApiService 래핑
    'tag':           TagTool(),           // 자동 태그 생성
    'link_person':   LinkPersonTool(),    // 인물사전 연결
    'save_record':   SaveRecordTool(),    // HiveDB 저장
    'search':        SearchTool(),        // 기록 검색
    'export':        ExportTool(),        // CSV/JSON 내보내기
    'generate_doc':  GenerateDocTool(),   // 책/보고서 생성
  };
}
```

---

### 3-4. AgentMemory

에이전트의 작업 컨텍스트와 단기 기억을 관리한다.

```dart
// lib/agents/core/agent_memory.dart
class AgentMemory {
  // 현재 세션의 대화 히스토리 (Claude API context)
  List<Message> conversationHistory = [];

  // 현재 처리 중인 태스크 컨텍스트
  TaskContext? currentContext;

  // 최근 처리 기록 (재시도, 오류 패턴 파악용)
  List<TaskLog> recentLogs = [];

  // Claude API에 전달할 컨텍스트 구성
  List<Message> buildContext(AgentIntent intent) { ... }
}
```

---

### 3-5. Claude API 프롬프트 구조 (v2 핵심)

v2에서 Claude는 단순 요약 도구가 아니라 **에이전트의 두뇌**로 작동한다.

```python
# scripts/agent_brain.py

AGENT_SYSTEM_PROMPT = """
당신은 구술기록관리 에이전트입니다.

## 역할
구술 기록(음성/영상/텍스트)을 전문적으로 처리하고 아카이빙하는 AI 에이전트입니다.

## 사용 가능한 도구
{tool_descriptions}

## 처리 원칙
1. 입력을 받으면 필요한 처리 단계를 계획하세요
2. 각 단계를 순서대로 실행하세요
3. 결과의 완전성을 검증하세요
4. 불확실한 경우 사용자에게 확인을 요청하세요

## 출력 형식
항상 JSON으로 응답하세요:
{
  "plan": ["단계1", "단계2", ...],
  "tool_calls": [{"tool": "tool_name", "params": {...}}, ...],
  "confidence": 0.0~1.0,
  "needs_human_review": true/false,
  "review_reason": "검토가 필요한 이유 (있을 경우)"
}
"""
```

---

## 4. 폴더 구조 변경 계획

### v2 목표 구조

```
lib/
├── agents/
│   ├── core/                    # [신규] AgentCore 핵심
│   │   ├── agent_core.dart
│   │   ├── intent_parser.dart
│   │   ├── agent_memory.dart
│   │   └── agent_result.dart
│   ├── tools/                   # [신규] ToolRegistry
│   │   ├── tool_registry.dart
│   │   ├── tool_interface.dart
│   │   ├── transcribe_tool.dart
│   │   ├── summarize_tool.dart
│   │   ├── tag_tool.dart
│   │   ├── link_person_tool.dart
│   │   ├── save_record_tool.dart
│   │   ├── search_tool.dart
│   │   ├── export_tool.dart
│   │   └── generate_doc_tool.dart
│   ├── check/                   # [유지] 기존 체크리스트 엔진
│   │   └── (v1 파일 유지)
│   ├── do/                      # [유지] 기존 실행 모듈
│   └── plan/                    # [업데이트] 아키텍처 문서 추가
│       ├── v2_architecture.md   # ← 이 문서
│       └── (v1 문서 유지)
├── src/
│   ├── services/                # [유지] v1 서비스 재활용
│   │   ├── whisper_service.dart
│   │   ├── claude_api_service.dart
│   │   └── hive_service.dart
│   ├── ui/                      # [리팩토링] 에이전트 UI로 개편
│   │   ├── agent_chat_panel.dart    # [신규] 에이전트 대화 패널
│   │   ├── intent_input_widget.dart # [신규] 의도 입력 위젯
│   │   ├── review_panel.dart        # [신규] 검토/승인 패널
│   │   └── (v1 화면 유지, 점진적 교체)
│   └── state/                   # [리팩토링] Riverpod 상태
│       ├── agent_state_provider.dart  # [신규]
│       └── (v1 provider 유지)
└── main.dart
```

---

## 5. 개발 로드맵

### Phase 1 — 에이전트 기반 구조 (2주)
- [ ] `AgentCore` 클래스 기본 구현
- [ ] `ToolRegistry` + `AgentTool` 인터페이스
- [ ] v1 서비스들을 Tool로 래핑 (8개 툴)
- [ ] `AgentMemory` 기본 구현
- [ ] Claude API 에이전트 프롬프트 설계

### Phase 2 — 핵심 플로우 구현 (2주)
- [ ] `IntentParser` 구현 (5가지 Intent)
- [ ] 파일 등록 에이전트 플로우 완성 (전사→요약→태깅→저장 자동화)
- [ ] PDCA 런타임 루프 (`_plan` → `_execute` → `_verify` → `_act`)
- [ ] 에이전트 상태 Riverpod Provider

### Phase 3 — UI 연동 (1주)
- [ ] `AgentChatPanel` (에이전트와 대화하는 채팅 UI)
- [ ] `IntentInputWidget` (자연어 의도 입력)
- [ ] `ReviewPanel` (에이전트 결과 검토/승인)
- [ ] v1 UI와 병렬 운영 (점진적 전환)

### Phase 4 — 고도화 (지속)
- [ ] 멀티스텝 태스크 (예: "이번 달 기록 전부 정리해줘")
- [ ] 에이전트 학습 (자주 쓰는 패턴 기억)
- [ ] 서브에이전트 분화 (등록/검색/생성 전담 에이전트)
- [ ] 에이전트 실행 로그 대시보드

---

## 6. v1 호환성 유지 전략

v2 개발 중에도 v1 기능이 모두 동작해야 한다.

1. **기존 서비스 파일 수정 금지** — Tool 래퍼를 새 파일로 생성
2. **기존 Riverpod Provider 유지** — 에이전트 전용 Provider 별도 추가
3. **기존 UI 화면 유지** — `AgentChatPanel`을 새 탭/화면으로 추가
4. **Hive DB 스키마 유지** — v2 전용 필드는 optional로만 추가
5. **feature flag 사용** — `useAgentMode: bool` 설정으로 v1/v2 전환 가능

---

## 7. 다음 작업

이 문서 확정 후 **Phase 1 첫 번째 작업**: `AgentCore` 클래스 구현

```
lib/agents/core/agent_core.dart      ← 다음 작업
lib/agents/core/agent_result.dart    ← 다음 작업
lib/agents/tools/tool_interface.dart ← 다음 작업
```
