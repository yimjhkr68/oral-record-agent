// 파일 목적: MetadataInputPage - 메타데이터 입력 화면 (v2)
// 구술자/면담자: 최근 사용 목록 + 검색 + 전체 목록 이동 + 인라인 추가
// 저장 후 → /records/detail/{id}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/metadata_form_provider.dart';
import '../providers/master_data_provider.dart';
import '../providers/pending_content_provider.dart';
import '../providers/record_provider.dart';
import '../../data/models/narrator.dart';
import '../../data/models/interviewer.dart';
import '../../data/models/interview_session.dart';
import '../../data/models/record.dart';
import '../../data/repositories/repository_provider.dart';

class MetadataInputPage extends ConsumerStatefulWidget {
  const MetadataInputPage({super.key});

  @override
  ConsumerState<MetadataInputPage> createState() => _MetadataInputPageState();
}

class _MetadataInputPageState extends ConsumerState<MetadataInputPage> {
  bool _isSaving = false;
  String _narratorSearch = '';
  String _interviewerSearch = '';
  bool _narratorSearchActive = false;
  bool _interviewerSearchActive = false;
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _keywordController = TextEditingController();
  final _keywordFocus = FocusNode();
  // 전사 실패 처리
  final _manualTextCtrl = TextEditingController();
  bool _showManualInput = false;
  bool _skipTranscription = false; // true이면 빈 내용으로 저장

