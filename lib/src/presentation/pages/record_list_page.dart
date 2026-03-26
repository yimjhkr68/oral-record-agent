// 파일 목적: RecordListPage - 기록 목록 화면
// 검색/필터, 편집 모드(체크박스+일괄삭제), 개별 삭제, 미처리 배지

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/record.dart';
import '../../data/models/narrator.dart';
import '../../data/models/interviewer.dart';
import '../../data/models/interview_session.dart';
import '../../data/models/search_filters.dart';
import '../../data/utils/record_processing_util.dart';
import '../../data/services/import_export_service.dart';
import '../providers/record_provider.dart';
import '../providers/search_filter_provider.dart';
import '../providers/master_data_provider.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../data/models/account.dart';
import '../widgets/permission_guard.dart';
import 'ai_content_generation_page.dart';

enum _SortOption {
  latest,
  oldest,
  title,
  narrator;

  String get label {
    switch (this) {
      case _SortOption.latest:  return '최신순';
      case _SortOption.oldest:  return '오래된순';
      case _SortOption.title:   return '제목순';
      case _SortOption.narrator: return '구술자순';
    }
  }
}

class RecordListPage extends ConsumerStatefulWidget {
  const RecordListPage({super.key});

  @override
  ConsumerState<RecordListPage> createState() => _RecordListPageState();
}

class _RecordListPageState extends ConsumerState<RecordListPage> {
  bool _editMode = false;
  final Set<String> _selected = {};
  _SortOption _sortOption = _SortOption.latest;

  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;
      _selected.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  bool _isFiltered(SearchFilters f) =>
      f.narratorId != null ||
      f.interviewerId != null ||
      f.startDate != null ||
      f.endDate != null ||
      (f.location != null && f.location!.isNotEmpty) ||
      (f.mainCategory != null && f.mainCategory!.isNotEmpty) ||
      f.isPrivate != null ||
      (f.query != null && f.query!.isNotEmpty);

  List<Record> _sortRecords(
      List<Record> records, Map<String, dynamic> narratorMap) {
    final list = [...records];
    switch (_sortOption) {
      case _SortOption.latest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _SortOption.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _SortOption.title:
        list.sort((a, b) => a.title.compareTo(b.title));
      case _SortOption.narrator:
        list.sort((a, b) {
          final na = (narratorMap[a.narratorId]?.name ?? '') as String;
          final nb = (narratorMap[b.narratorId]?.name ?? '') as String;
          return na.compareTo(nb);
        });
    }
    return list;
  }

