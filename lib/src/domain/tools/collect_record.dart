// 파일 목적: collectRecord 도구 구현
// 새로운 Record 객체 생성 후 Hive에 저장
// inputType(audio/document/text)에 따라 콘텐츠 또는 파일 경로 처리

import 'package:hive/hive.dart';
import '../../data/models/record.dart';
import '../../data/models/interview_session.dart';
import 'tool_base.dart';

/// collectRecord 도구
///
/// 책임:
/// 1. 입력 파라미터 검증 (title, inputType, sessionId, narratorId 필수)
/// 2. Record 객체 생성
/// 3. Hive records 박스에 저장
/// 4. 저장된 Record 객체 반환
///
/// 예외처리:
/// - ValidationException: title 길이 1-200, inputType 유효성, 필수 필드 누락
/// - DatabaseException: Hive 저장 실패, 세션/구술자 존재 확인 실패
class CollectRecordTool {
  /// Hive records 박스
  final Box<Record> recordsBox;

  /// Hive sessions 박스 (sessionId 유효성 확인용)
  final Box<InterviewSession> sessionsBox;

  /// 현재 사용자 ID
  final String currentUserId;

  CollectRecordTool({
    required this.recordsBox,
    required this.sessionsBox,
    required this.currentUserId,
  });

  /// 새로운 Record 생성 및 저장
  ///
  /// 파라미터:
  /// - title: 기록 제목 (필수, 1-200자)
  /// - content: 콘텐츠 (필수, inputType="text" 또는 임시값)
  /// - inputType: "audio", "document", "text" (필수)
  /// - sessionId: 면담 세션 ID (필수, 존재 확인)
  /// - narratorId: 구술자 ID (필수)
  /// - mainCategory: 주제 대분류 (선택, 기본값: "기타")
  /// - originalAudioPath: 음성 파일 경로 (inputType="audio"일 때)
  /// - originalDocPath: 문서 파일 경로 (inputType="document"일 때)
  ///
  /// 반환:
  /// - 저장된 Record 객체
  ///
  /// 예외:
  /// - ValidationException: 입력 검증 실패
  /// - DatabaseException: Hive 저장 실패, 세션 미존재
  Future<Record> execute({
    required String title,
    required String content,
    required String inputType,
    required String sessionId,
    required String narratorId,
    String mainCategory = '기타',
    String? originalAudioPath,
    String? originalDocPath,
  }) async {
    try {
      // 1단계: 입력 검증
      _validateInput(
        title: title,
        inputType: inputType,
        sessionId: sessionId,
        narratorId: narratorId,
      );

      // 2단계: 세션 존재 확인
      if (!sessionsBox.containsKey(sessionId)) {
        throw DatabaseException('세션 ID "$sessionId"를 찾을 수 없습니다');
      }

      // 3단계: Record 객체 생성
      final record = Record(
        title: title,
        content: content,
        inputType: inputType,
        originalAudioPath: originalAudioPath,
        originalDocPath: originalDocPath,
        sessionId: sessionId,
        narratorId: narratorId,
        mainCategory: mainCategory,
        visibility: 'private', // 기본값: 작성자만 보기
        recordedBy: currentUserId,
      );

      // 4단계: Hive에 저장
      await recordsBox.put(record.id, record);

      return record;
    } on ToolException {
      rethrow;
    } catch (e) {
      throw DatabaseException('Record 저장 중 오류: $e');
    }
  }

  /// 입력 파라미터 검증
  ///
  /// 검증 항목:
  /// - title: 비어있지 않고 1-200자
  /// - inputType: "audio", "document", "text" 중 하나
  /// - sessionId, narratorId: 비어있지 않음
  void _validateInput({
    required String title,
    required String inputType,
    required String sessionId,
    required String narratorId,
  }) {
    // title 검증
    if (title.isEmpty || title.length > 200) {
      throw ValidationException('title은 1-200자여야 합니다 (현재: ${title.length})');
    }

    // inputType 검증
    const validTypes = ['audio', 'document', 'text'];
    if (!validTypes.contains(inputType)) {
      throw ValidationException(
        'inputType은 ${validTypes.join(", ")} 중 하나여야 합니다 (현재: "$inputType")',
      );
    }

    // 필수 필드 검증
    if (sessionId.isEmpty) {
      throw ValidationException('sessionId는 필수입니다');
    }
    if (narratorId.isEmpty) {
      throw ValidationException('narratorId는 필수입니다');
    }
  }
}
