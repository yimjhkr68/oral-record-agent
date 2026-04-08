import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/ontology.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/hive_provider.dart';
import '../../api/api_client.dart';
import '../../api/ontology_api.dart';
import 'ontology_detail_panel.dart';

class OntologyListScreen extends ConsumerWidget {
  const OntologyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);

    return Scaffold(
      body: Row(
        children: [
          // ── 좌측: 버전 목록 패널 ────────────────────────────────────────
          SizedBox(
            width: 280,
            child: Column(
              children: [
                _ListHeader(),
                if (state.isLoading && state.versions.isEmpty)
                  const Expanded(
                      child: Center(child: CircularProgressIndicator()))
                else if (state.error != null && state.versions.isEmpty)
                  Expanded(child: _ErrorView(error: state.error!))
                else
                  Expanded(child: _VersionList()),
              ],
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          // ── 우측: 상세/편집 패널 ────────────────────────────────────────
          const Expanded(child: OntologyDetailPanel()),
        ],
      ),
    );
  }
}

// ── 목록 헤더 ─────────────────────────────────────────────────────────────────

class _ListHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);
    final notifier = ref.read(ontologyProvider.notifier);
    final mergeCount = state.selectedForMerge.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('온톨로지 관리',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              // 새로고침
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () => notifier.loadVersions(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 8),
          // [+ 새 버전] 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('새 버전', style: TextStyle(fontSize: 13)),
              onPressed: () => _showCreateDialog(context, ref),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // [구술기록으로 생성] 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('구술기록으로 생성',
                  style: TextStyle(fontSize: 13)),
              onPressed: () => _showInputSheet(context, ref),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          // [선택 Draft 종합] 버튼 — Draft 2개 이상 선택 시 표시
          if (mergeCount >= 2) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.merge_type, size: 16),
                label: Text('선택 Draft 종합 ($mergeCount개)',
                    style: const TextStyle(fontSize: 13)),
                onPressed: () => _showMergeDialog(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3a5a3a),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final idCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 온톨로지 버전'),
        content: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '버전 ID',
                hintText: 'v1.0',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '버전 ID를 입력하세요' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('생성'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final result = await ref
        .read(ontologyProvider.notifier)
        .createDraft(idCtrl.text.trim(), descCtrl.text.trim());
    if (result == null && context.mounted) {
      _showError(context, ref.read(ontologyProvider).error ?? '생성 실패');
    }
  }

  Future<void> _showInputSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const InputMethodBottomSheet(),
    );
  }

  Future<void> _showMergeDialog(BuildContext context, WidgetRef ref) async {
    final state = ref.read(ontologyProvider);
    final idCtrl = TextEditingController(
        text: 'merged-${DateTime.now().millisecondsSinceEpoch ~/ 1000}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('선택 Draft AI 종합'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('선택된 Draft ${state.selectedForMerge.length}개를 AI로 종합합니다.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            ...state.selectedForMerge.map((id) => Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text('• $id',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                )),
            const SizedBox(height: 16),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '새 버전 ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3a5a3a),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('종합 시작'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // 종합 진행 중 안내 SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('AI 분석 중입니다. 잠시 기다려주세요... (최대 2분)'),
        ]),
        duration: Duration(seconds: 130),
      ),
    );

    final result = await ref.read(ontologyProvider.notifier).mergeDrafts(
          state.selectedForMerge.toList(),
          idCtrl.text.trim(),
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result == null) {
      _showError(context, ref.read(ontologyProvider).error ?? '종합 실패');
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

// ── 버전 목록 ─────────────────────────────────────────────────────────────────

class _VersionList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);
    final notifier = ref.read(ontologyProvider.notifier);

    if (state.versions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('버전이 없습니다.\n[새 버전] 또는 [구술기록으로 생성]을\n눌러 시작하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.versions.length,
      itemBuilder: (_, i) {
        final v = state.versions[i];
        final isSelected =
            state.selectedVersion?.versionId == v.versionId;
        final inMerge = state.selectedForMerge.contains(v.versionId);

        return InkWell(
          onTap: () => notifier.selectVersion(v),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1)
                  : null,
              border: Border(
                left: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 3,
                ),
                bottom: BorderSide(color: Colors.grey.shade100),
              ),
            ),
            child: Row(
              children: [
                // 체크박스 (Draft만)
                if (v.status == OntologyStatus.draft)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: inMerge,
                      onChanged: (_) =>
                          notifier.toggleMergeSelect(v.versionId),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                else
                  const SizedBox(width: 24),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.versionId,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        _StatusBadge(status: v.status),
                        const SizedBox(width: 6),
                        Text(
                          v.createdAt.length >= 10
                              ? v.createdAt.substring(0, 10)
                              : v.createdAt,
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── 상태 배지 ─────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final OntologyStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OntologyStatus.draft => ('Draft', const Color(0xFFE65100)),
      OntologyStatus.confirmed => ('Confirmed', const Color(0xFF388E3C)),
      OntologyStatus.archived => ('Archived', const Color(0xFF757575)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── 오류 뷰 ───────────────────────────────────────────────────────────────────

class _ErrorView extends ConsumerWidget {
  final String error;
  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 32),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                ref.read(ontologyProvider.notifier).loadVersions(),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}

// ── InputMethodBottomSheet (구술기록으로 생성 — 텍스트 탭만 우선 구현) ────────

class InputMethodBottomSheet extends ConsumerStatefulWidget {
  const InputMethodBottomSheet({super.key});

  @override
  ConsumerState<InputMethodBottomSheet> createState() =>
      _InputMethodBottomSheetState();
}

class _InputMethodBottomSheetState
    extends ConsumerState<InputMethodBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // 텍스트 탭
  final _textCtrl = TextEditingController();
  String? _baseVersionId;

  // 파일 탭
  String? _pickedFileName;
  String? _extractedText;
  bool _extracting = false;

  // Hive 탭
  final _hiveUrlCtrl = TextEditingController();
  final _hiveQueryCtrl = TextEditingController();
  List<HiveRecord> _hiveResults = [];
  HiveRecord? _selectedRecord;
  bool _hiveConnected = false;
  bool _hiveSearching = false;

  bool _loading = false; // AI 생성 중

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _hiveUrlCtrl.text = ref.read(hiveUrlProvider);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    _hiveUrlCtrl.dispose();
    _hiveQueryCtrl.dispose();
    super.dispose();
  }

  // ── 현재 탭의 샘플 텍스트 ──────────────────────────────────────────────────
  String? get _currentSampleText {
    switch (_tabCtrl.index) {
      case 0:
        return _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim();
      case 1:
        return _extractedText;
      case 2:
        return _selectedRecord?.text;
      default:
        return null;
    }
  }

  // ── AI 생성 ──────────────────────────────────────────────────────────────────
  Future<void> _generate() async {
    final text = _currentSampleText;
    if (text == null || text.isEmpty) return;
    setState(() => _loading = true);
    final result = await ref
        .read(ontologyProvider.notifier)
        .generateFromSample(text, baseVersionId: _baseVersionId);
    setState(() => _loading = false);
    if (!mounted) return;
    if (result != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draft "${result.versionId}" 가 생성됐습니다.')),
      );
    } else {
      final err = ref.read(ontologyProvider).error ?? 'AI 생성 실패';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
    }
  }

  // ── 파일 선택 ─────────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _pickedFileName = file.name;
      _extractedText = null;
      _extracting = true;
    });

    try {
      final api = OntologyApi(ref.read(apiClientProvider));
      final res = await api.extractTextFromFile(file.path!, file.name);
      setState(() {
        _extractedText = res['text'] as String?;
        _extracting = false;
      });
    } catch (e) {
      setState(() => _extracting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('텍스트 추출 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Hive 연결 확인 ────────────────────────────────────────────────────────────
  Future<void> _checkHiveConnection() async {
    final url = _hiveUrlCtrl.text.trim();
    ref.read(hiveUrlProvider.notifier).state = url;
    await saveHiveUrl(url);
    setState(() => _hiveSearching = true);
    final ok = await HiveApi(url).checkConnection();
    setState(() {
      _hiveConnected = ok;
      _hiveSearching = false;
    });
  }

  // ── Hive 검색 ─────────────────────────────────────────────────────────────────
  Future<void> _searchHive() async {
    if (_hiveQueryCtrl.text.trim().isEmpty) return;
    setState(() => _hiveSearching = true);
    try {
      final url = _hiveUrlCtrl.text.trim();
      final records = await HiveApi(url)
          .searchRecords(_hiveQueryCtrl.text.trim(), topK: 5);
      setState(() {
        _hiveResults = records;
        _hiveSearching = false;
        _selectedRecord = null;
      });
    } catch (e) {
      setState(() => _hiveSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final versions = ref.watch(ontologyProvider).versions;
    final canGenerate = _currentSampleText != null && !_loading;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (_, __) => Column(
        children: [
          // 핸들
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('구술기록으로 온톨로지 생성',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: '텍스트 입력'),
              Tab(text: '파일 업로드'),
              Tab(text: 'Hive DB'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // ── 텍스트 입력 탭 ──────────────────────────────────────────
                _TextTab(
                  textCtrl: _textCtrl,
                  baseVersionId: _baseVersionId,
                  versions: versions,
                  onBaseChanged: (v) => setState(() => _baseVersionId = v),
                ),
                // ── 파일 업로드 탭 ──────────────────────────────────────────
                _FileTab(
                  pickedFileName: _pickedFileName,
                  extractedText: _extractedText,
                  extracting: _extracting,
                  onPickFile: _pickFile,
                ),
                // ── Hive DB 탭 ──────────────────────────────────────────────
                _HiveTab(
                  urlCtrl: _hiveUrlCtrl,
                  queryCtrl: _hiveQueryCtrl,
                  connected: _hiveConnected,
                  searching: _hiveSearching,
                  results: _hiveResults,
                  selectedRecord: _selectedRecord,
                  onCheckConnection: _checkHiveConnection,
                  onSearch: _searchHive,
                  onSelectRecord: (r) => setState(() => _selectedRecord = r),
                ),
              ],
            ),
          ),
          // ── 공통 하단: 기존 버전 기반 선택 + AI 생성 버튼 ─────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 기존 버전 기반 확장 드롭다운 (텍스트 탭에만 해당하지 않고 공통)
                if (_tabCtrl.index != 0) ...[
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '기존 버전 기반 확장 (선택)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButton<String?>(
                      value: _baseVersionId,
                      isExpanded: true,
                      underline: const SizedBox(),
                      hint: const Text('없음 (새로 생성)',
                          style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem(
                            value: null,
                            child: Text('없음 (새로 생성)',
                                style: TextStyle(fontSize: 13))),
                        ...versions.map((v) => DropdownMenuItem(
                              value: v.versionId,
                              child: Text(v.versionId,
                                  style: const TextStyle(fontSize: 13)),
                            )),
                      ],
                      onChanged: (v) => setState(() => _baseVersionId = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_loading ? 'AI 분석 중... (최대 2분)' : 'AI 초안 생성'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor:
                          Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: canGenerate ? _generate : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 텍스트 입력 탭 ────────────────────────────────────────────────────────────

class _TextTab extends StatelessWidget {
  final TextEditingController textCtrl;
  final String? baseVersionId;
  final List<OntologyVersion> versions;
  final ValueChanged<String?> onBaseChanged;

  const _TextTab({
    required this.textCtrl,
    required this.baseVersionId,
    required this.versions,
    required this.onBaseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('기존 버전 기반 확장 (선택)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          InputDecorator(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            ),
            child: DropdownButton<String?>(
              value: baseVersionId,
              isExpanded: true,
              underline: const SizedBox(),
              hint: const Text('없음 (새로 생성)',
                  style: TextStyle(fontSize: 13)),
              items: [
                const DropdownMenuItem(
                    value: null,
                    child: Text('없음 (새로 생성)',
                        style: TextStyle(fontSize: 13))),
                ...versions.map((v) => DropdownMenuItem(
                      value: v.versionId,
                      child: Text(v.versionId,
                          style: const TextStyle(fontSize: 13)),
                    )),
              ],
              onChanged: onBaseChanged,
            ),
          ),
          const SizedBox(height: 12),
          const Text('구술 자료 텍스트',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Expanded(
            child: TextField(
              controller: textCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '구술 자료 텍스트를 붙여넣으세요...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 파일 업로드 탭 ────────────────────────────────────────────────────────────

class _FileTab extends StatelessWidget {
  final String? pickedFileName;
  final String? extractedText;
  final bool extracting;
  final VoidCallback onPickFile;

  const _FileTab({
    required this.pickedFileName,
    required this.extractedText,
    required this.extracting,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('파일 선택 (txt / pdf / docx)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('파일 선택'),
              onPressed: extracting ? null : onPickFile,
            ),
            if (pickedFileName != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(pickedFileName!,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          if (extracting)
            const Row(children: [
              SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('텍스트 추출 중...', style: TextStyle(fontSize: 13)),
            ])
          else if (extractedText != null) ...[
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text('추출 완료 — ${extractedText!.length}자',
                  style: const TextStyle(
                      fontSize: 13, color: Colors.green)),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    extractedText!.length > 2000
                        ? '${extractedText!.substring(0, 2000)}…'
                        : extractedText!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('파일을 선택하면 텍스트를 자동 추출합니다.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Hive DB 탭 ────────────────────────────────────────────────────────────────

class _HiveTab extends StatelessWidget {
  final TextEditingController urlCtrl;
  final TextEditingController queryCtrl;
  final bool connected;
  final bool searching;
  final List<HiveRecord> results;
  final HiveRecord? selectedRecord;
  final VoidCallback onCheckConnection;
  final VoidCallback onSearch;
  final ValueChanged<HiveRecord> onSelectRecord;

  const _HiveTab({
    required this.urlCtrl,
    required this.queryCtrl,
    required this.connected,
    required this.searching,
    required this.results,
    required this.selectedRecord,
    required this.onCheckConnection,
    required this.onSearch,
    required this.onSelectRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 서버 URL + 연결 확인
          const Text('v3.0 Hive 서버 주소',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.0.x:8000',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: searching ? null : onCheckConnection,
              child: const Text('연결 확인'),
            ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(
              searching
                  ? Icons.sync
                  : connected
                      ? Icons.check_circle
                      : Icons.error_outline,
              size: 14,
              color: connected ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              searching
                  ? '확인 중...'
                  : connected
                      ? '연결됨'
                      : '미연결 — 서버 주소를 확인하세요',
              style: TextStyle(
                  fontSize: 12,
                  color: connected ? Colors.green : Colors.grey),
            ),
          ]),
          const SizedBox(height: 12),

          // 검색
          const Text('레코드 검색',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: queryCtrl,
                decoration: const InputDecoration(
                  hintText: '예) 제주 4.3 경험',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: (searching || !connected) ? null : onSearch,
              child: const Text('검색'),
            ),
          ]),
          const SizedBox(height: 10),

          // 결과 목록
          if (searching)
            const Center(child: CircularProgressIndicator())
          else if (results.isEmpty)
            const Center(
              child: Text('검색 결과가 여기에 표시됩니다.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final r = results[i];
                  final isSelected = selectedRecord?.displayId == r.displayId;
                  return InkWell(
                    onTap: () => onSelectRecord(r),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.07)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  size: 14, color: Colors.green),
                            if (isSelected) const SizedBox(width: 4),
                            Text(r.displayId,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(width: 8),
                            Text(r.narratorName,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                            const Spacer(),
                            Text(
                                '관련도 ${(r.score * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                            r.text.length > 120
                                ? '${r.text.substring(0, 120)}…'
                                : r.text,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
