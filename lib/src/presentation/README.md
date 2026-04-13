// 파일 목적: pubspec.yaml 의존성 추천사항
// Phase 3 UI/라우팅 구현에 필요한 패키지

// pubspec.yaml에 다음 의존성 추가 권장:
// 
// dependencies:
//   flutter:
//     sdk: flutter
//   riverpod: ^2.4.0              # 상태 관리
//   flutter_riverpod: ^2.4.0      # Flutter 통합
//   go_router: ^13.0.0            # 라우팅 (고급)
//   # 또는 (단순 라우팅)
//   # flutter_navigator: ^1.0.0
//
//   # 음성 녹음
//   record: ^5.0.0                # 음성 녹음
//   audio_session: ^0.1.16        # 음성 세션
//
//   # 파일 선택
//   file_picker: ^6.0.0           # 파일 선택
//
//   # 저장소 접근
//   hive: ^2.2.3
//   hive_flutter: ^1.1.0
//
// dev_dependencies:
//   flutter_test:
//     sdk: flutter
//   riverpod_generator: ^2.3.0
//   build_runner: ^2.4.0

/// Riverpod Provider 의존성 관계:
/// 
/// main
///   ├─ recordRepositoryProvider
///   │   ├─ recordListProvider (family with SearchFilters)
///   │   ├─ recordDetailProvider (family with recordId)
///   │   └─ recentRecordsProvider
///   │
///   ├─ narratorRepositoryProvider
///   │   └─ narratorListProvider
///   │
///   ├─ metadataFormProvider (StateNotifier)
///   │   └─ metadataFormValidProvider (derived)
///   │
///   ├─ searchFilterProvider (StateNotifier)
///   │
///   ├─ settingsProvider (StateNotifier)
///   │
///   └─ interviewerRepositoryProvider
///       └─ interviewerListProvider

/// 라우팅 구조:
/// 
/// "/" (HomePage)
///   ├─ /recording (RecordingPage)
///   ├─ /file-picker (FilePickerPage)
///   ├─ /text-input (TextInputPage)
///   ├─ /metadata-input (MetadataInputPage)
///   ├─ /records (RecordListPage)
///   │   ├─ /search-filter (SearchFilterPage)
///   │   └─ /detail/:recordId (RecordDetailPage)
///   └─ /settings (SettingsPage)

/// 다음 단계 구현 체크리스트:
/// 
/// [ ] main.dart에서 HiveService 초기화
/// [ ] Repository 구현 (RecordRepository, NarratorRepository 등)
/// [ ] 각 Provider에서 실제 데이터 소스 연결
/// [ ] 음성 녹음 기능 구현 (record 패키지)
/// [ ] 파일 선택 기능 구현 (file_picker 패키지)
/// [ ] 각 메뉴 액션 구현 (저장, 삭제, 내보내기 등)
/// [ ] Tool 통합 (detectPII, maskPII, summarizeRecord 등)
/// [ ] 테스트 코드 작성
