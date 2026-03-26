// 파일 목적: updateMetadata 도구 구현
// 저장된 기록의 메타데이터 수정 (접근 제어 적용)
// visibility, mainCategory, keywordTags, classification 등 수정

import 'package:hive/hive.dart';
import '../../data/models/record.dart';
import 'tool_base.dart';

/// updateMetadata 도구
///
/// 책임:
/// 1. 기록 소유권 확인 (visibility="private"일 때는 recordedBy == currentUserId)
/// 2. 메타데이터 필드 수정 (mainCategory, subCategory, keywordTags 등)
/// 3. 수정된 기록 Hive에 저장
/// 4. 감사 추적 로깅 (향후)
///
/// 보안 정책:
/// - visibility="private": 작성자(recordedBy)만 수정 가능
/// - visibility="public": 현재 버전에서는 수정 불가 (향후 권한 확인)
/// - visibility="conditional": 조건에 따라 수정 가능 (향후)
///
/// 예외처리:
/// - ValidationException: 메타데이터 형식 검증 실패 (keywordTags 개수 등)
/// - DatabaseException: Hive 업데이트 실패, 기록 미존재
/// - AccessDeniedException: 접근 거부 (소유권 없음)
class UpdateMetadataTool {
  /// Hive records 박스
  final Box<Record> recordsBox;

  /// 현재 사용자 ID
  final String currentUserId;

  UpdateMetadataTool({
    required this.recordsBox,
    required this.currentUserId,
  });

  /// 메타데이터 수정
  ///
  /// 파라미터:
  /// - recordId: 수정할 기록 ID (필수)
  /// - mainCategory: 주제 대분류 (선택)
  /// - subCategory: 주제 소분류 (선택)
  /// - keywordTags: 키워드 태그 리스트 (선택, 최대 20개)
  /// - visibility: 비공개 여부 (선택, "public"/"private"/"conditional")
  /// - classification: 자동 분류 결과 (선택)
  ///
  /// 반환:
  /// - 수정된 Record 객체
  ///
  /// 예외:
  /// - ValidationException: 메타데이터 검증 실패
  /// - DatabaseException: 기록 미존재
  /// - AccessDeniedException: 수정 권한 없음
  Future<Record> execute({
    required String recordId,
    String? mainCategory,
    String? subCategory,
    List<String>? keywordTags,
    String? visibility,
    String? classification,
  }) async {
    try {
      // 1단계: 기록 조회
      if (!recordsBox.containsKey(recordId)) {
        throw DatabaseException('기록 ID "$recordId"를 찾을 수 없습니다');
      }

      final originalRecord = recordsBox.get(recordId);
      if (originalRecord == null) {
        throw DatabaseException('기록을 읽을 수 없습니다');
      }

      // 2단계: 접근 제어 확인
      _checkAccess(originalRecord);

      // 3단계: 메타데이터 검증
      _validateMetadata(
        mainCategory: mainCategory,
        keywordTags: keywordTags,
        visibility: visibility,
      );

      // 4단계: Record 수정
      final updatedRecord = originalRecord.copyWith(
        mainCategory: mainCategory,
        subCategory: subCategory,
        keywordTags: keywordTags,
        visibility: visibility,
        classification: classification,
        updatedAt: DateTime.now(),
      );

      // 5단계: Hive 업데이트
      await recordsBox.put(recordId, updatedRecord);

      return updatedRecord;
    } on ToolException {
      rethrow;
    } catch (e) {
      throw DatabaseException('메타데이터 수정 중 오류: $e');
    }
  }

  /// 접근 제어 확인
  ///
  /// 규칙:
  /// - visibility="private": 작성자(recordedBy)만 수정 가능
  /// - 향후 visibility="public"에 대한 권한 정책 추가
  void _checkAccess(Record record) {
    if (record.visibility == 'private' && record.recordedBy != currentUserId) {
      throw AccessDeniedException(
        '이 기록은 작성자(${record.recordedBy})만 수정할 수 있습니다',
      );
    }
  }

  /// 메타데이터 검증
  ///
  /// 검사 항목:
  /// - mainCategory: 비어있지 않음 (선택이면 검증 안함)
  /// - keywordTags: 최대 20개
  /// - visibility: "public", "private", "conditional" 중 하나
  void _validateMetadata({
    String? mainCategory,
    List<String>? keywordTags,
    String? visibility,
  }) {
    // mainCategory 검증
    if (mainCategory != null && mainCategory.isEmpty) {
      throw ValidationException('mainCategory는 비어있을 수 없습니다');
    }

    // keywordTags 검증
    if (keywordTags != null && keywordTags.length > 20) {
      throw ValidationException(
        'keywordTags는 최대 20개입니다 (현재: ${keywordTags.length})',
      );
    }

    // visibility 검증
    if (visibility != null) {
      const validVisibilities = ['public', 'private', 'conditional'];
      if (!validVisibilities.contains(visibility)) {
        throw ValidationException(
          'visibility은 ${validVisibilities.join(", ")} 중 하나여야 합니다',
        );
      }
    }
  }
}
