# Check Phase Report — Windows 버전

- 작성일: 2026-03-24
- 검사 대상: 구술기록관리 Flutter Windows 앱
- 검사 방법: 전체 코드 정적 분석 + 시나리오 추적

---

## C1. flutter analyze

```
119 issues found (모두 info 수준)
error 0, warning 0
```
**결과: ✅ PASS**

---

## C2. flutter test

```
(Windows 전환 후 재실행 필요)
```
**결과: ⏳ 확인 필요**

---

## C3. 전 화면 구현 검증

| 라우트 | 파일 | 상태 |
|--------|------|------|
| `/` | home_page.dart | ✅ |
| `/recording` | record_input_pages.dart | ⚠️ 녹음→저장 미연결 |
| `/file-picker` | record_input_pages.dart | ✅ |
| `/text-input` | record_input_pages.dart | ✅ |
| `/metadata-input` | metadata_input_page.dart | ✅ |
| `/records` | record_list_page.dart | ✅ |
| `/records/search-filter` | search_filter_page.dart | ⚠️ 날짜 필터 버그 |
| `/records/detail/:id` | record_detail_page.dart | ⚠️ 요약 다이얼로그 취소 없음 |
| `/settings` | settings_page.dart | ✅ |

---

## C4. 발견된 버그 목록

### [BUG-1] RecordingPage: 녹음 저장 시 pendingContent 미설정 — 심각도: CRITICAL
- **위치**: `lib/src/presentation/pages/record_input_pages.dart:50-52`
- **증상**: `_saveRecording()`이 pendingContentProvider에 아무것도 설정하지 않고 /metadata-input으로 이동
  → MetadataInputPage에서 `pending = null` → bytes=null, fileName=null로 저장됨
- **원인**: RecordingPage가 StatefulWidget (ref 없음) → pendingContentProvider 접근 불가
- **수정**: ConsumerStatefulWidget으로 변환, _saveRecording()에서 PendingContent 설정

### [BUG-2] RecordDetailPage: 요약 다이얼로그에 취소 버튼 없음 — 심각도: HIGH
- **위치**: `lib/src/presentation/pages/record_detail_page.dart:267-276`
- **증상**: `_showSummaryConfirmDialog` actions에 "다시 생성", "저장하기"만 있고 "취소" 없음
  + `barrierDismissible: false`로 배경 터치도 막혀있어 탈출 불가
- **수정**: "취소" TextButton 추가 (null pop)

### [BUG-3] SearchFilterPage: 날짜 필터 — 한쪽이 null이면 설정 불가 — 심각도: MEDIUM
- **위치**: `lib/src/presentation/pages/search_filter_page.dart:72, 103`
- **증상**: 시작일 선택 시 종료일이 null이면 조건 `filters.endDate != null` 실패 → 날짜 저장 안 됨
  종료일 선택 시 시작일이 null이어도 동일 문제
- **수정**: SearchFilterNotifier에 setStartDate/setEndDate 독립 메서드 추가

### [BUG-4] MetadataInputPage: 주제(mainCategory) 필수지만 UI에 표시 없음 — 심각도: LOW
- **위치**: `lib/src/presentation/pages/metadata_input_page.dart:219-250`
  `lib/src/presentation/providers/metadata_form_provider.dart:31`
- **증상**: isValid에 mainCategory != null 포함 (필수) 이지만 라벨에 * 없음
  → 사용자가 주제를 선택하지 않으면 저장 버튼이 비활성화되는데 이유를 모름
- **수정**: "주제 분류" 라벨을 "주제 분류 *"로 변경

### [BUG-5] RecordListPage: FAB이 녹음만 가능 — 심각도: LOW
- **위치**: `lib/src/presentation/pages/record_list_page.dart:78-81`
- **증상**: FAB 클릭 시 `/recording`으로만 이동, 파일 업로드/텍스트 입력 접근 불가
- **수정**: FAB 클릭 시 입력 방식 선택 BottomSheet 표시

### [BUG-6] RecordDetailPage: 삭제 후 fileStorage 정리 없음 — 심각도: MEDIUM
- **위치**: `lib/src/presentation/pages/record_detail_page.dart:690-702`
- **증상**: 기록 삭제 시 Hive 레코드만 삭제, Documents/OralRecordAgent/files/{id}/ 디렉터리는 남음
- **수정**: deleteRecord 호출 전 fileStorage.deleteFile(record.id) 호출

---

## 품질 기준 달성 여부

| 기준 | 상태 |
|------|------|
| 전체 시나리오 오류 0건 | ❌ BUG-1~6 |
| 모든 다이얼로그 취소/닫기 버튼 | ❌ BUG-2 |
| 음성 녹음 → 저장 동작 | ❌ BUG-1 |
| 파일 업로드 → 저장 → 요약 | ✅ |
| 오류 발생 시 친절한 안내 | ✅ |
| flutter analyze error 0 | ✅ |
| flutter test 100% | ⏳ |

**판정: ❌ 품질 기준 미달 → Act 단계 실행**