  @override
  void initState() {
    super.initState();
    final pending = ref.read(pendingContentProvider);
    _titleController.text = pending?.suggestedTitle ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _keywordController.dispose();
    _keywordFocus.dispose();
    _manualTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final pending = ref.read(pendingContentProvider);
      final form = ref.read(metadataFormProvider);

      final sessionRepo = await ref.read(sessionRepositoryProvider.future);
      final session = InterviewSession(
        narratorId: form.narratorId!,
        interviewerId: form.interviewerId!,
        sessionNo: form.sessionNo,
        interviewDate: form.interviewDate!,
        interviewType: form.interviewType,
      );
      await sessionRepo.createSession(session);

      final recordRepo = await ref.read(recordRepositoryProvider.future);
      final d = form.interviewDate!;
      final dateStr =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      // 전사 실패 처리: 수동 입력 또는 건너뛰기
      String finalContent;
      if (_showManualInput && _manualTextCtrl.text.trim().isNotEmpty) {
        finalContent = _manualTextCtrl.text.trim();
      } else if (_skipTranscription) {
        finalContent = '';
      } else {
        finalContent = pending?.content ?? '';
      }

      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : '면담 기록 $dateStr';
      final record = Record(
        title: title,
        content: finalContent,
        inputType: pending?.inputType ?? 'text',
        sessionId: session.id,
        narratorId: form.narratorId!,
        mainCategory: form.mainCategory ?? '기타',
        keywordTags: form.keywords,
        visibility: form.visibility,
        recordedBy: 'user',
        originalFileName: pending?.fileName,
        fileSize: pending?.fileSize,
        mimeType: pending?.mimeType,
      );
      await recordRepo.createRecord(record);

      final bytes = pending?.bytes;
      if (bytes != null && bytes.isNotEmpty && pending?.fileName != null) {
        final fileStorage = ref.read(fileStorageProvider);
        await fileStorage.saveFile(
          recordId: record.id,
          bytes: bytes,
          fileName: pending!.fileName!,
          mimeType: pending.mimeType ?? 'application/octet-stream',
        );
      }

      ref.read(pendingContentProvider.notifier).state = null;
      ref.read(metadataFormProvider.notifier).reset();
      ref.invalidate(recentRecordsProvider);
      ref.invalidate(recordListProvider);
      debugPrint('[기록저장] title: ${record.title}');
      debugPrint('[기록저장] Hive 저장 완료: ${record.id}');
      debugPrint('[기록저장] Provider 갱신 완료');

      if (!mounted) return;
      context.go('/records/detail/${record.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── 구술자 추가 다이얼로그 ──────────────────────────────────
  Future<void> _showAddNarratorDialog() async {
    final nameCtrl = TextEditingController();
    final jobCtrl = TextEditingController();
    final affiliationCtrl = TextEditingController();
    String? selectedGender;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('새 구술자 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '이름 *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: '성별',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('선택 안 함')),
                    DropdownMenuItem(value: 'M', child: Text('남성')),
                    DropdownMenuItem(value: 'F', child: Text('여성')),
                    DropdownMenuItem(value: 'Other', child: Text('기타')),
                  ],
                  onChanged: (v) => setDlgState(() => selectedGender = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: jobCtrl,
                  decoration: const InputDecoration(
                    labelText: '직책/직함',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: affiliationCtrl,
                  decoration: const InputDecoration(
                    labelText: '소속 기관',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final repo =
                    await ref.read(narratorRepositoryProvider.future);
                final narrator = Narrator(
                  name: name,
                  gender: selectedGender,
                  jobTitle: jobCtrl.text.trim().isEmpty
                      ? null
                      : jobCtrl.text.trim(),
                  affiliation: affiliationCtrl.text.trim().isEmpty
                      ? null
                      : affiliationCtrl.text.trim(),
                );
                await repo.createNarrator(narrator);
                ref.invalidate(narratorListProvider);
                ref.invalidate(recentNarratorsProvider);
                ref
                    .read(metadataFormProvider.notifier)
                    .setNarrator(narrator.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  // ── 면담자 추가 다이얼로그 ──────────────────────────────────
  Future<void> _showAddInterviewerDialog() async {
    final nameCtrl = TextEditingController();
    final affiliationCtrl = TextEditingController();
    final jobTitleCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 면담자 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: '이름 *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: affiliationCtrl,
              decoration: const InputDecoration(
                  labelText: '소속 기관', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: jobTitleCtrl,
              decoration: const InputDecoration(
                  labelText: '직위', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final repo =
                  await ref.read(interviewerRepositoryProvider.future);
              final interviewer = Interviewer(
                name: name,
                affiliation: affiliationCtrl.text.trim().isEmpty
                    ? null
                    : affiliationCtrl.text.trim(),
                jobTitle: jobTitleCtrl.text.trim().isEmpty
                    ? null
                    : jobTitleCtrl.text.trim(),
              );
              await repo.createInterviewer(interviewer);
              ref.invalidate(interviewerListProvider);
              ref.invalidate(recentInterviewersProvider);
              ref
                  .read(metadataFormProvider.notifier)
                  .setInterviewer(interviewer.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(metadataFormProvider);
    final isValid = ref.watch(metadataFormValidProvider);
    final narrators = ref.watch(narratorListProvider);
    final interviewers = ref.watch(interviewerListProvider);
    final recentNarrators = ref.watch(recentNarratorsProvider);
    final recentInterviewers = ref.watch(recentInterviewersProvider);
    final pending = ref.watch(pendingContentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('메타데이터 입력')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pending != null) ...[
              _buildContentSummaryCard(pending),
              const SizedBox(height: 24),
            ],

            // ── 제목 ───────────────────────────────────────
            _sectionTitle('제목 *'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '기록 제목을 입력하세요',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              maxLength: 200,
            ),
            const SizedBox(height: 24),

            // ── 구술자 ─────────────────────────────────────
            _sectionTitle('구술자 *'),
            const SizedBox(height: 8),
            _PersonSelector(
              selectedId: formState.narratorId,
              allPersons: narrators,
              recentPersons: recentNarrators,
              searchText: _narratorSearch,
              searchActive: _narratorSearchActive,
              labelHint: '구술자 선택',
              onSelected: (id) {
                ref.read(metadataFormProvider.notifier).setNarrator(id);
                setState(() {
                  _narratorSearch = '';
                  _narratorSearchActive = false;
                });
              },
              onRemove: () =>
                  ref.read(metadataFormProvider.notifier).setNarrator(''),
              onSearchChanged: (v) =>
                  setState(() => _narratorSearch = v),
              onSearchActivated: () =>
                  setState(() => _narratorSearchActive = true),
              onViewAll: () => context.push('/people'),
              onAdd: _showAddNarratorDialog,
              getName: (p) => (p as Narrator).name,
              getSub: (p) {
                final n = p as Narrator;
                final parts = [
                  if (n.jobTitle != null) n.jobTitle,
                  if (n.affiliation != null) n.affiliation,
                ];
                return parts.isEmpty ? null : parts.join(' · ');
              },
            ),
            const SizedBox(height: 24),

            // ── 면담자 ─────────────────────────────────────
            _sectionTitle('면담자 *'),
            const SizedBox(height: 8),
            _PersonSelector(
              selectedId: formState.interviewerId,
              allPersons: interviewers,
              recentPersons: recentInterviewers,
              searchText: _interviewerSearch,
              searchActive: _interviewerSearchActive,
              labelHint: '면담자 선택',
              onSelected: (id) {
                ref
                    .read(metadataFormProvider.notifier)
                    .setInterviewer(id);
                setState(() {
                  _interviewerSearch = '';
                  _interviewerSearchActive = false;
                });
              },
              onRemove: () =>
                  ref.read(metadataFormProvider.notifier).setInterviewer(''),
              onSearchChanged: (v) =>
                  setState(() => _interviewerSearch = v),
              onSearchActivated: () =>
                  setState(() => _interviewerSearchActive = true),
              onViewAll: () => context.push('/people'),
              onAdd: _showAddInterviewerDialog,
              getName: (p) => (p as Interviewer).name,
              getSub: (p) {
                final iv = p as Interviewer;
                final parts = [
                  if (iv.jobTitle != null) iv.jobTitle,
                  if (iv.affiliation != null) iv.affiliation,
                ];
                return parts.isEmpty ? null : parts.join(' · ');
              },
            ),
            const SizedBox(height: 24),

            // ── 면담 일시 ──────────────────────────────────
            _sectionTitle('면담 일시 *'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: formState.interviewDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  ref
                      .read(metadataFormProvider.notifier)
                      .setInterviewDate(date);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(formState.interviewDate == null
                        ? '날짜 선택'
                        : '${formState.interviewDate!.year}-${formState.interviewDate!.month.toString().padLeft(2, '0')}-${formState.interviewDate!.day.toString().padLeft(2, '0')}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── 면담 위치 ──────────────────────────────────
            _sectionTitle('면담 위치'),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: '예: 서울시 종로구 면담실',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) =>
                  ref.read(metadataFormProvider.notifier).setLocation(v),
            ),
            const SizedBox(height: 24),

            // ── 회차 / 면담 유형 ────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('회차'),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: InputDecoration(
                          hintText: '1',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        controller: TextEditingController(
                            text: formState.sessionNo.toString()),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) {
                            ref
                                .read(metadataFormProvider.notifier)
                                .setSessionNo(n);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('면담 유형'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: formState.interviewType,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'oral', child: Text('구술')),
                          DropdownMenuItem(
                              value: 'written', child: Text('서면')),
                          DropdownMenuItem(
                              value: 'phone', child: Text('전화')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            ref
                                .read(metadataFormProvider.notifier)
                                .setInterviewType(v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 주제 분류 ───────────────────────────────────
            _sectionTitle('주제 분류 *'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              value: formState.mainCategory,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
              ),
              hint: const Text('선택 안 함'),
              items: const [
                DropdownMenuItem(value: null, child: Text('선택 안 함')),
                DropdownMenuItem(value: '역사', child: Text('역사')),
                DropdownMenuItem(value: '문화', child: Text('문화')),
                DropdownMenuItem(value: '과학', child: Text('과학')),
                DropdownMenuItem(value: '정치', child: Text('정치')),
                DropdownMenuItem(value: '경제', child: Text('경제')),
                DropdownMenuItem(value: '교육', child: Text('교육')),
                DropdownMenuItem(value: '보건', child: Text('보건')),
                DropdownMenuItem(value: '농업', child: Text('농업')),
                DropdownMenuItem(value: '기타', child: Text('기타')),
              ],
              onChanged: (v) =>
                  ref.read(metadataFormProvider.notifier).setMainCategory(v),
            ),
            const SizedBox(height: 24),

            // ── 키워드 ──────────────────────────────────────
            _sectionTitle('키워드 (최대 20개)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final kw in formState.keywords)
                  Chip(
                    label: Text(kw),
                    onDeleted: () => ref
                        .read(metadataFormProvider.notifier)
                        .removeKeyword(kw),
                  ),
              ],
            ),
            if (formState.keywords.length < 20) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _keywordController,
                focusNode: _keywordFocus,
                decoration: InputDecoration(
                  hintText: '키워드 입력 후 Enter',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _addKeyword,
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onSubmitted: (_) => _addKeyword(),
              ),
            ],
            const SizedBox(height: 24),

            // ── 비공개 여부 ────────────────────────────────
            Row(
              children: [
                Switch(
                  value: formState.visibility == 'private',
                  onChanged: (v) => ref
                      .read(metadataFormProvider.notifier)
                      .setVisibility(v ? 'private' : 'public'),
                ),
                const SizedBox(width: 8),
                Text(formState.visibility == 'private' ? '비공개' : '공개'),
              ],
            ),
            const SizedBox(height: 32),

            // ── 저장 버튼 ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (isValid && !_isSaving) ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _addKeyword() {
    final kw = _keywordController.text.trim();
    if (kw.isNotEmpty) {
      ref.read(metadataFormProvider.notifier).addKeyword(kw);
      _keywordController.clear();
      _keywordFocus.requestFocus();
    }
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      );

  Widget _buildContentSummaryCard(PendingContent pending) {
    IconData icon;
    switch (pending.inputType) {
      case 'audio':
        icon = Icons.mic;
      case 'video':
        icon = Icons.videocam;
      case 'document':
        icon = Icons.description;
      case 'image':
        icon = Icons.image;
      default:
        icon = Icons.text_fields;
    }

    final isAudio = pending.inputType == 'audio';
    final failed = pending.transcriptionFailed;

    // 전사 성공 여부 계산
    final transcriptionSuccess = isAudio && !failed &&
        pending.content.isNotEmpty &&
        !pending.content.startsWith('[');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: failed ? Colors.orange[50] : Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: failed ? Colors.orange[300]! : Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 파일명 + 크기
          Row(
            children: [
              Icon(icon,
                  color: failed ? Colors.orange[700] : Colors.blue[700],
                  size: 18),
              const SizedBox(width: 8),
              Text(
                _inputTypeLabel(pending.inputType),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: failed ? Colors.orange[700] : Colors.blue[700]),
              ),
              if (pending.fileName != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pending.fileName!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (pending.fileSize != null) ...[
            const SizedBox(height: 2),
            Text(
              _formatSize(pending.fileSize!),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],

          // ── 전사 상태 표시 ────────────────────────────
          if (isAudio) ...[
            const SizedBox(height: 8),
            if (transcriptionSuccess) ...[
              // 전사 성공
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '전사 완료: ${pending.content.length}자',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pending.content.length > 200
                    ? '${pending.content.substring(0, 200)}...'
                    : pending.content,
                style: const TextStyle(fontSize: 13),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ] else ...[
              // 전사 실패 또는 미진행
              const Row(
                children: [
                  Icon(Icons.warning_amber,
                      size: 16, color: Colors.orange),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '전사 실패 — 텍스트를 직접 입력하거나 나중에 입력할 수 있습니다',
                      style: TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              if (pending.transcriptionError != null) ...[
                const SizedBox(height: 4),
                Text(
                  pending.transcriptionError!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 10),
              // 수동 입력 선택 시
              if (_showManualInput) ...[
                TextField(
                  controller: _manualTextCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    hintText: '전사 텍스트를 직접 입력하세요...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _showManualInput = false),
                  child: const Text('취소'),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('텍스트 직접 입력'),
                        onPressed: () => setState(() {
                          _showManualInput = true;
                          _skipTranscription = false;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.skip_next, size: 16),
                        label: Text(_skipTranscription
                            ? '건너뛰기 선택됨 ✓'
                            : '건너뛰기'),
                        style: _skipTranscription
                            ? OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                side: const BorderSide(
                                    color: Colors.orange))
                            : null,
                        onPressed: () => setState(() {
                          _skipTranscription = !_skipTranscription;
                          _showManualInput = false;
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ] else ...[
            // 음성 아닌 파일: 내용 미리보기
            const SizedBox(height: 6),
            Text('내용 미리보기:',
                style: TextStyle(fontSize: 12, color: Colors.blue[600])),
            const SizedBox(height: 4),
            Text(
              pending.content.length > 200
                  ? '${pending.content.substring(0, 200)}...'
                  : pending.content,
              style: const TextStyle(fontSize: 13),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String _inputTypeLabel(String type) {
    switch (type) {
      case 'audio':
        return '음성 녹음/파일';
      case 'video':
        return '영상 파일';
      case 'document':
        return '문서 파일';
      default:
        return '텍스트 입력';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── 인물 선택 위젯 ───────────────────────────────────────────
class _PersonSelector extends StatelessWidget {
  final String? selectedId;
  final AsyncValue<List<dynamic>> allPersons;
  final AsyncValue<List<dynamic>> recentPersons;
  final String searchText;
  final bool searchActive;
  final String labelHint;
  final ValueChanged<String> onSelected;
  final VoidCallback onRemove;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchActivated;
  final VoidCallback onViewAll;
  final VoidCallback onAdd;
  final String Function(dynamic) getName;
  final String? Function(dynamic) getSub;

  const _PersonSelector({
    required this.selectedId,
    required this.allPersons,
    required this.recentPersons,
    required this.searchText,
    required this.searchActive,
    required this.labelHint,
    required this.onSelected,
    required this.onRemove,
    required this.onSearchChanged,
    required this.onSearchActivated,
    required this.onViewAll,
    required this.onAdd,
    required this.getName,
    required this.getSub,
  });

  @override
  Widget build(BuildContext context) {
    return allPersons.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const Text('로드 실패'),
      data: (all) {
        final selected =
            all.where((p) => p.id == selectedId).firstOrNull;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 선택된 항목
              if (selected != null) ...[
                _SelectedChip(
                  label: getName(selected),
                  sub: getSub(selected),
                  onRemove: onRemove,
                ),
                const SizedBox(height: 8),
              ],

              // 검색 필드
              TextField(
                decoration: InputDecoration(
                  hintText: '🔍 이름으로 검색...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                onTap: onSearchActivated,
                onChanged: onSearchChanged,
              ),

              // 검색 결과
              if (searchText.isNotEmpty) ...[
                const SizedBox(height: 4),
                _SearchResults(
                  items: all
                      .where((p) => getName(p)
                          .toLowerCase()
                          .contains(searchText.toLowerCase()))
                      .toList(),
                  getName: getName,
                  getSub: getSub,
                  onSelected: onSelected,
                ),
              ]

              // 검색 비활성 시: 최근 사용 + 버튼
              else ...[
                recentPersons.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (recent) {
                    if (recent.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        const Text('최근 사용',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        for (final p in recent)
                          InkWell(
                            onTap: () => onSelected(p.id as String),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.circle,
                                      size: 8, color: Colors.grey),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      getSub(p) != null
                                          ? '${getName(p)} | ${getSub(p)}'
                                          : getName(p),
                                      style:
                                          const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.list, size: 16),
                        label: const Text('전체 목록 보기'),
                        onPressed: onViewAll,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('새로 추가'),
                        onPressed: onAdd,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<dynamic> items;
  final String Function(dynamic) getName;
  final String? Function(dynamic) getSub;
  final ValueChanged<String> onSelected;

  const _SearchResults({
    required this.items,
    required this.getName,
    required this.getSub,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('검색 결과 없음', style: TextStyle(color: Colors.grey)),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final p = items[i];
          return ListTile(
            dense: true,
            title: Text(getName(p)),
            subtitle: getSub(p) != null ? Text(getSub(p)!) : null,
            onTap: () => onSelected(p.id as String),
          );
        },
      ),
    );
  }
}

class _SelectedChip extends StatelessWidget {
  final String label;
  final String? sub;
  final VoidCallback onRemove;

  const _SelectedChip(
      {required this.label, this.sub, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            sub != null ? '$label ($sub)' : label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close,
                size: 16,
                color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}
