// 파일 목적: 메타데이터 폼 상태 관리 Provider
// 구술자/면담자/면담정보/기록분류 폼 상태

import 'package:riverpod/riverpod.dart';

class MetadataFormState {
  // ── 구술자 (기존 선택 또는 새로 생성) ──
  final String? narratorId;

  // ── 면담자 (기존 선택 또는 새로 생성) ──
  final String? interviewerId;

  // ── 면담 정보 ──
  final DateTime? interviewDate;
  final String? location;
  final int sessionNo;
  final String interviewType; // 'oral' | 'written' | 'phone'

  // ── 기록 분류 ──
  final String? mainCategory;
  final List<String> keywords;
  final String visibility; // 'public' | 'private'
  final String? notes;

  MetadataFormState({
    this.narratorId,
    this.interviewerId,
    this.interviewDate,
    this.location,
    this.sessionNo = 1,
    this.interviewType = 'oral',
    this.mainCategory,
    this.keywords = const [],
    this.visibility = 'private',
    this.notes,
  });

  /// 필수 항목: 구술자, 면담자, 면담 일시
  bool get isValid =>
      narratorId != null && interviewerId != null && interviewDate != null;

  MetadataFormState copyWith({
    String? narratorId,
    String? interviewerId,
    DateTime? interviewDate,
    String? location,
    int? sessionNo,
    String? interviewType,
    String? mainCategory,
    List<String>? keywords,
    String? visibility,
    String? notes,
  }) {
    return MetadataFormState(
      narratorId: narratorId ?? this.narratorId,
      interviewerId: interviewerId ?? this.interviewerId,
      interviewDate: interviewDate ?? this.interviewDate,
      location: location ?? this.location,
      sessionNo: sessionNo ?? this.sessionNo,
      interviewType: interviewType ?? this.interviewType,
      mainCategory: mainCategory ?? this.mainCategory,
      keywords: keywords ?? this.keywords,
      visibility: visibility ?? this.visibility,
      notes: notes ?? this.notes,
    );
  }
}

class MetadataFormNotifier extends StateNotifier<MetadataFormState> {
  MetadataFormNotifier() : super(MetadataFormState(
    interviewDate: DateTime.now(),
  ));

  void setNarrator(String narratorId) =>
      state = state.copyWith(narratorId: narratorId);

  void setInterviewer(String interviewerId) =>
      state = state.copyWith(interviewerId: interviewerId);

  void setInterviewDate(DateTime date) =>
      state = state.copyWith(interviewDate: date);

  void setLocation(String location) =>
      state = state.copyWith(location: location.isEmpty ? null : location);

  void setSessionNo(int no) => state = state.copyWith(sessionNo: no);

  void setInterviewType(String type) =>
      state = state.copyWith(interviewType: type);

  void setMainCategory(String? category) =>
      state = state.copyWith(mainCategory: category);

  void addKeyword(String keyword) {
    if (state.keywords.contains(keyword)) return;
    state = state.copyWith(keywords: [...state.keywords, keyword]);
  }

  void removeKeyword(String keyword) {
    state = state.copyWith(
      keywords: state.keywords.where((k) => k != keyword).toList(),
    );
  }

  void setVisibility(String visibility) =>
      state = state.copyWith(visibility: visibility);

  void setNotes(String notes) =>
      state = state.copyWith(notes: notes.isEmpty ? null : notes);

  void reset() {
    state = MetadataFormState(interviewDate: DateTime.now());
  }
}

final metadataFormProvider =
    StateNotifierProvider<MetadataFormNotifier, MetadataFormState>(
  (ref) => MetadataFormNotifier(),
);

final metadataFormValidProvider = Provider<bool>(
  (ref) => ref.watch(metadataFormProvider).isValid,
);
