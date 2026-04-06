// lib/agents/core/agent_intent.dart
// 사용자의 의도를 구조화한 데이터 모델

enum IntentType {
  registerRecord,  // "이 파일 등록해줘"
  searchRecord,    // "김철수 구술자 찾아줘"
  generateContent, // "3월 면담 보고서 만들어줘"
  analyzeRecord,   // "이 기록 분석해줘"
  managePersons,   // "인물사전 업데이트해줘"
  exportData,      // "CSV로 내보내줘"
  writeCreative,   // "소설로 써줘" / "생애 이야기 창작"
  writeAcademic,   // "학술 논문으로 작성해줘"
  writePopular,    // "교양서/평전으로 써줘"
  unknown,         // 분류 불가 → 사용자에게 되묻기
}

class AgentIntent {
  final IntentType type;
  final Map<String, dynamic> params;
  final String rawInput;       // 사용자가 실제로 입력한 원문
  final double confidence;     // 의도 분류 확신도 0.0~1.0

  const AgentIntent({
    required this.type,
    required this.rawInput,
    this.params = const {},
    this.confidence = 1.0,
  });

  /// 확신도가 낮으면 사용자 확인 필요
  bool get needsClarification => confidence < 0.6 || type == IntentType.unknown;

  /// 파일 등록 의도인지 확인
  bool get isFileRegistration =>
      type == IntentType.registerRecord && params.containsKey('filePath');

  /// 의도 타입을 한국어로 반환 (UI 표시용)
  String get typeLabel {
    switch (type) {
      case IntentType.registerRecord:   return '기록 등록';
      case IntentType.searchRecord:     return '기록 검색';
      case IntentType.generateContent:  return '콘텐츠 생성';
      case IntentType.analyzeRecord:    return '기록 분석';
      case IntentType.managePersons:    return '인물사전 관리';
      case IntentType.exportData:       return '데이터 내보내기';
      case IntentType.writeCreative:    return '창작 글쓰기';
      case IntentType.writeAcademic:    return '학술 논문';
      case IntentType.writePopular:     return '교양·대중서';
      case IntentType.unknown:          return '알 수 없음';
    }
  }

  @override
  String toString() =>
      'AgentIntent(type: $typeLabel, confidence: ${(confidence * 100).toInt()}%, '
      'params: $params)';
}
