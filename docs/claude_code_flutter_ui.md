# v4.0 Flutter UI 전환 — Claude Code 프롬프트

## 전체 구조 (확정)

```
Oral-record-agent_v4.0/
├── [기존 FastAPI 백엔드] ← 수정 없이 유지
│   ├── ontology/
│   ├── graph/
│   ├── pipeline/
│   ├── api/
│   ├── main.py
│   └── data/
│
└── flutter/              ← [신규] Flutter 앱 루트
    ├── lib/
    │   ├── main.dart
    │   ├── api/          ← FastAPI 클라이언트
    │   ├── models/       ← 데이터 모델
    │   ├── providers/    ← 상태관리 (Riverpod)
    │   ├── screens/      ← 화면
    │   └── widgets/      ← 공통 위젯
    ├── pubspec.yaml
    └── ...

플랫폼별 연결 방식:
  Windows 데스크탑: localhost:9000 (FastAPI 로컬 실행)
  Android / iOS:    설정 화면에서 서버 IP:포트 입력
                    (FastAPI 가 실행된 PC의 IP 주소)
```

---

## Step 0 — 현재 환경 확인

작업 시작 전 다음을 확인하고 보고해:

```bash
flutter --version
flutter doctor
dart --version
```

확인 항목:
- Flutter SDK 버전
- Windows 데스크탑 빌드 가능 여부
- Android 빌드 가능 여부 (Android Studio / SDK)
- iOS 빌드 가능 여부 (macOS 전용 — 없으면 skip)

---

## Step 1 — Flutter 프로젝트 생성

```bash
# 프로젝트 루트(Oral-record-agent_v4.0/)에서 실행
flutter create flutter \
  --org kr.ac.oralrecord \
  --project-name oral_record_agent \
  --platforms windows,android,ios \
  --description "구술기록 지식그래프 에이전트 v4.0"

cd flutter
```

---

## Step 2 — pubspec.yaml 의존성 설정

`flutter/pubspec.yaml` 을 아래 내용으로 교체:

```yaml
name: oral_record_agent
description: 구술기록 지식그래프 에이전트 v4.0
version: 4.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.10.0'

dependencies:
  flutter:
    sdk: flutter

  # HTTP 클라이언트
  dio: ^5.4.0

  # 상태 관리
  flutter_riverpod: ^2.4.0

  # 라우팅
  go_router: ^12.0.0

  # 그래프 시각화
  graphview: ^1.2.0

  # 로컬 설정 저장 (서버 IP 등)
  shared_preferences: ^2.2.0

  # 아이콘
  flutter_svg: ^2.0.0

  # 색상 유틸
  flex_color_scheme: ^7.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

```bash
flutter pub get
```

---

## Step 3 — 디렉토리 구조 생성

`flutter/lib/` 아래에 다음 구조를 만들어:

```
lib/
├── main.dart
├── app.dart                    ← MaterialApp + GoRouter 설정
│
├── api/
│   ├── api_client.dart         ← Dio 기반 HTTP 클라이언트
│   ├── ontology_api.dart       ← 온톨로지 API 호출
│   ├── triple_api.dart         ← 트리플 API 호출
│   └── graph_api.dart          ← 그래프/검색 API 호출
│
├── models/
│   ├── ontology.dart           ← OntologyVersion, OntologyClass, OntologyPredicate
│   └── triple.dart             ← Triple, GraphData
│
├── providers/
│   ├── server_provider.dart    ← 서버 URL + 연결 상태
│   ├── ontology_provider.dart  ← 온톨로지 상태
│   └── triple_provider.dart    ← 트리플/그래프 상태
│
├── screens/
│   ├── settings/
│   │   └── settings_screen.dart     ← 서버 IP + API 키 설정
│   ├── ontology/
│   │   ├── ontology_list_screen.dart    ← 온톨로지 버전 목록
│   │   └── ontology_detail_screen.dart  ← 클래스/속성 편집
│   ├── triple/
│   │   ├── triple_list_screen.dart      ← 트리플 목록/검색
│   │   └── triple_extract_screen.dart   ← 구술자료 → 트리플 추출
│   └── graph/
│       └── knowledge_graph_screen.dart  ← 전체 그래프 시각화
│
└── widgets/
    ├── status_badge.dart       ← Draft/Confirmed/Archived 배지
    ├── server_status.dart      ← 서버 연결 상태 표시
    └── graph_painter.dart      ← CustomPainter 기반 그래프