  Widget _buildSummaryBar({
    required BuildContext context,
    required int filteredCount,
    required int totalCount,
    required bool isFiltered,
  }) {
    return Container(
      color: const Color(0xFFF4F6FA),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: isFiltered
                ? RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 14),
                      children: [
                        TextSpan(
                          text: '검색 결과 $filteredCount건',
                          style: const TextStyle(
                            color: Color(0xFF1A2B5E),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' / 전체 $totalCount건',
                          style: const TextStyle(color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  )
                : Text(
                    '전체 $totalCount건',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A2B5E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          if (isFiltered)
            TextButton.icon(
              onPressed: () =>
                  ref.read(searchFilterProvider.notifier).reset(),
              icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
              label: const Text('필터 초기화'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                textStyle: const TextStyle(fontSize: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          const SizedBox(width: 4),
          DropdownButtonHideUnderline(
            child: DropdownButton<_SortOption>(
              value: _sortOption,
              isDense: true,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF6B7280)),
              items: _SortOption.values
                  .map((o) => DropdownMenuItem(
                        value: o,
                        child: Text(o.label),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _sortOption = v);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(BuildContext context, Record record) async {
    final confirmed = await _showDeleteDialog(context, record.title);
    if (confirmed != true || !context.mounted) return;
    await ref.read(recordFormProvider.notifier).deleteRecord(record.id);
  }

  Future<void> _deleteBulk(BuildContext context, List<Record> all) async {
    final targets = all.where((r) => _selected.contains(r.id)).toList();
    if (targets.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일괄 삭제'),
        content: Text('선택한 ${targets.length}건을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    for (final r in targets) {
      ref.read(recordFormProvider.notifier).deleteRecord(r.id);
    }
    setState(() {
      _selected.clear();
      _editMode = false;
    });
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('"$title"\n\n이 기록을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: AppTheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportDialog(
    BuildContext context,
    List<Record> allRecords,
    Map<String, Narrator> narratorMap,
    Map<String, Interviewer> interviewerMap,
    Map<String, InterviewSession> sessionMap,
    SearchFilters currentFilters,
  ) async {
    String scope = '전체'; // 전체 / 현재 필터 결과
    String format = 'CSV'; // CSV / JSON
    bool includeContent = false;
    bool includeSummary = false;
    final now = DateTime.now();
    final defaultName =
        'records_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileNameController = TextEditingController(text: defaultName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('기록 내보내기'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('범위', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioGroup<String>(
                    groupValue: scope,
                    onChanged: (v) => setDlgState(() { if (v != null) scope = v; }),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          dense: true,
                          title: Text('전체'),
                          value: '전체',
                        ),
                        RadioListTile<String>(
                          dense: true,
                          title: Text('현재 필터 결과'),
                          value: '현재 필터 결과',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('형식', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioGroup<String>(
                    groupValue: format,
                    onChanged: (v) => setDlgState(() { if (v != null) format = v; }),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          dense: true,
                          title: Text('CSV'),
                          value: 'CSV',
                        ),
                        RadioListTile<String>(
                          dense: true,
                          title: Text('JSON (백업용)'),
                          value: 'JSON',
                        ),
                      ],
                    ),
                  ),
                  if (format == 'CSV') ...[
                    const SizedBox(height: 8),
                    const Text('포함 항목', style: TextStyle(fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      dense: true,
                      title: const Text('전사내용'),
                      value: includeContent,
                      onChanged: (v) => setDlgState(() => includeContent = v!),
                    ),
                    CheckboxListTile(
                      dense: true,
                      title: const Text('요약'),
                      value: includeSummary,
                      onChanged: (v) => setDlgState(() => includeSummary = v!),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text('파일명', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: fileNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: '.csv / .json',
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
              child: const Text('내보내기'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final records = scope == '전체' ? allRecords : allRecords;
      // 현재 필터 결과는 이미 allRecords에 필터 적용돼 있음

      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir =
          Directory('${docsDir.path}/OralRecordAgent/exports');
      await exportDir.create(recursive: true);

      final ext = format == 'CSV' ? 'csv' : 'json';
      final fileName = '${fileNameController.text.trim().isNotEmpty ? fileNameController.text.trim() : defaultName}.$ext';
      final filePath = '${exportDir.path}/$fileName';

      String content;
      if (format == 'CSV') {
        content = ImportExportService.exportRecordsCsv(
          records,
          narratorMap,
          interviewerMap,
          sessionMap,
          includeContent: includeContent,
          includeSummary: includeSummary,
        );
      } else {
        final allNarratorsList = narratorMap.values.toList();
        final allInterviewersList = interviewerMap.values.toList();
        final allSessionsList = sessionMap.values.toList();
        content = ImportExportService.exportAllJson(
          records,
          allNarratorsList,
          allInterviewersList,
          allSessionsList,
        );
      }

      // CSV는 Excel 한글 인식을 위해 UTF-8 BOM 추가
      final fileContent = format == 'CSV' ? '\uFEFF$content' : content;
      await File(filePath).writeAsString(fileContent, flush: true);

      if (!context.mounted) return;
      _showExportSuccessDialog(context, exportDir.path, filePath);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }

  void _showExportSuccessDialog(
      BuildContext context, String folderPath, String filePath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내보내기 완료'),
        content: Text(filePath),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Process.run('explorer', [folderPath]);
              Navigator.of(ctx).pop();
            },
            child: const Text('폴더 열기'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSelectedExportDialog(
    BuildContext context,
    List<Record> allRecords,
    Map<String, Narrator> narratorMap,
    Map<String, Interviewer> interviewerMap,
    Map<String, InterviewSession> sessionMap,
  ) async {
    final selectedRecords =
        allRecords.where((r) => _selected.contains(r.id)).toList();
    if (selectedRecords.isEmpty) return;

    String format = 'CSV';
    bool includeContent = false;
    bool includeSummary = false;
    final now = DateTime.now();
    final defaultName =
        'records_selected_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileNameController = TextEditingController(text: defaultName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('선택 항목 내보내기'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('선택된 기록: ${selectedRecords.length}건',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('형식', style: TextStyle(fontWeight: FontWeight.bold)),
                  RadioGroup<String>(
                    groupValue: format,
                    onChanged: (v) =>
                        setDlgState(() { if (v != null) format = v; }),
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          dense: true,
                          title: Text('CSV'),
                          value: 'CSV',
                        ),
                        RadioListTile<String>(
                          dense: true,
                          title: Text('JSON (백업용)'),
                          value: 'JSON',
                        ),
                      ],
                    ),
                  ),
                  if (format == 'CSV') ...[
                    const SizedBox(height: 8),
                    const Text('포함 항목',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    CheckboxListTile(
                      dense: true,
                      title: const Text('전사내용'),
                      value: includeContent,
                      onChanged: (v) =>
                          setDlgState(() => includeContent = v ?? false),
                    ),
                    CheckboxListTile(
                      dense: true,
                      title: const Text('요약'),
                      value: includeSummary,
                      onChanged: (v) =>
                          setDlgState(() => includeSummary = v ?? false),
                    ),
                  ],
                  const SizedBox(height: 8),
                  const Text('파일명',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: fileNameController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      suffixText: '.csv / .json',
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
              child: const Text('내보내기'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final exportDir =
          Directory('${docsDir.path}/OralRecordAgent/exports');
      await exportDir.create(recursive: true);

      final ext = format == 'CSV' ? 'csv' : 'json';
      final fileName =
          '${fileNameController.text.trim().isNotEmpty ? fileNameController.text.trim() : defaultName}.$ext';
      final filePath = '${exportDir.path}/$fileName';

      String content;
      if (format == 'CSV') {
        content = ImportExportService.exportRecordsCsv(
          selectedRecords,
          narratorMap,
          interviewerMap,
          sessionMap,
          includeContent: includeContent,
          includeSummary: includeSummary,
        );
      } else {
        final usedNarratorIds =
            selectedRecords.map((r) => r.narratorId).toSet();
        final usedSessionIds =
            selectedRecords.map((r) => r.sessionId).toSet();
        final usedInterviewerIds = sessionMap.values
            .where((s) => usedSessionIds.contains(s.id))
            .map((s) => s.interviewerId)
            .toSet();
        content = ImportExportService.exportAllJson(
          selectedRecords,
          narratorMap.values
              .where((n) => usedNarratorIds.contains(n.id))
              .toList(),
          interviewerMap.values
              .where((i) => usedInterviewerIds.contains(i.id))
              .toList(),
          sessionMap.values
              .where((s) => usedSessionIds.contains(s.id))
              .toList(),
        );
      }

      final fileContent = format == 'CSV' ? '\uFEFF$content' : content;
      await File(filePath).writeAsString(fileContent, flush: true);

      if (!context.mounted) return;
      _showExportSuccessDialog(context, exportDir.path, filePath);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(searchFilterProvider);
    final records = ref.watch(recordListProvider(filters));
    final allRecords = ref.watch(recordListProvider(SearchFilters(limit: 999999)));
    final narratorMap = ref.watch(narratorMapProvider).valueOrNull ?? {};
    final interviewerMap = ref.watch(interviewerMapProvider).valueOrNull ?? {};
    final sessionMap = ref.watch(sessionMapProvider).valueOrNull ?? {};

    final isFiltered = _isFiltered(filters);
    final filteredCount = records.valueOrNull?.length ?? 0;
    final totalCount = allRecords.valueOrNull?.length ?? 0;

    final canDelete = ref.watch(authProvider).currentUser
            ?.hasPermission(Permission.canDeleteRecord) ??
        false;
    final canCreate = ref.watch(authProvider).currentUser
            ?.hasPermission(Permission.canCreateRecord) ??
        false;

    return Scaffold(
      appBar: AppBar(
        leading: _editMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '편집 종료',
                onPressed: _toggleEditMode,
              )
            : null,
        title: _editMode
            ? Text('${_selected.length}개 선택됨')
            : const Text('기록 목록'),
        actions: [
          if (_editMode) ...[
            // AI 생성 (골드 강조)
            IconButton(
              icon: Icon(
                Icons.auto_awesome,
                color: _selected.isEmpty
                    ? Colors.white.withValues(alpha: 0.35)
                    : const Color(0xFFC9A84C),
              ),
              tooltip: 'AI 생성',
              onPressed: _selected.isEmpty
                  ? null
                  : () => _openAiGeneration(context, records.valueOrNull ?? []),
            ),
            // 내보내기
            IconButton(
              icon: Icon(
                Icons.upload_file,
                color: _selected.isEmpty
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.white,
              ),
              tooltip: '선택 내보내기',
              onPressed: _selected.isEmpty
                  ? null
                  : () => _showSelectedExportDialog(
                        context,
                        records.valueOrNull ?? [],
                        narratorMap,
                        interviewerMap,
                        sessionMap,
                      ),
            ),
            // 삭제
            if (canDelete)
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: _selected.isEmpty
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.white,
                ),
                tooltip: '선택 삭제',
                onPressed: (_selected.isEmpty || records.valueOrNull == null)
                    ? null
                    : () => _deleteBulk(context, records.valueOrNull!),
              )
            else
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.white.withValues(alpha: 0.35)),
                tooltip: '삭제 권한 없음',
                onPressed: () =>
                    showNoPermissionSnackBar(context, Permission.canDeleteRecord),
              ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '편집',
              onPressed: _toggleEditMode,
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => context.push('/records/search-filter'),
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: '내보내기',
              onPressed: () => _showExportDialog(
                context,
                records.valueOrNull ?? [],
                narratorMap,
                interviewerMap,
                sessionMap,
                filters,
              ),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildSummaryBar(
            context: context,
            filteredCount: filteredCount,
            totalCount: totalCount,
            isFiltered: isFiltered,
          ),
          Expanded(
            child: records.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              data: (recordList) {
                final sorted = _sortRecords(recordList, narratorMap);
                return sorted.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox_outlined,
                                  size: 64, color: AppTheme.textDisabled),
                              SizedBox(height: 16),
                              Text(
                                '아직 등록된 기록이 없습니다.\n+ 버튼을 눌러 첫 기록을 추가해보세요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) {
                          final record = sorted[index];
                          final narrator = narratorMap[record.narratorId];
                          final session = sessionMap[record.sessionId];
                          final interviewer = session != null
                              ? interviewerMap[session.interviewerId]
                              : null;
                          return _RecordCard(
                            record: record,
                            narrator: narrator,
                            interviewer: interviewer,
                            session: session,
                            editMode: _editMode,
                            selected: _selected.contains(record.id),
                            canDelete: canDelete,
                            onTap: _editMode
                                ? () => _toggleSelect(record.id)
                                : () => context
                                    .push('/records/detail/${record.id}'),
                            onLongPress: _editMode
                                ? null
                                : () => _showContextMenu(context, record),
                            onDelete: canDelete
                                ? () => _deleteRecord(context, record)
                                : () => showNoPermissionSnackBar(
                                    context, Permission.canDeleteRecord),
                          );
                        },
                      );
              },
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('기록 로드 실패'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          ref.refresh(recordListProvider(filters)),
                      child: const Text('재시도'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _editMode
          ? null
          : FloatingActionButton(
              onPressed: canCreate
                  ? () => _showAddOptions(context)
                  : () => showNoPermissionSnackBar(
                      context, Permission.canCreateRecord),
              child: const Icon(Icons.add),
            ),
    );
  }

  void _showContextMenu(BuildContext context, Record record) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('상세 보기'),
              onTap: () {
                Navigator.of(ctx).pop();
                context.push('/records/detail/${record.id}');
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppTheme.error),
              title: Text('삭제', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteRecord(context, record);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openAiGeneration(BuildContext context, List<Record> allRecords) {
    final selectedRecords =
        allRecords.where((r) => _selected.contains(r.id)).toList();
    if (selectedRecords.isEmpty) return;

    final hasContent =
        selectedRecords.any((r) => r.content.trim().isNotEmpty);
    if (!hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '선택한 기록 중 전사된 내용이 없습니다. 먼저 음성/영상을 전사해주세요.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          AiContentGenerationPage(selectedRecords: selectedRecords),
    ));
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic),
              title: const Text('음성 녹음'),
              onTap: () { Navigator.of(ctx).pop(); context.push('/recording'); },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('파일 업로드'),
              onTap: () { Navigator.of(ctx).pop(); context.push('/file-picker'); },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('텍스트/문서 입력'),
              onTap: () { Navigator.of(ctx).pop(); context.push('/text-input'); },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 카드 ────────────────────────────────────────────────────────────────────

class _RecordCard extends StatelessWidget {
  final Record record;
  final Narrator? narrator;
  final Interviewer? interviewer;
  final InterviewSession? session;
  final bool editMode;
  final bool selected;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.record,
    required this.narrator,
    required this.interviewer,
    required this.session,
    required this.editMode,
    required this.selected,
    required this.canDelete,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = _formatDate(session?.interviewDate ?? record.createdAt);
    final location = session?.location;
    final fileSizeStr = record.fileSize != null ? _formatFileSize(record.fileSize!) : null;
    final durationStr = record.duration != null ? _formatDuration(record.duration!) : null;
    final needsProcessing = RecordProcessingUtil.needsProcessing(record);

    String? interviewerText;
    if (interviewer != null) {
      interviewerText = interviewer!.affiliation != null
          ? '${interviewer!.name} · ${interviewer!.affiliation}'
          : interviewer!.name;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: selected ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 편집 모드 체크박스
              if (editMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8, top: 2),
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onTap(),
                  ),
                ),

              // 카드 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // displayId
                    if (record.displayId != null) ...[
                      Text(
                        record.displayId!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF78909C),
                          fontFamily: 'monospace',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    // 제목 + 포맷 배지 + 미처리 배지
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _FormatBadge(
                            mimeType: record.mimeType,
                            inputType: record.inputType),
                      ],
                    ),
                    // 미처리 배지
                    if (needsProcessing) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.warning_amber,
                              size: 12, color: Colors.orange[700]),
                          const SizedBox(width: 3),
                          Text(
                            '텍스트 미추출',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (narrator != null)
                      _InfoRow(icon: Icons.person, text: narrator!.name),
                    if (interviewerText != null)
                      _InfoRow(
                          icon: Icons.record_voice_over, text: interviewerText),
                    _InfoRow(icon: Icons.calendar_today, text: dateStr),
                    if (location != null && location.isNotEmpty)
                      _InfoRow(icon: Icons.location_on, text: location),
                    if (fileSizeStr != null)
                      _InfoRow(icon: Icons.storage, text: fileSizeStr),
                    if (durationStr != null)
                      _InfoRow(icon: Icons.access_time, text: durationStr),
                  ],
                ),
              ),

              // 삭제 버튼 (편집 모드 아닐 때)
              if (!editMode)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18,
                      color: canDelete
                          ? AppTheme.error
                          : AppTheme.textDisabled),
                  tooltip: canDelete ? '삭제' : '삭제 권한 없음',
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── 공통 위젯 ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatBadge extends StatelessWidget {
  final String? mimeType;
  final String inputType;
  const _FormatBadge({required this.mimeType, required this.inputType});

  @override
  Widget build(BuildContext context) {
    final label = _getLabel();
    final color = _getColor();
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String? _getLabel() {
    if (mimeType != null) {
      if (mimeType!.contains('wav')) return 'WAV';
      if (mimeType!.contains('mpeg') || mimeType!.contains('mp3')) return 'MP3';
      if (mimeType!.contains('m4a') || mimeType!.contains('mp4a')) return 'M4A';
      if (mimeType!.contains('mp4')) return 'MP4';
      if (mimeType!.contains('avi')) return 'AVI';
      if (mimeType!.contains('mov') || mimeType!.contains('quicktime')) { return 'MOV'; }
      if (mimeType!.contains('pdf')) return 'PDF';
      if (mimeType!.contains('docx') || mimeType!.contains('wordprocessingml')) { return 'DOCX'; }
    }
    if (inputType == 'audio') return 'AUDIO';
    if (inputType == 'video') return 'VIDEO';
    if (inputType == 'document') return 'DOC';
    return null;
  }

  Color _getColor() {
    final label = _getLabel();
    if (label == null) return AppTheme.textFileColor;
    if ({'WAV', 'MP3', 'M4A', 'AUDIO'}.contains(label)) {
      return AppTheme.audioColor;
    }
    if ({'MP4', 'AVI', 'MOV', 'VIDEO'}.contains(label)) {
      return AppTheme.videoColor;
    }
    if ({'PDF', 'DOCX', 'DOC'}.contains(label)) {
      return AppTheme.docColor;
    }
    return AppTheme.textFileColor;
  }
}
