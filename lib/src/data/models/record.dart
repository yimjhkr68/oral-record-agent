// 파일 목적: 기록(Record) 데이터 모델 정의
// 구술자 면담의 음성, 문서, 텍스트를 저장하는 핵심 데이터 모델
// 메타데이터(sessionId, narratorId, mainCategory, visibility) 필수 포함

import 'package:uuid/uuid.dart';
import 'pii_item.dart';

class Record {
  /// 기록 고유 ID (UUID)
  final String id;

  /// 기록 제목 (필수, 1-200자)
  /// 예: "김철수 구술자 2차 면담", "1990년대 시정 결정사"
  final String title;

  /// 전사된 텍스트 또는 문서 콘텐츠 (필수)
  /// inputType="audio": transcribeAudio 완료 후 텍스트
  /// inputType="document": parseDocument 완료 후 텍스트
  /// inputType="text": 사용자 직접 입력
  final String content;

  /// 입력 유형 (필수, "audio"/"document"/"text")
  /// audio: 실시간 녹음 또는 음성 파일
  /// document: 녹취 원문 문서 (txt/docx/pdf)
  /// text: 사용자 직접 입력
  final String inputType;

  /// 원본 음성 파일 경로 (선택, inputType="audio"일 때만)
  /// 예: "/storage/emulated/0/audio_20260323_123456.wav"
  final String? originalAudioPath;

  /// 원본 문서 파일 경로 (선택, inputType="document"일 때만)
  /// 예: "/storage/emulated/0/interview_001.docx"
  final String? originalDocPath;

  /// 원본 파일명 (document/audio 업로드 시)
  final String? originalFileName;

  /// 파일 크기 (bytes 단위, document/audio 업로드 시)
  final int? fileSize;

  /// 재생 시간 (초 단위, audio/video 파일에서 ffprobe로 측정)
  final int? duration;

  /// 사람이 읽기 쉬운 고유 식별자 (예: REC-202603-0001)
  final String? displayId;

  /// MIME 타입 (예: 'application/pdf', 'audio/mpeg')
  final String? mimeType;

  // ==================== 메타데이터 필드 (필수) ====================

  /// 면담 세션 ID (필수, InterviewSession 참조)
  /// 기록이 어느 면담에 속하는지 추적
  final String sessionId;

  /// 구술자 ID (필수, Narrator 참조)
  /// 기록이 어느 구술자의 면담인지 직접 참조 (검색 최적화)
  final String narratorId;

  /// 주제 대분류 (필수)
  /// 예: "정치사건", "경제정책", "문화콘텐츠", "개인사", "기타"
  /// classifyRecord 도구 또는 사용자 수동 입력
  final String mainCategory;

  /// 주제 소분류 (선택)
  /// 예: mainCategory="정치사건"일 때 subCategory="부정선거", "쿠데타"
  final String? subCategory;

  /// 키워드 태그 (선택, 1-20개)
  /// 예: ["1980년대", "군부정권", "민주화운동"]
  /// 검색 및 분류에 활용
  final List<String> keywordTags;

  /// 비공개 여부 (필수, "public"/"private"/"conditional")
  /// public: 모든 사용자 조회 가능
  /// private: 작성자(recordedBy)만 조회 가능
  /// conditional: 조건 만족 시 공개 (예: 2년 후)
  final String visibility;

  /// 기록 작성자/녹음자 (필수)
  /// 보안 정책: visibility="private" 일 때 recordedBy == currentUser 확인
  final String recordedBy;

  // ==================== 자동 처리 결과 필드 ====================

  /// 감지된 PII 목록 (detectPII 도구 결과)
  /// 이메일, 전화, SSN, 신용카드 등 민감 정보 저장
  /// UI: 마스킹 또는 하이라이팅 표시
  final List<PIIItem> detectedPII;

  /// 자동 분류 결과 (classifyRecord 도구 결과)
  /// Claude NLP로 자동 지정된 카테고리 (선택)
  final String? classification;

  /// AI 요약 (summarizeRecords 도구 결과)
  /// 기록을 한 문단으로 요약 (선택)
  final String? summary;

  /// 임시 태그 (선택, 최대 20개)
  /// keywordTags와는 별도로 사용자 임시 태그
  final List<String> tags;

  /// 레코드 생성 시각
  final DateTime createdAt;

  /// 레코드 마지막 수정 시각
  final DateTime updatedAt;

  /// 생성자
  Record({
    String? id,
    required this.title,
    required this.content,
    required this.inputType,
    this.originalAudioPath,
    this.originalDocPath,
    this.originalFileName,
    this.fileSize,
    this.duration,
    this.mimeType,
    this.displayId,
    required this.sessionId,
    required this.narratorId,
    required this.mainCategory,
    this.subCategory,
    List<String>? keywordTags,
    required this.visibility,
    required this.recordedBy,
    List<PIIItem>? detectedPII,
    this.classification,
    this.summary,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        keywordTags = keywordTags ?? [],
        detectedPII = detectedPII ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now() {
    // 제약 검증: title 길이
    assert(title.isNotEmpty && title.length <= 200, 'title은 1-200자여야 합니다');
    // 제약 검증: inputType 유효성
    assert(['audio', 'document', 'text', 'video', 'image'].contains(inputType),
        'inputType은 audio, document, text, video, image 중 하나여야 합니다');
    // 제약 검증: visibility 유효성
    assert(['public', 'private', 'conditional'].contains(visibility),
        'visibility은 public, private, conditional 중 하나여야 합니다');
    // 제약 검증: keywordTags 개수
    assert(this.keywordTags.length <= 20, 'keywordTags는 최대 20개입니다');
  }

  /// 복사 생성자 (사본 생성 시 일부 필드 변경)
  Record copyWith({
    String? title,
    String? content,
    String? narratorId,
    String? mainCategory,
    String? subCategory,
    List<String>? keywordTags,
    String? visibility,
    List<PIIItem>? detectedPII,
    String? classification,
    String? summary,
    List<String>? tags,
    DateTime? updatedAt,
    int? duration,
    String? displayId,
  }) {
    return Record(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      inputType: inputType,
      originalAudioPath: originalAudioPath,
      originalDocPath: originalDocPath,
      originalFileName: originalFileName,
      fileSize: fileSize,
      duration: duration ?? this.duration,
      mimeType: mimeType,
      displayId: displayId ?? this.displayId,
      sessionId: sessionId,
      narratorId: narratorId ?? this.narratorId,
      mainCategory: mainCategory ?? this.mainCategory,
      subCategory: subCategory ?? this.subCategory,
      keywordTags: keywordTags ?? this.keywordTags,
      visibility: visibility ?? this.visibility,
      recordedBy: recordedBy,
      detectedPII: detectedPII ?? this.detectedPII,
      classification: classification ?? this.classification,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// 객체 동등성 비교
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Record && runtimeType == other.runtimeType && id == other.id;

  /// 해시 코드 생성
  @override
  int get hashCode => id.hashCode;

  /// 문자열 표현
  @override
  String toString() =>
      'Record(id: $id, title: $title, inputType: $inputType, narratorId: $narratorId, createdAt: $createdAt)';
}