```

---

## Step 4 — 핵심 파일 작성

### lib/main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(
    const ProviderScope(
      child: OralRecordApp(),
    ),
  );
}
```

### lib/api/api_client.dart

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String defaultServerUrl = 'http://127.0.0.1:9000';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late Dio _dio;
  String _baseUrl = defaultServerUrl;

  ApiClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? defaultServerUrl;
    _dio.options.baseUrl = _baseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);
  }

  String get baseUrl => _baseUrl;

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path) => _dio.delete(path);

  Future<bool> checkConnection() async {
    try {
      await _dio.get('/api/ontologies/');
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

### lib/models/ontology.dart

```dart
enum OntologyStatus { draft, confirmed, archived }

class OntologyClass {
  final String name;
  final String labelKo;
  final String color;
  final String description;
  final List<String> examples;

  const OntologyClass({
    required this.name,
    required this.labelKo,
    required this.color,
    this.description = '',
    this.examples = const [],
  });

  factory OntologyClass.fromJson(Map<String, dynamic> json) => OntologyClass(
    name: json['name'] ?? '',
    labelKo: json['label_ko'] ?? '',
    color: json['color'] ?? '#888888',
    description: json['description'] ?? '',
    examples: List<String>.from(json['examples'] ?? []),
  );
}

class OntologyPredicate {
  final String name;
  final List<String> domain;
  final List<String> range;
  final String description;

  const OntologyPredicate({
    required this.name,
    this.domain = const [],
    this.range = const [],
    this.description = '',
  });

  factory OntologyPredicate.fromJson(Map<String, dynamic> json) =>
      OntologyPredicate(
        name: json['name'] ?? '',
        domain: List<String>.from(json['domain'] ?? []),
        range: List<String>.from(json['range_'] ?? []),
        description: json['description'] ?? '',
      );
}

class OntologyVersion {
  final String versionId;
  final OntologyStatus status;
  final List<OntologyClass> classes;
  final List<OntologyPredicate> predicates;
  final String createdAt;
  final String? confirmedAt;
  final String description;

  const OntologyVersion({
    required this.versionId,
    required this.status,
    required this.classes,
    required this.predicates,
    required this.createdAt,
    this.confirmedAt,
    this.description = '',
  });

  factory OntologyVersion.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] ?? 'draft';
    final status = OntologyStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => OntologyStatus.draft,
    );
    return OntologyVersion(
      versionId: json['version_id'] ?? '',
      status: status,
      classes: (json['classes'] as List? ?? [])
          .map((c) => OntologyClass.fromJson(c))
          .toList(),
      predicates: (json['predicates'] as List? ?? [])
          .map((p) => OntologyPredicate.fromJson(p))
          .toList(),
      createdAt: json['created_at'] ?? '',
      confirmedAt: json['confirmed_at'],
      description: json['description'] ?? '',
    );
  }
}
```

### lib/models/triple.dart

```dart
enum TripleStatus { active, archived }

class Triple {
  final String id;
  final String subject;
  final String subjectType;
  final String predicate;
  final String object;
  final String objectType;
  final String ontologyVersion;
  final double confidence;
  final TripleStatus status;
  final String createdAt;
  final String note;

  const Triple({
    required this.id,
    required this.subject,
    required this.subjectType,
    required this.predicate,
    required this.object,
    required this.objectType,
    required this.ontologyVersion,
    this.confidence = 1.0,
    this.status = TripleStatus.active,
    required this.createdAt,
    this.note = '',
  });

  factory Triple.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] ?? 'active';
    return Triple(
      id: json['id'] ?? '',
      subject: json['subject'] ?? '',
      subjectType: json['subject_type'] ?? '',
      predicate: json['predicate'] ?? '',
      object: json['object'] ?? '',
      objectType: json['object_type'] ?? '',
      ontologyVersion: json['ontology_version'] ?? '',
      confidence: (json['confidence'] ?? 1.0).toDouble(),
      status: statusStr == 'archived' ? TripleStatus.archived : TripleStatus.active,
      createdAt: json['created_at'] ?? '',
      note: json['note'] ?? '',
    );
  }
}

class GraphNode {
  final String id;
  final String type;
  final int degree;

  const GraphNode({
    required this.id,
    required this.type,
    required this.degree,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) => GraphNode(
    id: json['id'] ?? '',
    type: json['type'] ?? '',
    degree: json['degree'] ?? 0,
  );
}

class GraphData {
  final List<GraphNode> nodes;
  final List<Triple> triples;

  const GraphData({required this.nodes, required this.triples});

  factory GraphData.fromJson(Map<String, dynamic> json) => GraphData(
    nodes: (json['nodes'] as List? ?? [])
        .map((n) => GraphNode.fromJson(n))
        .toList(),
    triples: (json['triples'] as List? ?? [])
        .map((t) => Triple.fromJson(t))
        .toList(),
  );
}
```

### lib/app.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/ontology/ontology_list_screen.dart';
import 'screens/ontology/ontology_detail_screen.dart';
import 'screens/triple/triple_list_screen.dart';
import 'screens/triple/triple_extract_screen.dart';
import 'screens/graph/knowledge_graph_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/ontology',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/ontology',
              builder: (c, s) => const OntologyListScreen()),
          GoRoute(path: '/ontology/:versionId',
              builder: (c, s) =>
                  OntologyDetailScreen(versionId: s.pathParameters['versionId']!)),
          GoRoute(path: '/triple',
              builder: (c, s) => const TripleListScreen()),
          GoRoute(path: '/triple/extract',
              builder: (c, s) => const TripleExtractScreen()),
          GoRoute(path: '/graph',
              builder: (c, s) => const KnowledgeGraphScreen()),
          GoRoute(path: '/settings',
              builder: (c, s) => const SettingsScreen()),
        ],
      ),
    ],
  );
});

