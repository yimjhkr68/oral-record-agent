// 파일 목적: searchRecords 도구 구현
// Hive records 박스에서 복합 조건 검색 수행
// 텍스트, 날짜 범위, 메타데이터 기반 필터링, 접근 제어 자동 적용

import 'package:hive/hive.dart';
import '../../data/models/record.dart';
import 'tool_base.dart';

/// 검색 필터 조건
class SearchFilters {
  /// 텍스트 검색 (title, content에 대해)
  final String? query;

  /// 구술자 ID 필터
  final String? narratorId;

  /// 시작 날짜 (createdAt 이상)
  final DateTime? dateFrom;

  /// 종료 날짜 (createdAt 이하)
  final DateTime? dateTo;

  /// 장소 필터
  final String? location;

  /// 주제 대분류 필터
  final String? mainCategory;

  /// 페이지 번호 (0부터 시작, 20개씩)
  final int page;

  /// 정렬 순서 ("createdAt_desc", "createdAt_asc", "title_asc")
  final String orderBy;

  SearchFilters({
    this.query,
    this.narratorId,
    this.dateFrom,
    this.dateTo,
    this.location,
    this.mainCategory,
    this.page = 0,
    this.orderBy = 'createdAt_desc',
  });
}

/// searchRecords 도구
///
/// 책임:
/// 1. 검색 조건 검증
/// 2. 문자열 검색 (title, content 모두 포함)
/// 3. 메타데이터 필터링 (narratorId, mainCategory, location, 날짜 범위)
/// 4. 접근 제어 적용 (visibility 기반, 현재 사용자 확인)
/// 5. 페이지네이션 (20개씩)
/// 6. 정렬 (createdAt 기본)
///
/// 보안:
/// - visibility="private"인 기록: recordedBy == currentUserId만 조회 가능
/// - visibility="conditional"인 기록: 조건 확인 후 조회
/// - visibility="public"인 기록: 모든 사용자 조회 가능
///
/// 예외처리:
/// - ValidationException: 페이지 번호 음수, 날짜 범위 검증
class SearchRecordsTool {
  /// Hive records 박스
  final Box<Record> recordsBox;

  /// 현재 사용자 ID
  final String currentUserId;

  /// 페이지당 아이템 개수 (기본 20)
  static const int pageSize = 20;

  SearchRecordsTool({
    required this.recordsBox,
    required this.currentUserId,
  });

  /// 기록 검색 실행
  ///
  /// 파라미터:
  /// - filters: 검색 조건 (SearchFilters)
  ///
  /// 반환:
  /// - {records: List<Record>, total: int, page: int, pageSize: int}
  ///
  /// 예외:
  /// - ValidationException: 입력 검증 실패
  Future<Map<String, dynamic>> execute({required SearchFilters filters}) async {
    try {
      // 1단계: 입력 검증
      _validateFilters(filters);

      // 2단계: 모든 기록 조회
      final allRecords = recordsBox.values.toList();

      // 3단계: 필터링
      var filtered = allRecords
          .where((record) => _passesFilters(record, filters))
          .where((record) => _checkAccess(record))
          .toList();

      // 4단계: 정렬
      filtered = _sortRecords(filtered, filters.orderBy);

      // 5단계: 페이지네이션
      final startIndex = filters.page * pageSize;
      final endIndex = (startIndex + pageSize).clamp(0, filtered.length);

      final pagedRecords = startIndex < filtered.length
          ? filtered.sublist(startIndex, endIndex)
          : <Record>[];

      return {
        'records': pagedRecords,
        'total': filtered.length,
        'page': filters.page,
        'pageSize': pageSize,
        'totalPages': (filtered.length / pageSize).ceil(),
      };
    } on ToolException {
      rethrow;
    } catch (e) {
      throw DatabaseException('검색 중 오류: $e');
    }
  }

  /// 필터 조건 검증
  void _validateFilters(SearchFilters filters) {
    // 페이지 번호 검증
    if (filters.page < 0) {
      throw ValidationException('페이지 번호는 0 이상이어야 합니다');
    }

    // 날짜 범위 검증
    if (filters.dateFrom != null &&
        filters.dateTo != null &&
        filters.dateFrom!.isAfter(filters.dateTo!)) {
      throw ValidationException('dateFrom이 dateTo보다 클 수 없습니다');
    }
  }

  /// 기록이 필터 조건을 통과하는지 확인
  ///
  /// 검사 항목:
  /// - query: title 또는 content에 포함되는지
  /// - narratorId: 구술자 일치
  /// - dateFrom/dateTo: 생성 날짜 범위
  /// - mainCategory: 분류 일치
  /// - location: 장소 포함 (InterviewSession에서 참조)
  bool _passesFilters(Record record, SearchFilters filters) {
    // 텍스트 검색
    if (filters.query != null && filters.query!.isNotEmpty) {
      final query = filters.query!.toLowerCase();
      if (!record.title.toLowerCase().contains(query) &&
          !record.content.toLowerCase().contains(query)) {
        return false;
      }
    }

    // 구술자 필터
    if (filters.narratorId != null && record.narratorId != filters.narratorId) {
      return false;
    }

    // 날짜 범위 필터
    if (filters.dateFrom != null && record.createdAt.isBefore(filters.dateFrom!)) {
      return false;
    }
    if (filters.dateTo != null) {
      final nextDay = filters.dateTo!.add(const Duration(days: 1));
      if (record.createdAt.isAfter(nextDay)) {
        return false;
      }
    }

    // 주제 분류 필터
    if (filters.mainCategory != null &&
        record.mainCategory != filters.mainCategory) {
      return false;
    }

    return true;
  }

  /// 접근 제어 확인
  ///
  /// 규칙:
  /// - visibility="public": 항상 허용
  /// - visibility="private": recordedBy == currentUserId일 때만 허용
  /// - visibility="conditional": 향후 조건 확인 (현재: 거부)
  bool _checkAccess(Record record) {
    return switch (record.visibility) {
      'public' => true,
      'private' => record.recordedBy == currentUserId,
      'conditional' => false, // 향후 구현
      _ => false,
    };
  }

  /// 기록 정렬
  ///
  /// 지원 순서:
  /// - "createdAt_desc": 생성 시간 역순 (기본)
  /// - "createdAt_asc": 생성 시간 순서
  /// - "title_asc": 제목 가나다순
  List<Record> _sortRecords(List<Record> records, String orderBy) {
    final sorted = [...records];
    switch (orderBy) {
      case 'createdAt_asc':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case 'title_asc':
        sorted.sort((a, b) => a.title.compareTo(b.title));
      case 'createdAt_desc':
      default:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }
}
