// 파일 목적: SettingsPage - 설정 화면 (사이드바 레이아웃)

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/settings_provider.dart';
import '../../data/models/record.dart';
import '../../data/models/search_filters.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/services/local_transcription_service.dart';
import '../../data/services/document_extraction_service.dart';
import '../../data/services/video_transcription_service.dart';
import '../../data/services/import_export_service.dart';
import '../../data/utils/record_processing_util.dart';
import '../../data/models/account.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import 'account_management_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late TextEditingController _apiKeyController;
  late TextEditingController _openAiApiKeyController;
  late TextEditingController _pythonPathController;
  bool _apiKeyObscured = true;
  bool _openAiKeyObscured = true;
  bool _whisperTesting = false;
  String? _whisperTestResult;
  List<FileSystemEntity> _cachedModels = [];
  bool _cacheLoaded = false;
  int _selectedSection = 0;

  // 배치 처리 상태
  bool _batchRunning = false;
  int _batchDone = 0;
  int _batchTotal = 0;
  int? _unprocessedCount;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _openAiApiKeyController = TextEditingController(text: settings.openAiApiKey);
    _pythonPathController = TextEditingController(text: settings.pythonPath);
    _loadUnprocessedCount();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _openAiApiKeyController.dispose();
    _pythonPathController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedModels() async {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    final cacheDir = Directory('$home\\.cache\\whisper');
    if (!cacheDir.existsSync()) {
      if (mounted) setState(() { _cachedModels = []; _cacheLoaded = true; });
      return;
    }
    final files = cacheDir.listSync().where((f) => f is File && f.path.endsWith('.pt')).toList();
    if (mounted) setState(() { _cachedModels = files; _cacheLoaded = true; });
  }

  Future<void> _deleteCachedModel(FileSystemEntity file) async {
    final name = file.path.split(Platform.pathSeparator).last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모델 삭제'),
        content: Text('$name 을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        file.deleteSync();
        await _loadCachedModels();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name 삭제 완료')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
        }
      }
    }
  }

  Future<void> _loadUnprocessedCount() async {
    final repository = await ref.read(recordRepositoryProvider.future);
    final all = await repository.searchRecords(SearchFilters());
    final count = all.where(RecordProcessingUtil.needsProcessing).length;
    if (mounted) setState(() => _unprocessedCount = count);
  }

  Future<void> _showBatchExtractionSheet() async {
    final repository = await ref.read(recordRepositoryProvider.future);
    final all = await repository.searchRecords(SearchFilters());
    final targets = all.where(RecordProcessingUtil.needsProcessing).toList();
    if (!mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('미처리 기록이 없습니다.')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _BatchProcessingSheet(
        targets: targets,
        settings: ref.read(settingsProvider),
        fileStorage: ref.read(fileStorageProvider),
        repository: repository,
        onStart: () => setState(() {
          _batchRunning = true;
          _batchDone = 0;
          _batchTotal = targets.length;
        }),
        onProgress: (done) => setState(() => _batchDone = done),
        onDone: () {
          setState(() => _batchRunning = false);
          _loadUnprocessedCount();
        },
      ),
    );
  }

  Future<void> _importCsv(String type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'json' ? ['json'] : ['csv'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    final path = file.path;
    String csvText;
    if (bytes != null) {
      csvText = String.fromCharCodes(bytes);
    } else if (path != null) {
      csvText = await File(path).readAsString();
    } else {
      return;
    }

    final rows = parseCsv(csvText);
    final dataRows = rows.length > 1 ? rows.skip(1).toList() : <List<String>>[];
    final previewRows = dataRows.take(3).toList();
    final headerRow = rows.isNotEmpty ? rows.first : <String>[];

    final filePathStatuses = <({String path, bool? exists})>[];
    if (type == 'records') {
      for (final row in previewRows) {
        final p = row.length > 10 ? row[10].trim() : '';
        if (p.isEmpty) {
          filePathStatuses.add((path: '', exists: null));
        } else {
          filePathStatuses.add((path: p, exists: await File(p).exists()));
        }
      }
    }

    if (!mounted) return;

    bool overwrite = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('가져오기: ${file.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('총 ${dataRows.length}행 발견됨',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (previewRows.isNotEmpty) ...[
                    const Text('미리보기 (최대 3행):',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 28,
                        dataRowMaxHeight: 28,
                        columnSpacing: 12,
                        columns: headerRow
                            .map((h) => DataColumn(
                                label: Text(h, style: const TextStyle(fontSize: 11))))
                            .toList(),
                        rows: previewRows
                            .map((row) => DataRow(
                                  cells: List.generate(
                                    headerRow.length,
                                    (i) => DataCell(Text(
                                      i < row.length ? row[i] : '',
                                      style: const TextStyle(fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (type == 'records' && filePathStatuses.isNotEmpty) ...[
                    const Text('파일경로 확인:',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey)),
                    const SizedBox(height: 4),
                    ...filePathStatuses.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final s = entry.value;
                      final rowTitle = previewRows[idx].isNotEmpty
                          ? previewRows[idx][0]
                          : '(제목 없음)';
                      if (s.exists == null) {
                        return _FilePathRow(
                          rowLabel: '${idx + 2}행 [$rowTitle]',
                          status: _FilePathStatus.none,
                          path: '',
                        );
                      } else if (s.exists!) {
                        return _FilePathRow(
                          rowLabel: '${idx + 2}행 [$rowTitle]',
                          status: _FilePathStatus.found,
                          path: s.path,
                        );
                      } else {
                        return _FilePathRow(
                          rowLabel: '${idx + 2}행 [$rowTitle]',
                          status: _FilePathStatus.notFound,
                          path: s.path,
                        );
                      }
                    }),
                    const SizedBox(height: 8),
                  ],
                  const Text('가져오기 방식:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioGroup<bool>(
                    groupValue: overwrite,
                    onChanged: (v) => setDlgState(() { if (v != null) overwrite = v; }),
                    child: const Column(
                      children: [
                        RadioListTile<bool>(
                          dense: true,
                          title: Text('기존 데이터에 추가'),
                          value: false,
                        ),
                        RadioListTile<bool>(
                          dense: true,
                          title: Text('전체 덮어쓰기'),
                          value: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('가져오기'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    ImportResult importResult;
    try {
      if (type == 'records') {
        final recordRepo = await ref.read(recordRepositoryProvider.future);
        final narratorRepo = await ref.read(narratorRepositoryProvider.future);
        final interviewerRepo = await ref.read(interviewerRepositoryProvider.future);
        final sessionRepo = await ref.read(sessionRepositoryProvider.future);
        importResult = await ImportExportService.importRecordsCsv(
          csvText, overwrite, recordRepo, narratorRepo, interviewerRepo, sessionRepo,
          fileStorage: ref.read(fileStorageProvider),
        );
      } else if (type == 'narrators') {
        final narratorRepo = await ref.read(narratorRepositoryProvider.future);
        importResult = await ImportExportService.importNarratorsCsv(csvText, overwrite, narratorRepo);
      } else if (type == 'interviewers') {
        final interviewerRepo = await ref.read(interviewerRepositoryProvider.future);
        importResult = await ImportExportService.importInterviewersCsv(csvText, overwrite, interviewerRepo);
      } else {
        final recordRepo = await ref.read(recordRepositoryProvider.future);
        final narratorRepo = await ref.read(narratorRepositoryProvider.future);
        final interviewerRepo = await ref.read(interviewerRepositoryProvider.future);
        final sessionRepo = await ref.read(sessionRepositoryProvider.future);
        importResult = await ImportExportService.importJson(
          csvText, recordRepo, narratorRepo, interviewerRepo, sessionRepo, overwrite,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('가져오기 실패: $e')));
      return;
    }

    if (!mounted) return;

    final String msg;
    if (type == 'records' &&
        (importResult.importedWithFile > 0 || importResult.importedTextOnly > 0)) {
      final parts = <String>['${importResult.imported}건 가져오기 완료'];
      if (importResult.importedWithFile > 0) parts.add('파일 포함 ${importResult.importedWithFile}건');
      if (importResult.importedTextOnly > 0) parts.add('텍스트만 ${importResult.importedTextOnly}건');
      if (importResult.failed > 0) parts.add('실패 ${importResult.failed}건');
      msg = parts.join(' · ');
    } else {
      msg = '${importResult.imported}건 가져오기 완료${importResult.failed > 0 ? ' (${importResult.failed}건 실패)' : ''}';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    if (importResult.errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('가져오기 오류 보고'),
          content: SizedBox(
            width: 400,
            height: 300,
            child: ListView(
              children: importResult.errors
                  .map((e) => Text(e, style: const TextStyle(fontSize: 12, color: Colors.red)))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('닫기')),
          ],
        ),
      );
    }
  }

  Future<void> _downloadCsvTemplates() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final templateDir = Directory('${docsDir.path}/OralRecordAgent/templates');
      await templateDir.create(recursive: true);
      const bom = '\uFEFF';
      await File('${templateDir.path}/records_template.csv').writeAsString(
          '$bom제목,구술자,면담자,면담일시,면담장소,주제대분류,주제소분류,키워드태그,비공개,메모,파일경로\n'
          '예시-삭제후입력,홍길동,연구원A,2026-03-25,서울,개인사,주거,"태그1,태그2",Y,메모내용,C:\\Users\\samsung\\Documents\\면담.mp3\n',
          flush: true);
      await File('${templateDir.path}/narrators_template.csv').writeAsString(
          '$bom이름,생년월일,성별,직업(당시),직업(현재),소속,메모\n', flush: true);
      await File('${templateDir.path}/interviewers_template.csv').writeAsString(
          '$bom이름,소속,직위,전문분야,메모\n', flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('템플릿 저장 완료: ${templateDir.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('템플릿 저장 실패: $e')));
    }
  }

  Future<void> _testWhisper() async {
    setState(() { _whisperTesting = true; _whisperTestResult = null; });
    final settings = ref.read(settingsProvider);
    final result = await LocalTranscriptionService.transcribeFile(
      filePath: 'test_nonexistent_file_check_only.wav',
      pythonPath: settings.pythonPath,
      model: settings.whisperModel,
      language: settings.transcriptionLanguage,
    );
    if (!mounted) return;
    String msg;
    if (result.pythonNotFound) {
      msg = 'Python을 찾을 수 없습니다.\n경로를 확인하거나 python3 등으로 변경해보세요.';
    } else if (result.whisperNotInstalled) {
      msg = 'openai-whisper가 설치되지 않았습니다.\npip install openai-whisper';
    } else if (result.error != null && result.error!.contains('찾을 수 없습니다')) {
      msg = '파일 오류 (예상됨): Python과 Whisper는 정상 설치되어 있습니다.';
    } else {
      msg = result.error ?? 'Python과 Whisper 설치 확인 완료';
    }
    setState(() { _whisperTesting = false; _whisperTestResult = msg; });
  }

  // ── BUILD ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authProvider).currentUser;
    final isAdmin = user?.hasPermission(Permission.canManageAccounts) ?? false;

    final items = <_SidebarMenuItem>[
      const _SidebarMenuItem(icon: Icons.person_outline, label: '내 계정', index: 0),
      if (isAdmin)
        const _SidebarMenuItem(icon: Icons.manage_accounts_outlined, label: '계정 관리', index: 1),
      const _SidebarMenuItem(icon: Icons.vpn_key_outlined, label: 'API 설정', index: 2),
      const _SidebarMenuItem(icon: Icons.mic_none, label: 'Whisper 설정', index: 3),
      const _SidebarMenuItem(icon: Icons.storage_outlined, label: '데이터 관리', index: 4),
      const _SidebarMenuItem(icon: Icons.info_outline, label: '앱 정보', index: 5),
    ];

    final validSections = items.map((e) => e.index).toSet();
    if (!validSections.contains(_selectedSection)) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) { if (mounted) setState(() => _selectedSection = 0); });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('설정'),
      ),
      body: Row(
        children: [
          _buildSidebar(context, user, items),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(child: _buildContent(context, settings)),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, Account? user, List<_SidebarMenuItem> items) {
    const selectedBg = Color(0xFF2D4A9E);
    return Container(
      width: 200,
      color: AppTheme.primary,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final isSelected = _selectedSection == item.index;
                return InkWell(
                  onTap: () => setState(() => _selectedSection = item.index),
                  child: Container(
                    color: isSelected ? selectedBg : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(item.icon, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 3,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppTheme.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          _buildSidebarFooter(context, user),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context, Account? user) {
    if (user == null) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.accent.withValues(alpha: 0.3),
                child: Text(
                  user.displayName.isNotEmpty ? user.displayName[0] : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    Text(user.role.displayName,
                        style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[300],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('로그아웃하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && mounted) {
                  await ref.read(authProvider.notifier).logout();
                }
              },
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('로그아웃', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppSettingsState settings) {
    return switch (_selectedSection) {
      0 => _buildMyAccountSection(context),
      1 => const AccountManagementContent(),
      2 => _buildApiSection(context, settings),
      3 => _buildWhisperSection(context, settings),
      4 => _buildDataSection(context, settings),
      5 => _buildAppInfoSection(context),
      _ => _buildMyAccountSection(context),
    };
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  // ── 섹션 0: 내 계정 ──────────────────────────────────────────────
  Widget _buildMyAccountSection(BuildContext context) {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const Center(child: Text('로그인 정보 없음'));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle(context, '내 계정'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    user.displayName.isNotEmpty ? user.displayName[0] : '?',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('@${user.username}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(user.role.displayName,
                            style: TextStyle(
                                color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('비밀번호 변경', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _PasswordChangePanel(userId: user.id),
      ],
    );
  }

  // ── 섹션 2: API 설정 ──────────────────────────────────────────────
  Widget _buildApiSection(BuildContext context, AppSettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle(context, 'API 설정'),
        Text('Anthropic (Claude) API', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('요약 생성 기능에 Claude API 키가 필요합니다.',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          obscureText: _apiKeyObscured,
          decoration: InputDecoration(
            labelText: 'Claude API 키',
            hintText: 'sk-ant-...',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_apiKeyObscured ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _apiKeyObscured = !_apiKeyObscured),
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: '저장',
                  onPressed: () {
                    ref.read(settingsProvider.notifier).setApiKey(_apiKeyController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Claude API 키가 저장되었습니다')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('OpenAI API', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('음성 전사(Whisper) 기능에 OpenAI API 키가 필요합니다.',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        TextField(
          controller: _openAiApiKeyController,
          obscureText: _openAiKeyObscured,
          decoration: InputDecoration(
            labelText: 'OpenAI API 키',
            hintText: 'sk-...',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_openAiKeyObscured ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _openAiKeyObscured = !_openAiKeyObscured),
                ),
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: '저장',
                  onPressed: () {
                    ref.read(settingsProvider.notifier).setOpenAiApiKey(_openAiApiKeyController.text.trim());
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OpenAI API 키가 저장되었습니다')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── 섹션 3: Whisper 설정 ──────────────────────────────────────────
  Widget _buildWhisperSection(BuildContext context, AppSettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle(context, 'Whisper 설정'),
        const Text(
          'Python과 openai-whisper 패키지를 사용해 인터넷 없이 음성을 전사합니다.\n'
          '설치: pip install openai-whisper',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        Text('Python 경로', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _pythonPathController,
          decoration: InputDecoration(
            hintText: 'python (또는 python3, C:\\Python311\\python.exe)',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.save),
              tooltip: '저장',
              onPressed: () {
                ref.read(settingsProvider.notifier).setPythonPath(_pythonPathController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Python 경로가 저장되었습니다')),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Whisper 모델'),
          subtitle: const Text('클수록 정확하지만 느리고 많은 메모리 필요'),
          trailing: DropdownButton<String>(
            value: settings.whisperModel,
            items: const [
              DropdownMenuItem(value: 'tiny', child: Text('tiny (39MB)')),
              DropdownMenuItem(value: 'base', child: Text('base (74MB) ★ 권장')),
              DropdownMenuItem(value: 'small', child: Text('small (244MB)')),
              DropdownMenuItem(value: 'medium', child: Text('medium (769MB)')),
              DropdownMenuItem(value: 'large', child: Text('large (1.5GB)')),
            ],
            onChanged: (val) {
              if (val != null) ref.read(settingsProvider.notifier).setWhisperModel(val);
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('전사 언어'),
          trailing: DropdownButton<String>(
            value: settings.transcriptionLanguage,
            items: const [
              DropdownMenuItem(value: 'ko', child: Text('한국어')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ja', child: Text('日本語')),
              DropdownMenuItem(value: 'zh', child: Text('中文')),
            ],
            onChanged: (val) {
              if (val != null) ref.read(settingsProvider.notifier).setTranscriptionLanguage(val);
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _whisperTesting ? null : _testWhisper,
              icon: _whisperTesting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_whisperTesting ? '확인 중...' : 'Whisper 설치 확인'),
            ),
          ],
        ),
        if (_whisperTestResult != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _whisperTestResult!.contains('정상') || _whisperTestResult!.contains('완료')
                  ? Colors.green[50]
                  : Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _whisperTestResult!.contains('정상') || _whisperTestResult!.contains('완료')
                    ? Colors.green[300]!
                    : Colors.orange[300]!,
              ),
            ),
            child: Text(
              _whisperTestResult!,
              style: TextStyle(
                color: _whisperTestResult!.contains('정상') || _whisperTestResult!.contains('완료')
                    ? Colors.green[800]
                    : Colors.orange[800],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('저장된 Whisper 모델', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: _loadCachedModels,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('새로고침'),
            ),
          ],
        ),
        if (!_cacheLoaded)
          const Text('새로고침을 눌러 캐시 목록을 불러오세요.', style: TextStyle(color: Colors.grey))
        else if (_cachedModels.isEmpty)
          const Text('캐시된 모델 없음', style: TextStyle(color: Colors.grey))
        else
          ...(_cachedModels.map((f) {
            final name = f.path.split(Platform.pathSeparator).last;
            final sizeMb = ((f as File).lengthSync() / 1024 / 1024).toStringAsFixed(0);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.storage, size: 18),
              title: Text(name),
              subtitle: Text('$sizeMb MB'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: '삭제',
                onPressed: () => _deleteCachedModel(f),
              ),
            );
          })),
      ],
    );
  }

  // ── 섹션 4: 데이터 관리 ──────────────────────────────────────────
  Widget _buildDataSection(BuildContext context, AppSettingsState settings) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle(context, '데이터 관리'),
        Text('가져오기 / 처리', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_fix_high),
          title: const Text('미처리 기록 일괄 처리'),
          subtitle: Text(
            _batchRunning
                ? '$_batchDone/$_batchTotal 처리 중...'
                : _unprocessedCount == null
                    ? 'PDF/DOCX/음성/영상 미처리 기록을 일괄 처리합니다'
                    : _unprocessedCount! == 0
                        ? '미처리 기록 없음'
                        : '미처리 기록 ${_unprocessedCount!}건',
          ),
          trailing: _batchRunning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : _unprocessedCount != null && _unprocessedCount! > 0
                  ? Badge(
                      label: Text('$_unprocessedCount'),
                      child: const Icon(Icons.arrow_forward_ios, size: 16),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _batchRunning ? null : _showBatchExtractionSheet,
        ),
        const Divider(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.upload_file),
          title: const Text('기록 CSV 가져오기'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _importCsv('records'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_add),
          title: const Text('구술자 CSV 가져오기'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _importCsv('narrators'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.people),
          title: const Text('면담자 CSV 가져오기'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _importCsv('interviewers'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.restore),
          title: const Text('백업 JSON 가져오기'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => _importCsv('json'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download),
          title: const Text('CSV 템플릿 내려받기'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _downloadCsvTemplates,
        ),
        const SizedBox(height: 24),
        Text('기타 설정', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('자동 전사'),
          subtitle: const Text('음성 기록 저장 시 자동으로 텍스트로 변환'),
          value: settings.autoTranscribe,
          onChanged: (v) => ref.read(settingsProvider.notifier).toggleAutoTranscribe(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('PII 감지'),
          subtitle: const Text('개인식별정보 자동 감지 및 표시'),
          value: settings.enablePIIDetection,
          onChanged: (v) => ref.read(settingsProvider.notifier).togglePIIDetection(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('기본 내보내기 형식'),
          trailing: DropdownButton<String>(
            value: settings.exportFormat,
            items: const [
              DropdownMenuItem(value: 'json', child: Text('JSON')),
              DropdownMenuItem(value: 'txt', child: Text('TXT')),
            ],
            onChanged: (format) {
              if (format != null) ref.read(settingsProvider.notifier).setExportFormat(format);
            },
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('다크 모드'),
          value: settings.darkMode,
          onChanged: (v) => ref.read(settingsProvider.notifier).toggleDarkMode(),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('언어'),
          trailing: DropdownButton<String>(
            value: settings.language,
            items: const [
              DropdownMenuItem(value: 'ko', child: Text('한국어')),
              DropdownMenuItem(value: 'en', child: Text('English')),
            ],
            onChanged: (lang) {
              if (lang != null) ref.read(settingsProvider.notifier).setLanguage(lang);
            },
          ),
        ),
      ],
    );
  }

  // ── 섹션 5: 앱 정보 ──────────────────────────────────────────────
  Widget _buildAppInfoSection(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionTitle(context, '앱 정보'),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('버전'),
          trailing: Text('1.0.0'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.folder_outlined),
          title: const Text('저장 경로'),
          subtitle: FutureBuilder<Directory>(
            future: getApplicationDocumentsDirectory(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Text('...');
              return Text('${snap.data!.path}/OralRecordAgent',
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis);
            },
          ),
        ),
        const Divider(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('이용약관'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('개인정보처리방침'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {},
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('오픈소스 라이선스'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () => showLicensePage(
            context: context,
            applicationName: '구술기록관리 에이전트',
            applicationVersion: '1.0.0',
          ),
        ),
      ],
    );
  }
}

// ── 사이드바 메뉴 항목 ─────────────────────────────────────────────────────

class _SidebarMenuItem {
  final IconData icon;
  final String label;
  final int index;
  const _SidebarMenuItem({required this.icon, required this.label, required this.index});
}

// ── 파일경로 상태 표시 위젯 ────────────────────────────────────────────────

enum _FilePathStatus { found, notFound, none }

class _FilePathRow extends StatelessWidget {
  final String rowLabel;
  final _FilePathStatus status;
  final String path;

  const _FilePathRow({
    required this.rowLabel,
    required this.status,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String displayText;

    switch (status) {
      case _FilePathStatus.found:
        color = Colors.green[700]!;
        icon = Icons.check_circle_outline;
        displayText = path;
      case _FilePathStatus.notFound:
        color = Colors.red[700]!;
        icon = Icons.cancel_outlined;
        displayText = path;
      case _FilePathStatus.none:
        color = Colors.grey;
        icon = Icons.remove;
        displayText = '(파일 없음)';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(rowLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(width: 6),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(displayText,
                style: TextStyle(fontSize: 11, color: color), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── 일괄 텍스트 추출 바텀시트 ──────────────────────────────────────────────

class _BatchProcessingSheet extends StatefulWidget {
  final List<Record> targets;
  final dynamic settings;
  final dynamic fileStorage;
  final dynamic repository;
  final VoidCallback onStart;
  final void Function(int done) onProgress;
  final VoidCallback onDone;

  const _BatchProcessingSheet({
    required this.targets,
    required this.settings,
    required this.fileStorage,
    required this.repository,
    required this.onStart,
    required this.onProgress,
    required this.onDone,
  });

  @override
  State<_BatchProcessingSheet> createState() => _BatchProcessingSheetState();
}

class _BatchProcessingSheetState extends State<_BatchProcessingSheet> {
  bool _running = false;
  int _done = 0;
  final Map<String, String?> _errors = {};

  Future<void> _runAll() async {
    setState(() { _running = true; _done = 0; _errors.clear(); });
    widget.onStart();

    final pythonPath = widget.settings.pythonPath as String;

    for (final record in widget.targets) {
      String? errMsg;
      try {
        final bytes = await widget.fileStorage.loadBytes(record.id) as dynamic;
        if (bytes == null || (bytes as List).isEmpty) {
          errMsg = '파일 없음';
        } else {
          final tmpDir = await getTemporaryDirectory();
          final ext = record.originalFileName?.split('.').last ?? 'bin';
          final tmpFile = File('${tmpDir.path}/batch_${record.id}.$ext');
          await tmpFile.writeAsBytes(bytes as List<int>, flush: true);

          final ptype = RecordProcessingUtil.getProcessingType(record);
          String resultText = '';
          bool success = false;
          String? error;

          if (ptype == ProcessingType.extractDocument) {
            final r = await DocumentExtractionService.extractText(
              filePath: tmpFile.path,
              pythonPath: pythonPath,
            );
            success = r.success;
            resultText = r.text;
            error = r.error;
          } else if (ptype == ProcessingType.transcribeAudio) {
            final r = await LocalTranscriptionService.transcribeFile(
              filePath: tmpFile.path,
              pythonPath: pythonPath,
              model: widget.settings.whisperModel as String,
              language: widget.settings.transcriptionLanguage as String,
            );
            success = r.success;
            resultText = r.text;
            error = r.error;
          } else if (ptype == ProcessingType.transcribeVideo) {
            final r = await VideoTranscriptionService.transcribeVideo(
              videoPath: tmpFile.path,
              pythonPath: pythonPath,
              model: widget.settings.whisperModel as String,
              language: widget.settings.transcriptionLanguage as String,
            );
            success = r.success;
            resultText = r.text;
            error = r.error;
          }

          try { await tmpFile.delete(); } catch (_) {}

          if (success && resultText.isNotEmpty) {
            final updated = record.copyWith(content: resultText);
            await widget.repository.updateRecord(record.id, updated);
          } else {
            errMsg = error ?? '처리 실패';
          }
        }
      } catch (e) {
        errMsg = '$e';
      }

      if (!mounted) return;
      setState(() { _done++; _errors[record.id] = errMsg; });
      widget.onProgress(_done);
    }

    if (mounted) setState(() => _running = false);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.targets.length;
    final successCount = _errors.values.where((e) => e == null).length;
    final failCount = _errors.values.where((e) => e != null).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('미처리 기록 ($total건)',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (!_running && _done == 0)
                  ElevatedButton.icon(
                    onPressed: _runAll,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('전체 처리'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_running || _done > 0) ...[
              LinearProgressIndicator(value: _done / total),
              const SizedBox(height: 4),
              Text(
                _running
                    ? '$_done/$total 처리 중...'
                    : '완료: 성공 $successCount건 / 실패 $failCount건',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: widget.targets.length,
                itemBuilder: (ctx, i) {
                  final r = widget.targets[i];
                  final err = _errors[r.id];
                  final processed = _errors.containsKey(r.id);
                  final typeLabel = RecordProcessingUtil.getButtonLabel(r);
                  return ListTile(
                    dense: true,
                    leading: processed
                        ? Icon(
                            err == null ? Icons.check_circle : Icons.error,
                            color: err == null ? Colors.green : Colors.red,
                            size: 18)
                        : Icon(Icons.hourglass_empty, size: 18, color: Colors.grey[400]),
                    title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      err ?? (processed ? '처리 완료' : typeLabel),
                      style: TextStyle(
                          fontSize: 11, color: err != null ? Colors.red : Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 비밀번호 변경 패널 ─────────────────────────────────────────────────────

class _PasswordChangePanel extends ConsumerStatefulWidget {
  final String userId;
  const _PasswordChangePanel({required this.userId});

  @override
  ConsumerState<_PasswordChangePanel> createState() => _PasswordChangePanelState();
}

class _PasswordChangePanelState extends ConsumerState<_PasswordChangePanel> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPw = _newCtrl.text;
    if (newPw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 합니다');
      return;
    }
    if (newPw != _confirmCtrl.text) {
      setState(() => _error = '새 비밀번호가 일치하지 않습니다');
      return;
    }
    setState(() { _isSaving = true; _error = null; _success = false; });
    try {
      final valid = await AuthService.verifyPassword(
        accountId: widget.userId,
        password: _currentCtrl.text,
      );
      if (!valid) {
        if (mounted) setState(() { _error = '현재 비밀번호가 올바르지 않습니다'; _isSaving = false; });
        return;
      }
      await AuthService.changePassword(accountId: widget.userId, newPassword: newPw);
      if (mounted) {
        setState(() { _success = true; _isSaving = false; });
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _isSaving = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: '현재 비밀번호',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: '새 비밀번호',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: '새 비밀번호 확인',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            if (_success) ...[
              const SizedBox(height: 8),
              const Text('비밀번호가 변경되었습니다', style: TextStyle(color: Colors.green, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('비밀번호 변경'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
