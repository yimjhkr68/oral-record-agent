// 파일 목적: 검색/필터 상태 관리 Provider
// 검색 필터 조건 (구술자, 날짜, 주제 등)

import 'package:riverpod/riverpod.dart';
import '../../data/models/search_filters.dart';

/// 검색 필터 상태 관리자
class SearchFilterNotifier extends StateNotifier<SearchFilters> {
  SearchFilterNotifier() : super(SearchFilters());

  void setNarrator(String narratorId) {
    state = state.copyWith(narratorId: narratorId);
  }

  void setInterviewer(String interviewerId) {
    state = state.copyWith(interviewerId: interviewerId);
  }

  void setDateRange(DateTime start, DateTime end) {
    state = state.copyWith(startDate: start, endDate: end);
  }

  void setStartDate(DateTime date) {
    state = state.copyWith(startDate: date);
  }

  void setEndDate(DateTime date) {
    state = state.copyWith(endDate: date);
  }

  void setLocation(String location) {
    state = state.copyWith(location: location.isEmpty ? null : location);
  }

  void setMainCategory(String category) {
    state = state.copyWith(mainCategory: category.isEmpty ? null : category);
  }

  void setPrivacy(bool isPrivate) {
    state = state.copyWith(isPrivate: isPrivate);
  }

  void reset() {
    state = SearchFilters();
  }

  void setPage(int pageNumber) {
    final offset = (pageNumber - 1) * state.limit;
    state = state.copyWith(offset: offset);
  }
}

/// 검색 필터 Provider
final searchFilterProvider =
    StateNotifierProvider<SearchFilterNotifier, SearchFilters>(
  (ref) => SearchFilterNotifier(),
);
