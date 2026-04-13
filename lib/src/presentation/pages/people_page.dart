// 파일 목적: 인물사전 목록 화면 (구술자/면담자 탭)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/master_data_provider.dart';
import '../../data/models/narrator.dart';
import '../../data/models/interviewer.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/services/import_export_service.dart';
import '../../data/models/account.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/permission_guard.dart';

class PeoplePage extends ConsumerStatefulWidget {
  const PeoplePage({super.key});

  @override
  ConsumerState<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends ConsumerState<PeoplePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _narratorSearch = '';
  String _interviewerSearch = '';

  bool _editMode = false;
  final Set<String> _selectedNarrators = {};
  final Set<String> _selectedInterviewers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_editMode) {
        setState(() {
          _editMode = false;
          _selectedNarrators.clear();
          _selectedInterviewers.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;
      _selectedNarrators.clear();
      _selectedInterviewers.clear();
    });
  }

  void _selectAllNarrators(List<Narrator> list) {
    setState(() {
      if (_selectedNarrators.length == list.length) {
        _selectedNarrators.clear();
      } else {
        _selectedNarrators
          ..clear()
          ..addAll(list.map((n) => n.id));
      }
    });
  }

  void _selectAllInterviewers(List<Interviewer> list) {
    setState(() {
      if (_selectedInterviewers.length == list.length) {
        _selectedInterviewers.clear();
      } else {
        _selectedInterviewers
          ..clear()
          ..addAll(list.map((i) => i.id));
      }
    });
  }

  Future<void> _showSelectedExportDialog(BuildContext context) async {
    final isNarratorTab = _tabController.index == 0;
    final selectedIds =
        isNarratorTab ? _selectedNarrators : _selectedInterviewers;
    if (selectedIds.isEmpty) return;

    String format = 'CSV';
    final now = DateTime.now();
    final defaultName = isNarratorTab
        ? 'narrators_selected_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        : 'interviewers_selected_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileNameController = TextEditingController(text: defaultName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(isNarratorTab ? '선택 구술자 내보내기' : '선택 면담자 내보내기'),
          content: SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('선택된 인물: ${selectedIds.length}명',
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
                const SizedBox(height: 8),
                const Text('파일명', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: fileNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
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
      final exportDir = Directory('${docsDir.path}/OralRecordAgent/exports');
      await exportDir.create(recursive: true);

      final ext = format == 'CSV' ? 'csv' : 'json';
      final fileName =
          '${fileNameController.text.trim().isNotEmpty ? fileNameController.text.trim() : defaultName}.$ext';
      final filePath = '${exportDir.path}/$fileName';

      String content;
      if (isNarratorTab) {
        final allNarrators =
            ref.read(narratorListProvider).valueOrNull ?? [];
        final selected =
            allNarrators.where((n) => selectedIds.contains(n.id)).toList();
        if (format == 'CSV') {
          content = ImportExportService.exportNarratorsCsv(selected);
        } else {
          content = ImportExportService.exportAllJson([], selected, [], []);
        }
      } else {
        final allInterviewers =
            ref.read(interviewerListProvider).valueOrNull ?? [];
        final selected =
            allInterviewers.where((i) => selectedIds.contains(i.id)).toList();
        if (format == 'CSV') {
          content = ImportExportService.exportInterviewersCsv(selected);
        } else {
          content = ImportExportService.exportAllJson([], [], selected, []);
        }
      }

      final fileContent = format == 'CSV' ? '\uFEFF$content' : content;
      await File(filePath).writeAsString(fileContent, flush: true);

      if (!context.mounted) return;
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
                Process.run('explorer', [exportDir.path]);
                Navigator.of(ctx).pop();
              },
              child: const Text('폴더 열기'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }

  Future<void> _showExportDialog(BuildContext context) async {
    final isNarratorTab = _tabController.index == 0;
    String format = 'CSV';
    final now = DateTime.now();
    final defaultName = isNarratorTab
        ? 'narrators_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
        : 'interviewers_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fileNameController = TextEditingController(text: defaultName);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(isNarratorTab ? '구술자 내보내기' : '면담자 내보내기'),
          content: SizedBox(
            width: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                const SizedBox(height: 8),
                const Text('파일명', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: fileNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
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
      final exportDir = Directory('${docsDir.path}/OralRecordAgent/exports');
      await exportDir.create(recursive: true);

      final ext = format == 'CSV' ? 'csv' : 'json';
      final fileName =
          '${fileNameController.text.trim().isNotEmpty ? fileNameController.text.trim() : defaultName}.$ext';
      final filePath = '${exportDir.path}/$fileName';

      String content;
      if (isNarratorTab) {
        final narrators =
            ref.read(narratorListProvider).valueOrNull ?? [];
        if (format == 'CSV') {
          content = ImportExportService.exportNarratorsCsv(narrators);
        } else {
          content = ImportExportService.exportAllJson([], narrators, [], []);
        }
      } else {
        final interviewers =
            ref.read(interviewerListProvider).valueOrNull ?? [];
        if (format == 'CSV') {
          content = ImportExportService.exportInterviewersCsv(interviewers);
        } else {
          content = ImportExportService.exportAllJson([], [], interviewers, []);
        }
      }

      // CSV는 Excel 한글 인식을 위해 UTF-8 BOM 추가
      final fileContent = format == 'CSV' ? '\uFEFF$content' : content;
      await File(filePath).writeAsString(fileContent, flush: true);

      if (!context.mounted) return;
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
                Process.run('explorer', [exportDir.path]);
                Navigator.of(ctx).pop();
              },
              child: const Text('폴더 열기'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('내보내기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarratorTab = _tabController.index == 0;
    final selectedCount = isNarratorTab
        ? _selectedNarrators.length
        : _selectedInterviewers.length;
    final canCreate = ref.watch(authProvider).currentUser
            ?.hasPermission(Permission.canCreateNarrator) ??
        false;

    return Scaffold(
      appBar: AppBar(
        title: _editMode
            ? Text('$selectedCount명 선택됨')
            : const Text('인물사전'),
        actions: [
          if (_editMode) ...[
            if (isNarratorTab)
              Builder(builder: (ctx) {
                final list =
                    ref.watch(narratorListProvider).valueOrNull ?? [];
                return TextButton(
                  onPressed: () => _selectAllNarrators(list),
                  child: Text(
                    _selectedNarrators.length == list.length
                        ? '선택 해제'
                        : '전체선택',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              })
            else
              Builder(builder: (ctx) {
                final list =
                    ref.watch(interviewerListProvider).valueOrNull ?? [];
                return TextButton(
                  onPressed: () => _selectAllInterviewers(list),
                  child: Text(
                    _selectedInterviewers.length == list.length
                        ? '선택 해제'
                        : '전체선택',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: '선택 내보내기',
              onPressed: selectedCount == 0
                  ? null
                  : () => _showSelectedExportDialog(context),
            ),
            TextButton(
              onPressed: _toggleEditMode,
              child: const Text('완료',
                  style: TextStyle(color: Colors.white)),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '편집',
              onPressed: _toggleEditMode,
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: '내보내기',
              onPressed: () => _showExportDialog(context),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(context),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _NarratorTab(
                  search: _narratorSearch,
                  onSearchChanged: (v) => setState(() => _narratorSearch = v),
                  editMode: _editMode,
                  selected: _selectedNarrators,
                  onToggle: (id) => setState(() {
                    if (_selectedNarrators.contains(id)) {
                      _selectedNarrators.remove(id);
                    } else {
                      _selectedNarrators.add(id);
                    }
                  }),
                ),
                _InterviewerTab(
                  search: _interviewerSearch,
                  onSearchChanged: (v) => setState(() => _interviewerSearch = v),
                  editMode: _editMode,
                  selected: _selectedInterviewers,
                  onToggle: (id) => setState(() {
                    if (_selectedInterviewers.contains(id)) {
                      _selectedInterviewers.remove(id);
                    } else {
                      _selectedInterviewers.add(id);
                    }
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _editMode
          ? null
          : FloatingActionButton(
              onPressed: canCreate
                  ? () {
                      final isNarTab = _tabController.index == 0;
                      context.push(isNarTab
                          ? '/people/narrator/add'
                          : '/people/interviewer/add');
                    }
                  : () => showNoPermissionSnackBar(
                      context, Permission.canCreateNarrator),
              tooltip: canCreate ? '새 인물 추가' : '등록 권한 없음',
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final narratorCount =
        ref.watch(narratorListProvider).valueOrNull?.length ?? 0;
    final interviewerCount =
        ref.watch(interviewerListProvider).valueOrNull?.length ?? 0;
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final idx = _tabController.index;
        return Container(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _TabItem(
                    label: '구술자',
                    count: narratorCount,
                    selected: idx == 0,
                    onTap: () => _tabController.animateTo(0),
                  ),
                  _TabItem(
                    label: '면담자',
                    count: interviewerCount,
                    selected: idx == 1,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ],
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            ],
          ),
        );
      },
    );
  }
}

// ── 탭 아이템 ─────────────────────────────────────────────────
class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const selectedColor = AppTheme.primary;
    const unselectedColor = Color(0xFF6B7280);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Stack(
            children: [
              Center(
                child: Text(
                  '$label ($count)',
                  style: TextStyle(
                    color: selected ? selectedColor : unselectedColor,
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 3,
                    decoration: const BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 구술자 탭 ─────────────────────────────────────────────────
class _NarratorTab extends ConsumerWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool editMode;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _NarratorTab({
    required this.search,
    required this.onSearchChanged,
    required this.editMode,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final narrators = ref.watch(narratorListProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: '이름으로 검색...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: narrators.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('로드 실패: $e')),
            data: (list) {
              final filtered = search.isEmpty
                  ? list
                  : list
                      .where((n) => n.name
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                      .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_off,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        search.isEmpty ? '등록된 구술자가 없습니다.' : '검색 결과 없음',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _NarratorCard(
                  narrator: filtered[i],
                  editMode: editMode,
                  selected: selected.contains(filtered[i].id),
                  onToggle: () => onToggle(filtered[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NarratorCard extends ConsumerWidget {
  final Narrator narrator;
  final bool editMode;
  final bool selected;
  final VoidCallback onToggle;

  const _NarratorCard({
    required this.narrator,
    required this.editMode,
    required this.selected,
    required this.onToggle,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구술자 삭제'),
        content: Text('"${narrator.name}"을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = await ref.read(narratorRepositoryProvider.future);
    await repo.deleteNarrator(narrator.id);
    ref.invalidate(narratorListProvider);
    ref.invalidate(narratorMapProvider);
    ref.invalidate(recentNarratorsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDelete = ref.watch(authProvider).currentUser
            ?.hasPermission(Permission.canDeleteNarrator) ??
        false;
    final subtitle = [
      if (narrator.jobTitle != null) narrator.jobTitle,
      if (narrator.affiliation != null) narrator.affiliation,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            narrator.name.isNotEmpty ? narrator.name[0] : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(narrator.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (narrator.displayId != null)
              Text(
                narrator.displayId!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey,
                  fontFamily: 'monospace',
                ),
              ),
            if (subtitle.isNotEmpty) Text(subtitle),
          ],
        ),
        trailing: editMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18,
                        color: canDelete ? AppTheme.error : AppTheme.textDisabled),
                    tooltip: canDelete ? '삭제' : '삭제 권한 없음',
                    onPressed: canDelete
                        ? () => _delete(context, ref)
                        : () => showNoPermissionSnackBar(
                            context, Permission.canDeleteNarrator),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
        onTap: editMode
            ? onToggle
            : () => context.push('/people/narrator/${narrator.id}'),
      ),
    );
  }
}

// ── 면담자 탭 ─────────────────────────────────────────────────
class _InterviewerTab extends ConsumerWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final bool editMode;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _InterviewerTab({
    required this.search,
    required this.onSearchChanged,
    required this.editMode,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviewers = ref.watch(interviewerListProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: '이름으로 검색...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        Expanded(
          child: interviewers.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('로드 실패: $e')),
            data: (list) {
              final filtered = search.isEmpty
                  ? list
                  : list
                      .where((i) => i.name
                          .toLowerCase()
                          .contains(search.toLowerCase()))
                      .toList();
              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        search.isEmpty ? '등록된 면담자가 없습니다.' : '검색 결과 없음',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _InterviewerCard(
                  interviewer: filtered[i],
                  editMode: editMode,
                  selected: selected.contains(filtered[i].id),
                  onToggle: () => onToggle(filtered[i].id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InterviewerCard extends ConsumerWidget {
  final Interviewer interviewer;
  final bool editMode;
  final bool selected;
  final VoidCallback onToggle;

  const _InterviewerCard({
    required this.interviewer,
    required this.editMode,
    required this.selected,
    required this.onToggle,
  });

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('면담자 삭제'),
        content: Text('"${interviewer.name}"을(를) 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD32F2F)),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final repo = await ref.read(interviewerRepositoryProvider.future);
    await repo.deleteInterviewer(interviewer.id);
    ref.invalidate(interviewerListProvider);
    ref.invalidate(interviewerMapProvider);
    ref.invalidate(recentInterviewersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canDelete = ref.watch(authProvider).currentUser
            ?.hasPermission(Permission.canDeleteNarrator) ??
        false;
    final subtitle = [
      if (interviewer.jobTitle != null) interviewer.jobTitle,
      if (interviewer.affiliation != null) interviewer.affiliation,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Text(
            interviewer.name.isNotEmpty ? interviewer.name[0] : '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(interviewer.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (interviewer.displayId != null)
              Text(
                interviewer.displayId!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.blueGrey,
                  fontFamily: 'monospace',
                ),
              ),
            if (subtitle.isNotEmpty) Text(subtitle),
          ],
        ),
        trailing: editMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => onToggle(),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        size: 18,
                        color: canDelete ? AppTheme.error : AppTheme.textDisabled),
                    tooltip: canDelete ? '삭제' : '삭제 권한 없음',
                    onPressed: canDelete
                        ? () => _delete(context, ref)
                        : () => showNoPermissionSnackBar(
                            context, Permission.canDeleteNarrator),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
        onTap: editMode
            ? onToggle
            : () => context.push('/people/interviewer/${interviewer.id}'),
      ),
    );
  }
}
