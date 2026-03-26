// 파일 목적: SearchFilters 모델
// Provider에서 사용하는 검색/필터 조건 모델

class SearchFilters {
  final String? narratorId;
  final String? interviewerId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? location;
  final String? mainCategory;
  final bool? isPrivate;
  final int limit;
  final int offset;
  /// 텍스트 검색 (제목, displayId 포함)
  final String? query;

  SearchFilters({
    this.narratorId,
    this.interviewerId,
    this.startDate,
    this.endDate,
    this.location,
    this.mainCategory,
    this.isPrivate,
    this.limit = 20,
    this.offset = 0,
    this.query,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchFilters &&
          narratorId == other.narratorId &&
          interviewerId == other.interviewerId &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          location == other.location &&
          mainCategory == other.mainCategory &&
          isPrivate == other.isPrivate &&
          limit == other.limit &&
          offset == other.offset &&
          query == other.query;

  @override
  int get hashCode => Object.hash(
        narratorId,
        interviewerId,
        startDate,
        endDate,
        location,
        mainCategory,
        isPrivate,
        limit,
        offset,
        query,
      );

  SearchFilters copyWith({
    String? narratorId,
    String? interviewerId,
    DateTime? startDate,
    DateTime? endDate,
    String? location,
    String? mainCategory,
    bool? isPrivate,
    int? limit,
    int? offset,
    String? query,
  }) {
    return SearchFilters(
      narratorId: narratorId ?? this.narratorId,
      interviewerId: interviewerId ?? this.interviewerId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      mainCategory: mainCategory ?? this.mainCategory,
      isPrivate: isPrivate ?? this.isPrivate,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
      query: query ?? this.query,
    );
  }
}
