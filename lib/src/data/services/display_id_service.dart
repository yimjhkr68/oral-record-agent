// 파일 목적: 사람이 읽기 쉬운 고유 식별자(displayId) 생성 서비스
// 형식: {PREFIX}-{YYYYMM}-{seq4}  예: REC-202603-0001

class DisplayIdService {
  /// Record용 displayId 생성
  /// [existingIds] : 해당 연월의 기존 displayId 목록
  static String generateRecordId(DateTime date, List<String> existingIds) {
    return _generate('REC', date, existingIds);
  }

  /// Narrator용 displayId 생성
  static String generateNarratorId(DateTime date, List<String> existingIds) {
    return _generate('NAR', date, existingIds);
  }

  /// Interviewer용 displayId 생성
  static String generateInterviewerId(DateTime date, List<String> existingIds) {
    return _generate('INT', date, existingIds);
  }

  static String _generate(
      String prefix, DateTime date, List<String> existingIds) {
    final yearMonth =
        '${date.year}${date.month.toString().padLeft(2, '0')}';
    final pattern = '$prefix-$yearMonth-';

    // 해당 연월의 기존 순번 추출
    int maxSeq = 0;
    for (final id in existingIds) {
      if (id.startsWith(pattern)) {
        final seqStr = id.substring(pattern.length);
        final seq = int.tryParse(seqStr) ?? 0;
        if (seq > maxSeq) maxSeq = seq;
      }
    }
    final nextSeq = (maxSeq + 1).toString().padLeft(4, '0');
    return '$pattern$nextSeq';
  }
}
