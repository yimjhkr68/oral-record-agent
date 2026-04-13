import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/ontology.dart';
import '../../providers/ontology_provider.dart';
import '../../api/api_client.dart';
import '../../api/ontology_api.dart';
import '../../api/record_api.dart';
import '../../models/oral_record.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/empty_state.dart';
import 'ontology_detail_panel.dart';

// ── [작업 중] 탭 — Draft 버전 목록 + 상세 패널 ──────────────────────────────────

class OntologyWorkingTab extends ConsumerWidget {
  const OntologyWorkingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);

    return Row(
      children: [
        // ── 좌측: Draft 버전 목록 ────────────────────────────────────────
        SizedBox(
          width: 280,
          child: Column(
            children: [
              _WorkingListHeader(),
              if (state.isLoading && state.versions.isEmpty)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (state.error != null && state.versions.isEmpty)
                Expanded(child: _ErrorView(error: state.error!))
              else
                const Expanded(child: _WorkingVersionList()),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        // ── 우측: 상세/편집 패널 ────────────────────────────────────────
        const Expanded(child: OntologyDetailPanel()),
      ],
    );
  }
}

// ── 목록 헤더 ─────────────────────────────────────────────────────────────────

class _WorkingListHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);
    final notifier = ref.read(ontologyProvider.notifier);
    // Draft 중 선택된 것만 카운트
    final drafts = state.versions
        .where((v) => v.status == OntologyStatus.draft)
        .map((v) => v.versionId)
        .toSet();
    final mergeCount =
        state.selectedForMerge.where((id) => drafts.contains(id)).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('작업 중 Draft', style: AppTypography.heading2),
              const Spacer(),
              // 임포트 버튼
              PopupMenuButton<String>(
                icon: const Icon(Icons.upload_file_outlined,
                    size: 18, color: AppColors.textMuted),
                tooltip: '임포트 / 템플릿',
                onSelected: (v) {
                  if (v.startsWith('import_')) {
                    _showImportDialog(
                        context, ref, v.replaceFirst('import_', ''));
                  } else if (v.startsWith('template_')) {
                    _downloadTemplate(
                        context, ref, v.replaceFirst('template_', ''));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'import_json',
                    child: Row(children: [
                      Icon(Icons.data_object, size: 16),
                      SizedBox(width: 8),
                      Text('JSON 임포트'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'import_csv_classes',
                    child: Row(children: [
                      Icon(Icons.table_chart_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('CSV 임포트 (클래스)'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'import_csv_predicates',
                    child: Row(children: [
                      Icon(Icons.table_chart_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('CSV 임포트 (속성)'),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'template_json',
                    child: Row(children: [
                      Icon(Icons.download_outlined,
                          size: 16,
                          color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('JSON 템플릿 다운로드',
                          style:
                              TextStyle(color: AppColors.secondary)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'template_csv_classes',
                    child: Row(children: [
                      Icon(Icons.download_outlined,
                          size: 16,
                          color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('CSV 클래스 템플릿',
                          style:
                              TextStyle(color: AppColors.secondary)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'template_csv_predicates',
                    child: Row(children: [
                      Icon(Icons.download_outlined,
                          size: 16,
                          color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('CSV 속성 템플릿',
                          style:
                              TextStyle(color: AppColors.secondary)),
                    ]),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18,
                    color: AppColors.textMuted),
                onPressed: () => notifier.loadVersions(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '새로고침',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('새 버전', style: TextStyle(fontSize: 13)),
              onPressed: () => _showCreateDialog(context, ref),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('구술기록으로 생성',
                  style: TextStyle(fontSize: 13)),
              onPressed: () => _showInputSheet(context, ref),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8)),
            ),
          ),
          // ── 선택 시 액션 바 ─────────────────────────────────────────
          if (mergeCount >= 1) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryFaint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text('$mergeCount개 선택됨',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 18),
                    tooltip: '내보내기',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => ExportService.exportOntologies(
                      apiClient: ref.read(apiClientProvider),
                      versionIds: state.selectedForMerge.toList(),
                      context: context,
                    ),
                  ),
                  if (mergeCount >= 2) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.merge_type, size: 18),
                      tooltip: '종합',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showMergeDialog(context, ref),
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    tooltip: '선택 해제',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () =>
                        ref.read(ontologyProvider.notifier).clearMergeSelect(),
                  ),
                ],
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
    final descCtrl = TextEditingController();

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
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                )),
            const SizedBox(height: 16),
            TextField(
              controller: idCtrl,
              decoration: const InputDecoration(
                labelText: '새 버전 ID',
                hintText: '예: v2.0, oral-history-v2',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(
                labelText: '설명 (선택)',
                hintText: '예: 제주 4·3 구술 샘플 3개 종합',
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('AI 분석 중입니다. 잠시 기다려주세요... (최대 2분)'),
        ]),
        duration: Duration(seconds: 130),
      ),
    );

    final result = await ref.read(ontologyProvider.notifier).mergeDrafts(
          state.selectedForMerge.toList(),
          idCtrl.text.trim(),
          descCtrl.text.trim(),
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result == null) {
      _showError(context, ref.read(ontologyProvider).error ?? '종합 실패');
    }
  }

  Future<void> _showImportDialog(
      BuildContext context, WidgetRef ref, String type) async {
    // 1. 파일 선택
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'json' ? ['json'] : ['csv'],
      withData: true, // 웹/데스크톱에서 bytes 직접 획득
    );
    if (result == null || !context.mounted) return;

    final pf = result.files.first;
    final bytes = pf.bytes;
    if (bytes == null) {
      _showError(context, '파일을 읽을 수 없습니다.');
      return;
    }

    // 2. 버전 ID 입력 다이얼로그
    final versionIdCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'json' ? 'JSON 임포트' : 'CSV 임포트'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('파일: ${pf.name}',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: versionIdCtrl,
            decoration: const InputDecoration(
              labelText: '새 버전 ID (비워두면 자동 생성)',
              hintText: '예: v2.0-imported',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('임포트')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // 3. API 호출 (multipart/form-data)
    try {
      final csvType = type == 'csv_classes' ? 'classes' : 'predicates';
      final formData = FormData.fromMap({
        'file':        MultipartFile.fromBytes(bytes, filename: pf.name),
        'version_id':  versionIdCtrl.text.trim(),
        'import_mode': 'new',
        'csv_type':    csvType,
      });

      final res = await ref
          .read(apiClientProvider)
          .postFormData('/api/ontologies/import', formData);

      if (!context.mounted) return;
      final vid = res.data['version_id'] ?? '';
      final cls = res.data['classes_count'] ?? 0;
      final prd = res.data['predicates_count'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('임포트 완료 — $vid (클래스 $cls개, 속성 $prd개)'),
          backgroundColor: Colors.green,
        ),
      );
      ref.read(ontologyProvider.notifier).loadVersions();
    } catch (e) {
      if (context.mounted) _showError(context, '임포트 실패: $e');
    }
  }

  Future<void> _downloadTemplate(
      BuildContext context, WidgetRef ref, String templateType) async {
    const filenames = {
      'json':           'ontology_template.json',
      'csv_classes':    'ontology_classes_template.csv',
      'csv_predicates': 'ontology_predicates_template.csv',
    };

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: '템플릿 저장',
      fileName: filenames[templateType] ?? 'template',
    );
    if (savePath == null || !context.mounted) return;

    try {
      final res = await ref.read(apiClientProvider).get(
        '/api/ontologies/templates/$templateType',
        options: Options(responseType: ResponseType.bytes),
      );
      await File(savePath).writeAsBytes(res.data as List<int>);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('템플릿 저장됨: $savePath')),
      );
    } catch (e) {
      if (context.mounted) _showError(context, '다운로드 실패: $e');
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

// ── Draft 버전 목록 ───────────────────────────────────────────────────────────

class _WorkingVersionList extends ConsumerWidget {
  const _WorkingVersionList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ontologyProvider);
    final notifier = ref.read(ontologyProvider.notifier);

    final drafts = state.versions
        .where((v) => v.status == OntologyStatus.draft)
        .toList();

    if (drafts.isEmpty) {
      return EmptyState(
        icon: Icons.note_add_outlined,
        title: '작업 중인 Draft 없음',
        description: '[새 버전] 또는\n[구술기록으로 생성]을 눌러 시작하세요.',
      );
    }

    return ListView.builder(
      itemCount: drafts.length,
      itemBuilder: (_, i) {
        final v = drafts[i];
        final isSelected = state.selectedVersion?.versionId == v.versionId;
        final inMerge = state.selectedForMerge.contains(v.versionId);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: AppCard(
            selected: isSelected,
            onTap: () => notifier.selectVersion(v),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
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
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.versionId,
                          style: AppTypography.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        OntologyStatusBadge(status: v.status),
                        const SizedBox(width: 6),
                        Text(
                          v.createdAt.length >= 10
                              ? v.createdAt.substring(0, 10)
                              : v.createdAt,
                          style: AppTypography.caption,
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

// ── 공통 위젯 — 상태 배지 ─────────────────────────────────────────────────────

class OntologyStatusBadge extends StatelessWidget {
  final OntologyStatus status;
  const OntologyStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      OntologyStatus.draft     => ('Draft',     AppColors.draft),
      OntologyStatus.confirmed => ('Confirmed', AppColors.confirmed),
      OntologyStatus.archived  => ('Archived',  AppColors.archived),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: AppTypography.badge.copyWith(color: color)),
    );
  }
}

// ── 공통 위젯 — 오류 뷰 ──────────────────────────────────────────────────────

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

// ── 구술기록으로 생성 BottomSheet ─────────────────────────────────────────────

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

  final _textCtrl = TextEditingController();
  String? _baseVersionId;

  String? _pickedFileName;
  String? _extractedText;
  bool _extracting = false;

  List<OralRecord> _storedRecords = [];
  OralRecord? _selectedRecord;
  bool _recordsLoading = false;

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      setState(() {});
      if (_tabCtrl.index == 2 && _storedRecords.isEmpty) {
        _loadStoredRecords('');
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  String? get _currentSampleText {
    switch (_tabCtrl.index) {
      case 0:
        return _textCtrl.text.trim().isEmpty ? null : _textCtrl.text.trim();
      case 1:
        return _extractedText;
      case 2:
        return _selectedRecord?.content ?? _selectedRecord?.contentPreview;
      default:
        return null;
    }
  }

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
          SnackBar(
              content: Text('텍스트 추출 실패: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadStoredRecords(String q) async {
    setState(() => _recordsLoading = true);
    try {
      final records =
          await RecordApi(ref.read(apiClientProvider)).list(q: q, limit: 100);
      setState(() {
        _storedRecords = records;
        _recordsLoading = false;
      });
    } catch (e) {
      setState(() => _recordsLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('기록 로드 실패: $e'),
              backgroundColor: Colors.red),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 40,
              height: 4,
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
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              Tab(text: '저장된 기록'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _TextTab(
                  textCtrl: _textCtrl,
                  baseVersionId: _baseVersionId,
                  versions: versions,
                  onBaseChanged: (v) => setState(() => _baseVersionId = v),
                ),
                _FileTab(
                  pickedFileName: _pickedFileName,
                  extractedText: _extractedText,
                  extracting: _extracting,
                  onPickFile: _pickFile,
                ),
                _StoredRecordsTab(
                  records: _storedRecords,
                  loading: _recordsLoading,
                  selectedRecord: _selectedRecord,
                  onRefresh: () => _loadStoredRecords(''),
                  onSearch: _loadStoredRecords,
                  onSelectRecord: (r) => setState(() => _selectedRecord = r),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                        _loading ? 'AI 분석 중... (최대 2분)' : 'AI 초안 생성'),
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
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('텍스트 추출 중...', style: TextStyle(fontSize: 13)),
            ])
          else if (extractedText != null) ...[
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 6),
              Text('추출 완료 — ${extractedText!.length}자',
                  style: const TextStyle(fontSize: 13, color: Colors.green)),
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
                        style:
                            TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 저장된 기록 탭 ────────────────────────────────────────────────────────────

class _StoredRecordsTab extends StatefulWidget {
  final List<OralRecord> records;
  final bool loading;
  final OralRecord? selectedRecord;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearch;
  final ValueChanged<OralRecord> onSelectRecord;

  const _StoredRecordsTab({
    required this.records,
    required this.loading,
    required this.selectedRecord,
    required this.onRefresh,
    required this.onSearch,
    required this.onSelectRecord,
  });

  @override
  State<_StoredRecordsTab> createState() => _StoredRecordsTabState();
}

class _StoredRecordsTabState extends State<_StoredRecordsTab> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: '제목 또는 내용 검색',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 14),
                          onPressed: () {
                            _searchCtrl.clear();
                            widget.onSearch('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: widget.onSearch,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '새로고침',
              onPressed: widget.onRefresh,
            ),
          ]),
          const SizedBox(height: 8),
          if (widget.selectedRecord != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '선택됨: ${widget.selectedRecord!.title}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ],
          if (widget.loading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else if (widget.records.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.library_books_outlined,
                        size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('저장된 구술기록이 없습니다.',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('"기록" 탭에서 먼저 기록을 등록해 주세요.',
                        style:
                            TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: widget.records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final r = widget.records[i];
                  final isSelected = widget.selectedRecord?.id == r.id;
                  return InkWell(
                    onTap: () => widget.onSelectRecord(r),
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
                      child: Row(children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle
                              : r.isFile
                                  ? Icons.description_outlined
                                  : Icons.text_snippet_outlined,
                          size: 16,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis),
                              if (r.contentPreview != null)
                                Text(r.contentPreview!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Text(r.dateLabel,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ]),
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