class OralRecordApp extends ConsumerWidget {
  const OralRecordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: '구술기록 지식그래프 v4.0',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A5F),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansKR',
      ),
      routerConfig: router,
    );
  }
}

class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: Row(
        children: [
          // 사이드 네비게이션 (데스크탑)
          NavigationRail(
            selectedIndex: _selectedIndex(location),
            onDestinationSelected: (i) => _navigate(context, i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('구술기록\n지식그래프',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.account_tree_outlined),
                  selectedIcon: Icon(Icons.account_tree),
                  label: Text('온톨로지')),
              NavigationRailDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: Text('트리플')),
              NavigationRailDestination(
                  icon: Icon(Icons.hub_outlined),
                  selectedIcon: Icon(Icons.hub),
                  label: Text('지식그래프')),
              NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('설정')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/ontology')) return 0;
    if (location.startsWith('/triple')) return 1;
    if (location.startsWith('/graph')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/ontology'); break;
      case 1: context.go('/triple'); break;
      case 2: context.go('/graph'); break;
      case 3: context.go('/settings'); break;
    }
  }
}
```

### lib/screens/settings/settings_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../providers/server_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _isConnected = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final client = ref.read(apiClientProvider);
    _urlController.text = client.baseUrl;
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _checking = true);
    final client = ref.read(apiClientProvider);
    final ok = await client.checkConnection();
    setState(() { _isConnected = ok; _checking = false; });
  }

  Future<void> _save() async {
    final client = ref.read(apiClientProvider);
    await client.setBaseUrl(_urlController.text.trim());
    await _checkConnection();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장됐습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('서버 설정')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 연결 상태
            Row(children: [
              Icon(_checking
                  ? Icons.sync
                  : _isConnected ? Icons.check_circle : Icons.error,
                color: _isConnected ? Colors.green : Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(_checking ? '연결 확인 중...'
                  : _isConnected ? 'FastAPI 서버 연결됨'
                  : '서버에 연결할 수 없음'),
              const SizedBox(width: 16),
              TextButton(onPressed: _checkConnection,
                  child: const Text('재연결')),
            ]),
            const SizedBox(height: 24),

            // 서버 URL
            const Text('FastAPI 서버 주소',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Windows: http://127.0.0.1:9000\n'
                'Android/iOS: http://PC의IP주소:9000',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'http://127.0.0.1:9000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // API 키
            const Text('Anthropic API 키',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'sk-ant-...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('* API 키는 이 기기에만 저장되며 서버로 전송됩니다.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              child: const Text('저장 및 연결 확인'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Step 5 — 나머지 화면 뼈대 생성

다음 파일들을 뼈대(scaffold)로 생성해줘.
이후 각 화면을 순서대로 완성할 예정이므로 지금은 구조만:

```dart
// 각 파일: AppBar + 중앙에 "화면명 준비 중" Text 표시
// 예시:
class OntologyListScreen extends ConsumerWidget {
  const OntologyListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('온톨로지 관리')),
      body: const Center(child: Text('온톨로지 목록')),
    );
  }
}
```

생성할 파일:
- screens/ontology/ontology_list_screen.dart
- screens/ontology/ontology_detail_screen.dart  (versionId 파라미터 포함)
- screens/triple/triple_list_screen.dart
- screens/triple/triple_extract_screen.dart
- screens/graph/knowledge_graph_screen.dart

---

## Step 6 — 빌드 및 실행 테스트

```bash
cd flutter

# Windows 데스크탑 실행
flutter run -d windows

# 빌드 가능 여부 확인
flutter build windows --release
```

확인 항목:
```
□ 앱 윈도우가 열리는가
□ 사이드 네비게이션 4개 탭 표시
□ 설정 화면에서 서버 URL 입력 가능
□ FastAPI 서버(python -m uvicorn main:app --port 9000) 실행 후
  설정 화면 "연결 확인" → 녹색 연결됨 표시
□ 각 탭 전환 시 화면 전환 동작
```

---

## Step 7 — .gitignore 및 Git 커밋

`flutter/` 아래 Flutter 기본 .gitignore 확인 후:

```bash
cd ..  # 프로젝트 루트로
git add flutter/
git commit -m "feat(flutter): Flutter UI 프로젝트 초기 구조 생성

- 타겟: Windows 데스크탑 + Android + iOS
- FastAPI 백엔드 연동 구조 (ApiClient, Dio)
- 데이터 모델: OntologyVersion, Triple, GraphData
- 상태관리: Riverpod
- 라우팅: GoRouter + NavigationRail
- 설정 화면: 서버 URL + API 키 + 연결 확인
- 각 화면 뼈대 생성 (온톨로지/트리플/그래프)"
```

---

## 완료 기준 및 다음 단계

```
Step 6 완료 후 보고 내용:
  □ flutter run -d windows 성공 여부
  □ 설정 화면 → FastAPI 연결 확인 결과
  □ 발생한 오류 목록

Step 6 통과 후 다음 순서:
  Phase A: 온톨로지 관리 화면 완성 (list + detail)
  Phase B: 트리플 관리 화면 완성
  Phase C: 지식그래프 화면 완성 (CustomPainter D3 대체)
  Phase D: Android 빌드 및 테스트
```

---

## 제약 조건

```
- 기존 FastAPI 백엔드 파일 수정 금지
- 기존 ui/*.jsx, index.html 은 그대로 유지
  (Flutter 전환 완료 후 별도 판단)
- flutter/ 는 반드시 프로젝트 루트 바로 아래에 생성
- Step 6 Windows 실행 확인 후 나에게 보고,
  내가 승인하면 Phase A 시작
```
