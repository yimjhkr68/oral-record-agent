// 파일 목적: RecordDetailPage - 기록 상세 화면 (Windows 버전)
// 콘텐츠 미리보기, 파일 저장(다운로드), 마스킹(PII 제거), 요약 확인 다이얼로그 포함

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../data/models/record.dart';
import '../../data/models/narrator.dart';
import '../../data/models/interviewer.dart';
import '../../data/models/interview_session.dart';
import '../../domain/tools/detect_pii.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/services/local_transcription_service.dart';
import '../../data/services/document_extraction_service.dart';
import '../../data/services/video_transcription_service.dart';
import '../../data/utils/record_processing_util.dart';
import '../providers/record_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/master_data_provider.dart';
import '../providers/auth_provider.dart';
import '../../data/models/account.dart';
import '../widgets/permission_guard.dart';
import '../routes.dart';

const _contentPreviewLimit = 300;
const _summaryContentMaxChars = 3000;

class RecordDetailPage extends ConsumerStatefulWidget {
  final String recordId;

  const RecordDetailPage({
    required this.recordId,
    super.key,
  });

  @override
  ConsumerState<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends ConsumerState<RecordDetailPage> {
  // 콘텐츠 확장 상태
  bool _showFullContent = false;

  // 마스킹 상태
  bool _isMasking = false;
  String? _maskedPreview;
  String? _maskingError;
  bool _isSavingMask = false;
  bool _maskingSaved = false;

  // 요약 상태
  bool _isSummarizing = false;
  String? _summaryError;

  // 다운로드 상태
  bool _isDownloading = false;

  // 음성/영상 전사 상태
  bool _isTranscribing = false;
  String _transcriptionLabel = '처리 중...';
  String? _transcriptionError;

  // 문서 텍스트 추출 상태
  bool _isExtracting = false;
  String? _extractionError;

  // ── 편집 모드 상태 ──────────────────────────────────────────
  bool _isEditing = false;
  bool _isSaving = false;
  bool _hasChanges = false;
  Record? _editingRecord;
  InterviewSession? _editingSession;

  // 편집 폼 컨트롤러
  TextEditingController? _editTitleCtrl;
  TextEditingController? _editSubCatCtrl;
  TextEditingController? _editLocationCtrl;
  TextEditingController? _editNotesCtrl;
  TextEditingController? _editKeywordInputCtrl;
  TextEditingController? _editSessionNoCtrl;
  TextEditingController? _editContentCtrl;
  String _originalContent = ''; // 원본 복원용

  // 편집 폼 선택값
  String _editMainCategory = '기타';
  String _editVisibility = 'public';
  String _editInterviewType = 'oral';
  String _editLanguage = 'ko';
  List<String> _editKeywords = [];
  DateTime _editInterviewDate = DateTime.now();
  Narrator? _editNarrator;
  Interviewer? _editInterviewer;

  bool get _isBusy =>
      _isMasking || _isSummarizing || _isSavingMask || _isDownloading ||
      _isTranscribing || _isExtracting;

  void _markChanged() => setState(() => _hasChanges = true);

  void _disposeEditControllers() {
    _editTitleCtrl?.dispose(); _editTitleCtrl = null;
    _editSubCatCtrl?.dispose(); _editSubCatCtrl = null;
    _editLocationCtrl?.dispose(); _editLocationCtrl = null;
    _editNotesCtrl?.dispose(); _editNotesCtrl = null;
    _editKeywordInputCtrl?.dispose(); _editKeywordInputCtrl = null;
    _editSessionNoCtrl?.dispose(); _editSessionNoCtrl = null;
    _editContentCtrl?.dispose(); _editContentCtrl = null;
  }

  @override
  void dispose() {
    _disposeEditControllers();
    super.dispose();
  }

  // ────────────────────────────── OOM 다이얼로그 ──────────────────────────────

  void _showOOMDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('메모리 부족'),
        content: const Text(
          '메모리가 부족합니다.\n'
          '설정에서 더 작은 Whisper 모델을 선택해주세요.\n\n'
          '권장: base 또는 small 모델',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go('/settings');
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────── 편집 모드 ──────────────────────────────

  Future<void> _enterEditMode(Record r) async {
    final sessionRepo = await ref.read(sessionRepositoryProvider.future);
    final session = await sessionRepo.getSession(r.sessionId);
    final narratorMap = await ref.read(narratorMapProvider.future);
    final interviewerMap = await ref.read(interviewerMapProvider.future);

    _originalContent = r.content;
    _editTitleCtrl = TextEditingController(text: r.title)..addListener(_markChanged);
    _editSubCatCtrl = TextEditingController(text: r.subCategory ?? '')..addListener(_markChanged);
    _editContentCtrl = TextEditingController(text: r.content)..addListener(_markChanged);
    _editLocationCtrl = TextEditingController(text: session?.location ?? '')..addListener(_markChanged);
    _editNotesCtrl = TextEditingController(text: session?.notes ?? '')..addListener(_markChanged);
    _editKeywordInputCtrl = TextEditingController();
    _editSessionNoCtrl = TextEditingController(text: (session?.sessionNo ?? 1).toString())..addListener(_markChanged);

    setState(() {
      _isEditing = true;
      _hasChanges = false;
      _editingRecord = r;
      _editingSession = session;
      _editMainCategory = r.mainCategory;
      _editVisibility = r.visibility;
      _editInterviewType = session?.interviewType ?? 'oral';
      _editLanguage = session?.language ?? 'ko';
      _editKeywords = List.from(r.keywordTags);
      _editInterviewDate = session?.interviewDate ?? r.createdAt;
      _editNarrator = narratorMap[r.narratorId];
      _editInterviewer = session != null ? interviewerMap[session.interviewerId] : null;
    });
  }

  /// 사용자가 취소 버튼 누를 때 — 변경사항 있으면 확인 다이얼로그
  Future<void> _cancelEdit() async {
    if (_hasChanges) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('편집 취소'),
          content: const Text('저장하지 않은 변경사항이 있습니다.\n편집을 취소하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('계속 편집'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('취소하고 나가기'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    _clearEditState();
  }

  /// 저장 완료 후 또는 강제 종료 시 상태 초기화
  void _clearEditState() {
    _disposeEditControllers();
    setState(() {
      _isEditing = false;
      _hasChanges = false;
      _editingRecord = null;
      _editingSession = null;
    });
  }

  Future<void> _saveEdits() async {
    final r = _editingRecord!;
    final title = _editTitleCtrl!.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목을 입력해주세요')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final recordRepo = await ref.read(recordRepositoryProvider.future);
      final updatedRecord = r.copyWith(
        title: title,
        narratorId: _editNarrator?.id,
        mainCategory: _editMainCategory,
        subCategory: _editSubCatCtrl!.text.trim().isEmpty
            ? null
            : _editSubCatCtrl!.text.trim(),
        keywordTags: _editKeywords,
        visibility: _editVisibility,
        content: _editContentCtrl!.text,
      );
      await recordRepo.updateRecord(r.id, updatedRecord);

      final session = _editingSession;
      if (session != null) {
        final sessionRepo = await ref.read(sessionRepositoryProvider.future);
        final sessionNo = int.tryParse(_editSessionNoCtrl!.text) ?? session.sessionNo;
        final updatedSession = InterviewSession(
          id: session.id,
          narratorId: _editNarrator?.id ?? session.narratorId,
          interviewerId: _editInterviewer?.id ?? session.interviewerId,
          sessionNo: sessionNo,
          interviewDate: _editInterviewDate,
          location: _editLocationCtrl!.text.trim().isEmpty
              ? null
              : _editLocationCtrl!.text.trim(),
          interviewType: _editInterviewType,
          language: _editLanguage,
          notes: _editNotesCtrl!.text.trim().isEmpty
              ? null
              : _editNotesCtrl!.text.trim(),
          createdAt: session.createdAt,
        );
        await sessionRepo.updateSession(session.id, updatedSession);
        ref.invalidate(sessionMapProvider);
      }

      ref.invalidate(recordDetailProvider(widget.recordId));
      if (!mounted) return;
      _clearEditState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('저장되었습니다'),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickPerson({required bool isNarrator}) async {
    if (isNarrator) {
      final narrators = await ref.read(narratorListProvider.future);
      if (!mounted) return;
      final selected = await _showPersonDialog<Narrator>(
        title: '구술자 선택',
        items: narrators,
        getName: (n) => n.name,
        currentId: _editNarrator?.id,
      );
      if (selected != null) setState(() { _editNarrator = selected; _hasChanges = true; });
    } else {
      final interviewers = await ref.read(interviewerListProvider.future);
      if (!mounted) return;
      final selected = await _showPersonDialog<Interviewer>(
        title: '면담자 선택',
        items: interviewers,
        getName: (i) => i.name,
        currentId: _editInterviewer?.id,
      );
      if (selected != null) setState(() { _editInterviewer = selected; _hasChanges = true; });
    }
  }

  Future<T?> _showPersonDialog<T>({
    required String title,
    required List<T> items,
    required String Function(T) getName,
    String? currentId,
  }) async {
    final searchCtrl = TextEditingController();
    return showDialog<T>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final query = searchCtrl.text.toLowerCase();
          final filtered = query.isEmpty
              ? items
              : items.where((i) => getName(i).toLowerCase().contains(query)).toList();
          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 300,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                      hintText: '이름 검색',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('검색 결과 없음'))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final item = filtered[i];
                              final name = getName(item);
                              // Get ID via dynamic lookup
                              final dynamic dyn = item;
                              final String id = dyn.id as String;
                              return ListTile(
                                title: Text(name),
                                selected: id == currentId,
                                selectedTileColor: Colors.blue[50],
                                onTap: () => Navigator.pop(ctx, item),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _restoreOriginalContent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('원본 복원'),
        content: const Text('전사 내용을 원본으로 되돌릴까요?\n수정한 내용이 사라집니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('복원하기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _editContentCtrl!.text = _originalContent;
    setState(() => _hasChanges = true);
  }

  Future<void> _showFindReplaceDialog() async {
    final findCtrl = TextEditingController();
    final replaceCtrl = TextEditingController();
    int matchCount = 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          void doFind() {
            final q = findCtrl.text;
            if (q.isEmpty) { setDlgState(() => matchCount = 0); return; }
            setDlgState(() {
              matchCount = q.isEmpty ? 0 : _editContentCtrl!.text.split(q).length - 1;
            });
          }

          void doReplaceAll() {
            final q = findCtrl.text;
            final rep = replaceCtrl.text;
            if (q.isEmpty) return;
            final newText = _editContentCtrl!.text.replaceAll(q, rep);
            final count = _editContentCtrl!.text.split(q).length - 1;
            _editContentCtrl!.text = newText;
            setState(() => _hasChanges = true);
            setDlgState(() => matchCount = 0);
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$count건을 바꿨습니다')),
            );
          }

          return AlertDialog(
            title: const Text('찾기/바꾸기'),
            content: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: findCtrl,
                    decoration: const InputDecoration(
                      labelText: '찾기',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => doFind(),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: replaceCtrl,
                    decoration: const InputDecoration(
                      labelText: '바꾸기',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (findCtrl.text.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        matchCount == 0 ? '일치하는 항목 없음' : '$matchCount건 발견',
                        style: TextStyle(
                          fontSize: 12,
                          color: matchCount > 0 ? Colors.blue[700] : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('닫기')),
              OutlinedButton(onPressed: doFind, child: const Text('찾기')),
              FilledButton(
                onPressed: matchCount > 0 ? doReplaceAll : null,
                child: const Text('전체 바꾸기'),
              ),
            ],
          );
        },
      ),
    );
    findCtrl.dispose();
    replaceCtrl.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _editInterviewDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_editInterviewDate),
    );
    if (!mounted) return;
    setState(() {
      _editInterviewDate = DateTime(
        date.year, date.month, date.day,
        time?.hour ?? _editInterviewDate.hour,
        time?.minute ?? _editInterviewDate.minute,
      );
      _hasChanges = true;
    });
  }

  String _formatNumber(int n) {
    // 천 단위 콤마 포맷
    return n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}'
        ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ────────────────────────────── Windows 토스트 ──────────────────────────────

  void _sendToast(String message) {
    Process.run(
      'powershell',
      [
        '-ExecutionPolicy', 'Bypass',
        '-File', 'scripts/notify.ps1',
        '-title', '구술기록관리 에이전트',
        '-message', message,
      ],
      runInShell: false,
    ).catchError((_) => ProcessResult(0, 0, '', ''));
  }

  // ────────────────────────────── 문서 추출 ──────────────────────────────

  Future<void> _extractDocumentText(Record r) async {
    setState(() {
      _isExtracting = true;
      _extractionError = null;
    });

    try {
      final fileStorage = ref.read(fileStorageProvider);
      final bytes = await fileStorage.loadBytes(r.id);
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _isExtracting = false;
          _extractionError = '저장된 파일을 찾을 수 없습니다. 파일이 삭제되었거나 저장되지 않았을 수 있습니다.';
        });
        return;
      }

      final tmpDir = await getTemporaryDirectory();
      final ext = r.originalFileName?.split('.').last ?? 'pdf';
      final tmpFile = File('${tmpDir.path}/extract_${r.id}.$ext');
      await tmpFile.writeAsBytes(bytes, flush: true);

      final settings = ref.read(settingsProvider);
      final result = await DocumentExtractionService.extractText(
        filePath: tmpFile.path,
        pythonPath: settings.pythonPath,
      );

      try { await tmpFile.delete(); } catch (_) {}

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isExtracting = false;
          _extractionError = result.error ?? '텍스트 추출 실패';
        });
        return;
      }

      final repository = await ref.read(recordRepositoryProvider.future);
      final updated = r.copyWith(content: result.text);
      await repository.updateRecord(r.id, updated);
      ref.invalidate(recordDetailProvider(widget.recordId));

      if (!mounted) return;
      setState(() => _isExtracting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('텍스트 추출 완료!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _extractionError = '추출 오류: $e';
      });
    }
  }

  // ────────────────────────────── 통합 처리 헬퍼 ──────────────────────────

  IconData _processingIcon(Record r) {
    switch (RecordProcessingUtil.getProcessingType(r)) {
      case ProcessingType.transcribeVideo: return Icons.videocam;
      case ProcessingType.transcribeAudio: return Icons.record_voice_over;
      case ProcessingType.extractDocument: return Icons.text_snippet;
      case ProcessingType.none:            return Icons.settings;
    }
  }

  Future<void> _processRecord(Record r) async {
    switch (RecordProcessingUtil.getProcessingType(r)) {
      case ProcessingType.extractDocument:
        await _extractDocumentText(r);
      case ProcessingType.transcribeAudio:
        await _transcribeAudio(r);
      case ProcessingType.transcribeVideo:
        await _transcribeVideo(r);
      case ProcessingType.none:
        break;
    }
  }

  // ────────────────────────────── 영상 전사 ──────────────────────────────

  Future<void> _transcribeVideo(Record r) async {
    // 전사 전 안내 다이얼로그
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영상 음성 전사'),
        content: const Text(
          '영상에서 음성을 추출하고 전사합니다.\n'
          '파일 크기에 따라 수 분이 소요될 수 있습니다.\n'
          '전사 중에도 다른 기록을 조회할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('시작'),
          ),
        ],
      ),
    );
    if (!mounted || proceed != true) return;

    setState(() {
      _isTranscribing = true;
      _transcriptionLabel = '준비 중...';
      _transcriptionError = null;
    });

    try {
      final fileStorage = ref.read(fileStorageProvider);
      // getFilePath 사용: 대용량 영상 파일을 메모리에 올리지 않고 경로만 전달
      final videoPath = await fileStorage.getFilePath(r.id);
      if (videoPath == null) {
        setState(() {
          _isTranscribing = false;
          _transcriptionError = '저장된 영상 파일을 찾을 수 없습니다.';
        });
        return;
      }

      final settings = ref.read(settingsProvider);
      final result = await VideoTranscriptionService.transcribeVideo(
        videoPath: videoPath,
        pythonPath: settings.pythonPath,
        model: settings.whisperModel,
        language: settings.transcriptionLanguage,
        onProgress: (label) {
          if (mounted) setState(() => _transcriptionLabel = label);
        },
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isTranscribing = false;
          _transcriptionError = result.error ?? '전사 실패';
        });
        if (result.outOfMemory && mounted) {
          _showOOMDialog();
        }
        return;
      }

      final repository = await ref.read(recordRepositoryProvider.future);
      final updated = r.copyWith(content: result.text);
      await repository.updateRecord(r.id, updated);
      ref.invalidate(recordDetailProvider(widget.recordId));

      if (!mounted) return;
      setState(() => _isTranscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전사 완료! 요약 생성을 눌러보세요.'),
          duration: Duration(seconds: 4),
        ),
      );
      _sendToast('전사 완료! 요약 생성을 눌러보세요.');
    } catch (e) {
      if (!mounted) return;
      setState(() { _isTranscribing = false; _transcriptionError = '전사 오류: $e'; });
    }
  }

  // ────────────────────────────── 음성 전사 ──────────────────────────────

  Future<void> _transcribeAudio(Record r) async {
    setState(() {
      _isTranscribing = true;
      _transcriptionError = null;
    });

    try {
      // 저장된 파일 경로 직접 사용 (loadBytes 대신 getFilePath)
      final fileStorage = ref.read(fileStorageProvider);
      final audioPath = await fileStorage.getFilePath(r.id);
      if (audioPath == null) {
        setState(() {
          _isTranscribing = false;
          _transcriptionError = '저장된 음성 파일을 찾을 수 없습니다.\n파일이 삭제되었거나 저장되지 않았을 수 있습니다.';
        });
        return;
      }

      final settings = ref.read(settingsProvider);
      final result = await LocalTranscriptionService.transcribeFile(
        filePath: audioPath,
        pythonPath: settings.pythonPath,
        model: settings.whisperModel,
        language: settings.transcriptionLanguage,
      );

      if (!mounted) return;

      if (!result.success) {
        setState(() {
          _isTranscribing = false;
          _transcriptionError = result.error ?? '전사 실패';
        });
        if (result.outOfMemory && mounted) {
          _showOOMDialog();
        }
        return;
      }

      // 5. 레코드 content 업데이트
      final repository = await ref.read(recordRepositoryProvider.future);
      final updated = r.copyWith(content: result.text);
      await repository.updateRecord(r.id, updated);
      ref.invalidate(recordDetailProvider(widget.recordId));

      if (!mounted) return;
      setState(() => _isTranscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전사 완료! 텍스트가 저장되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranscribing = false;
        _transcriptionError = '전사 오류: $e';
      });
    }
  }

  // ────────────────────────────── 다운로드 ──────────────────────────────

  Future<void> _downloadFile(Record r) async {
    setState(() => _isDownloading = true);
    try {
      final fileStorage = ref.read(fileStorageProvider);
      final bytes = await fileStorage.loadBytes(r.id);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장된 파일을 찾을 수 없습니다')),
          );
        }
        return;
      }
      await _saveToDownloads(
        bytes: bytes,
        fileName: r.originalFileName ?? 'download',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _saveToDownloads({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장됨: ${file.path}')),
      );
    }
  }

  // ────────────────────────────── 마스킹 ──────────────────────────────

  Future<void> _performMasking(Record record) async {
    setState(() {
      _isMasking = true;
      _maskingError = null;
      _maskedPreview = null;
    });

    try {
      final piiItems = DetectPIITool.detectWithRegex(record.content);

      if (piiItems.isEmpty) {
        setState(() {
          _isMasking = false;
          _maskingError = '감지된 개인정보가 없습니다.';
        });
        return;
      }

      var masked = record.content;
      final sorted = [...piiItems]
        ..sort((a, b) => b.startIndex.compareTo(a.startIndex));

      for (final pii in sorted) {
        if (pii.startIndex >= 0 && pii.endIndex <= masked.length) {
          masked =
              '${masked.substring(0, pii.startIndex)}***${masked.substring(pii.endIndex)}';
        }
      }

      setState(() {
        _isMasking = false;
        _maskedPreview = masked;
      });
    } catch (e) {
      setState(() {
        _isMasking = false;
        _maskingError = '마스킹 처리 실패: $e';
      });
    }
  }

  Future<void> _saveMasking(Record record) async {
    if (_maskedPreview == null) return;
    setState(() => _isSavingMask = true);

    try {
      final repository = await ref.read(recordRepositoryProvider.future);
      final updated = record.copyWith(
        content: _maskedPreview,
        detectedPII: [],
      );
      await repository.updateRecord(record.id, updated);

      setState(() {
        _isSavingMask = false;
        _maskingSaved = true;
        _maskedPreview = null;
        _maskingError = null;
      });

      ref.invalidate(recordDetailProvider(widget.recordId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('마스킹이 적용되었습니다')),
        );
      }
    } catch (e) {
      setState(() {
        _isSavingMask = false;
        _maskingError = '저장 실패: $e';
      });
    }
  }

  // ────────────────────────────── 요약 생성 ──────────────────────────────

  Future<void> _generateSummary(Record record) async {
    // 미처리 상태면 먼저 처리 유도
    if (RecordProcessingUtil.needsProcessing(record)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('텍스트가 없습니다'),
          content: Text(
            '텍스트가 없습니다.\n먼저 "${RecordProcessingUtil.getButtonLabel(record)}"를 실행해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(RecordProcessingUtil.getButtonLabel(record)),
            ),
          ],
        ),
      );
      if (!mounted || proceed != true) return;
      await _processRecord(record);
      if (!mounted) return;
      final updated = await ref.read(recordDetailProvider(widget.recordId).future);
      if (!RecordProcessingUtil.needsProcessing(updated)) {
        await _generateSummary(updated);
      }
      return;
    }

    if (record.content.trim().isEmpty) {
      setState(() => _summaryError = '텍스트가 없습니다. 먼저 처리해주세요.');
      return;
    }

    setState(() {
      _isSummarizing = true;
      _summaryError = null;
    });

    try {
      final settingsApiKey = ref.read(settingsProvider).apiKey;

      // 내용이 너무 길면 3000자로 자름
      final content = record.content.length > _summaryContentMaxChars
          ? '${record.content.substring(0, _summaryContentMaxChars)}\n\n[내용이 길어 일부만 요약했습니다]'
          : record.content;

      final body = jsonEncode({
        'model': 'claude-haiku-4-5-20251001',
        'max_tokens': 1024,
        'messages': [
          {
            'role': 'user',
            'content': '다음 구술 기록을 3~5문장으로 간결하게 요약해주세요:\n\n$content',
          }
        ],
      });

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'content-type': 'application/json',
          'anthropic-version': '2023-06-01',
          if (settingsApiKey.isNotEmpty) 'x-api-key': settingsApiKey,
        },
        body: body,
      );

      if (response.statusCode != 200) {
        throw 'API 오류 (${response.statusCode}): ${response.body}';
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final summary = (data['content'] as List).first['text'] as String;
      final trimmed = summary.trim();

      setState(() => _isSummarizing = false);

      if (mounted) {
        await _showSummaryConfirmDialog(record, trimmed);
      }
    } catch (e) {
      setState(() {
        _isSummarizing = false;
        _summaryError = '요약 생성 실패: $e';
      });
    }
  }

  /// 요약 확인 다이얼로그: [다시 생성] / [저장하기]
  Future<void> _showSummaryConfirmDialog(
      Record record, String summaryText) async {
    final action = await showDialog<_SummaryAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('생성된 요약'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.maxFinite,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Text(summaryText),
              ),
              if (record.content.length > _summaryContentMaxChars) ...[
                const SizedBox(height: 8),
                const Text(
                  '* 내용이 길어 일부만 요약했습니다',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_SummaryAction.regenerate),
            child: const Text('다시 생성'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(_SummaryAction.save),
            child: const Text('저장하기'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (action == _SummaryAction.regenerate) {
      await _generateSummary(record);
    } else if (action == _SummaryAction.save) {
      await _saveSummary(record, summaryText);
    }
  }

  Future<void> _saveSummary(Record record, String summaryText) async {
    try {
      final repository = await ref.read(recordRepositoryProvider.future);
      final updated = record.copyWith(summary: summaryText);
      await repository.updateRecord(record.id, updated);

      ref.invalidate(recordDetailProvider(widget.recordId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('요약이 저장되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('요약 저장 실패: $e')),
        );
      }
    }
  }

  // ────────────────────────────── UI ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(recordDetailProvider(widget.recordId));
    final canEdit = ref.watch(authProvider).currentUser?.hasPermission(Permission.canEditRecord) ?? false;
    final canDelete = ref.watch(authProvider).currentUser?.hasPermission(Permission.canDeleteRecord) ?? false;

    if (_isEditing) {
      const saveColor = Color(0xFF185FA5);
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '뒤로',
            onPressed: _isSaving ? null : _cancelEdit,
          ),
          title: Row(
            children: [
              const Text('편집'),
              if (_hasChanges) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '수정 중',
                    style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 하단 고정 저장 버튼 바
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEdit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : (_hasChanges ? _saveEdits : null),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_isSaving ? '저장 중...' : '저장하기',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _hasChanges ? saveColor : Colors.grey[400],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const AppBottomNavBar(currentIndex: 2),
          ],
        ),
        body: _buildEditForm(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '뒤로',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/records');
            }
          },
        ),
        title: const Text('기록 상세'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: canEdit ? null : Colors.grey,
            ),
            tooltip: canEdit ? '편집' : '편집 (권한 없음)',
            onPressed: record.valueOrNull == null
                ? null
                : canEdit
                    ? () => _enterEditMode(record.value!)
                    : () => showNoPermissionSnackBar(context, Permission.canEditRecord),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('공유'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: canDelete ? Colors.red : Colors.grey,
                  ),
                  title: Text(
                    '삭제',
                    style: TextStyle(color: canDelete ? Colors.red : Colors.grey),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'share') {
                _showShareDialog(context, record.valueOrNull);
              } else if (value == 'delete') {
                if (canDelete) {
                  _showDeleteDialog(context);
                } else {
                  showNoPermissionSnackBar(context, Permission.canDeleteRecord);
                }
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNavBar(currentIndex: 2),
      body: record.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        data: (r) => _buildBody(context, r),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('기록 로드 실패'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.refresh(recordDetailProvider(widget.recordId)),
                child: const Text('재시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── 편집 폼 UI ──────────────────────────────

  static const _mainCategories = ['정치사건', '경제정책', '문화콘텐츠', '개인사', '사회운동', '기타'];

  Widget _buildEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 기본 정보 ──────────────────────────────────────────
          _editSectionLabel('기본 정보'),
          TextField(
            controller: _editTitleCtrl,
            decoration: const InputDecoration(
              labelText: '제목',
              border: OutlineInputBorder(),
            ),
            maxLength: 200,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _editMainCategory,
            decoration: const InputDecoration(
              labelText: '주제 대분류',
              border: OutlineInputBorder(),
            ),
            items: _mainCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() { _editMainCategory = v!; _hasChanges = true; }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _editSubCatCtrl,
            decoration: const InputDecoration(
              labelText: '주제 소분류',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          // 키워드 태그
          Text('키워드 태그', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700])),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ..._editKeywords.map((tag) => InputChip(
                label: Text(tag),
                onDeleted: () => setState(() { _editKeywords.remove(tag); _hasChanges = true; }),
              )),
              SizedBox(
                width: 140,
                height: 36,
                child: TextField(
                  controller: _editKeywordInputCtrl,
                  decoration: const InputDecoration(
                    hintText: '태그 입력 후 Enter',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: (v) {
                    final tag = v.trim();
                    if (tag.isNotEmpty && !_editKeywords.contains(tag) && _editKeywords.length < 20) {
                      setState(() { _editKeywords.add(tag); _hasChanges = true; });
                      _editKeywordInputCtrl!.clear();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            title: const Text('비공개'),
            value: _editVisibility == 'private',
            onChanged: (v) => setState(() { _editVisibility = v ? 'private' : 'public'; _hasChanges = true; }),
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(height: 32),

          // ── 면담 정보 ──────────────────────────────────────────
          _editSectionLabel('면담 정보'),
          _editPersonTile(
            label: '구술자',
            name: _editNarrator?.name,
            onTap: () => _pickPerson(isNarrator: true),
          ),
          const SizedBox(height: 8),
          _editPersonTile(
            label: '면담자',
            name: _editInterviewer?.name,
            onTap: () => _pickPerson(isNarrator: false),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '면담 일시',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(_formatDateTime(_editInterviewDate)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _editLocationCtrl,
            decoration: const InputDecoration(
              labelText: '면담 장소',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _editSessionNoCtrl,
            decoration: const InputDecoration(
              labelText: '면담 회차',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _editInterviewType,
            decoration: const InputDecoration(
              labelText: '면담 유형',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'oral', child: Text('구술')),
              DropdownMenuItem(value: 'written', child: Text('서면')),
              DropdownMenuItem(value: 'phone', child: Text('전화')),
            ],
            onChanged: (v) => setState(() { _editInterviewType = v!; _hasChanges = true; }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _editLanguage,
            decoration: const InputDecoration(
              labelText: '사용 언어',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'ko', child: Text('한국어')),
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ja', child: Text('日本語')),
              DropdownMenuItem(value: 'zh', child: Text('中文')),
            ],
            onChanged: (v) => setState(() { _editLanguage = v!; _hasChanges = true; }),
          ),
          const Divider(height: 32),

          // ── 전사 내용 ──────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _editSectionLabel('전사 내용')),
              // 도구 버튼
              IconButton(
                icon: const Icon(Icons.select_all, size: 20),
                tooltip: '전체 선택',
                onPressed: () {
                  _editContentCtrl!.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _editContentCtrl!.text.length,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 20),
                tooltip: '복사',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _editContentCtrl!.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('전사 내용이 복사되었습니다'), duration: Duration(seconds: 1)),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.find_replace, size: 20),
                tooltip: '찾기/바꾸기',
                onPressed: _showFindReplaceDialog,
              ),
            ],
          ),
          TextField(
            controller: _editContentCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              hintText: '전사 내용을 입력하세요',
            ),
            minLines: 8,
            maxLines: null,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 6),
          // 글자수 + 원본 복원
          Row(
            children: [
              Text(
                '글자수: ${_editContentCtrl != null ? _formatNumber(_editContentCtrl!.text.length) : 0}자',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              if (_editContentCtrl?.text != _originalContent)
                TextButton.icon(
                  onPressed: _restoreOriginalContent,
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('원본 복원', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orange[700],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const Divider(height: 32),

          // ── 기록 정보 ──────────────────────────────────────────
          _editSectionLabel('기록 정보'),
          TextField(
            controller: _editNotesCtrl,
            decoration: const InputDecoration(
              labelText: '메모/특이사항',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _editSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _editPersonTile({required String label, required String? name, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.person_search, size: 18),
        ),
        child: Text(
          name ?? '선택 안 됨',
          style: name == null ? TextStyle(color: Colors.grey[500]) : null,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context, Record r) {
    final showPiiWarning = r.detectedPII.isNotEmpty && !_maskingSaved;
    final hasFile = r.originalFileName != null;
    final contentExceedsLimit = r.content.length > _contentPreviewLimit;
    final displayContent = (!_showFullContent && contentExceedsLimit)
        ? r.content.substring(0, _contentPreviewLimit)
        : r.content;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // displayId + 제목
          if (r.displayId != null)
            Row(
              children: [
                Text(
                  r.displayId!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.blueGrey[500],
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: r.displayId!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('식별자가 클립보드에 복사되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(Icons.copy, size: 14, color: Colors.blueGrey[400]),
                ),
              ],
            ),
          if (r.displayId != null) const SizedBox(height: 4),
          Text(r.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),

          // 메타데이터 박스
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetadataRow('주제', r.mainCategory),
                _MetadataRow('비공개', r.visibility == 'private' ? '예' : '아니오'),
                _MetadataRow(
                  '작성일',
                  '${r.createdAt.year}-'
                      '${r.createdAt.month.toString().padLeft(2, '0')}-'
                      '${r.createdAt.day.toString().padLeft(2, '0')}',
                ),
                if (hasFile) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('파일',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.originalFileName!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (r.fileSize != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          _formatSize(r.fileSize!),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isDownloading ? null : () => _downloadFile(r),
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.download, size: 14),
                          label: const Text('다운로드',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 키워드 태그
          if (r.keywordTags.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF185FA5).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('키워드',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in r.keywordTags) Chip(label: Text(tag)),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // PII 경고 박스
          if (showPiiWarning) ...[
            _buildPIIWarningBox(r),
            const SizedBox(height: 24),
          ],

          // 콘텐츠 미리보기
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF185FA5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('콘텐츠',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          if (RecordProcessingUtil.needsProcessing(r)) ...[
            // 미처리 상태 플레이스홀더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(_processingIcon(r), size: 18, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '텍스트 미처리 상태입니다. 아래 버튼으로 처리해주세요.',
                      style: TextStyle(color: Colors.amber[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isBusy ? null : () => _processRecord(r),
                icon: (_isExtracting || _isTranscribing)
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_processingIcon(r)),
                label: Text(_isExtracting
                    ? '추출 중...'
                    : _isTranscribing
                        ? _transcriptionLabel
                        : RecordProcessingUtil.getButtonLabel(r)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_extractionError != null || _transcriptionError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Text(
                  _extractionError ?? _transcriptionError!,
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
            ],
          ] else ...[
            Text(
              displayContent,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(height: 1.6, fontSize: 14),
            ),
            if (contentExceedsLimit) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () =>
                    setState(() => _showFullContent = !_showFullContent),
                child:
                    Text(_showFullContent ? '접기' : '더 보기 (${r.content.length}자)'),
              ),
            ],
          ],

          // 마스킹 미리보기
          if (_maskedPreview != null) ...[
            const SizedBox(height: 16),
            _buildMaskingPreview(r),
          ],

          // 마스킹 에러
          if (_maskingError != null) ...[
            const SizedBox(height: 8),
            Text(
              _maskingError!,
              style: const TextStyle(color: Colors.orange),
            ),
          ],

          const SizedBox(height: 24),

          // 요약 섹션
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF185FA5).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('요약',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),

          // 저장된 요약
          if (r.summary != null && r.summary!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF90CAF9)),
              ),
              child: Text(
                r.summary!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(height: 1.6, fontSize: 14),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 요약 생성 / 재생성 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : () => _generateSummary(r),
              icon: _isSummarizing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.summarize),
              label: Text(_isSummarizing
                  ? '요약 생성 중...'
                  : (r.summary != null ? '요약 재생성' : '요약 생성')),
            ),
          ),

          // 요약 에러
          if (_summaryError != null) ...[
            const SizedBox(height: 8),
            Text(
              _summaryError!,
              style: const TextStyle(color: Colors.red),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // PII 경고 + 마스킹 버튼
  Widget _buildPIIWarningBox(Record r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 8),
              Text(
                'PII 정보 감지됨',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('이 기록에는 개인식별정보 ${r.detectedPII.length}건이 포함되어 있습니다.'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : () => _performMasking(r),
              icon: _isMasking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.security),
              label: Text(_isMasking ? '마스킹 처리 중...' : '마스킹'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 마스킹 미리보기 + 저장 버튼
  Widget _buildMaskingPreview(Record r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '마스킹 미리보기',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _maskedPreview!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBusy ? null : () => _saveMasking(r),
              icon: _isSavingMask
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('마스킹 저장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, Record? r) {
    if (r == null) return;
    final text = '제목: ${r.title}\n주제: ${r.mainCategory}\n\n${r.content}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공유'),
        content: SingleChildScrollView(
          child: SelectableText(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('이 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final fileStorage = ref.read(fileStorageProvider);
              await fileStorage.deleteFile(widget.recordId);
              ref
                  .read(recordFormProvider.notifier)
                  .deleteRecord(widget.recordId);
              if (context.mounted) {
                context.pop();
                context.go('/records');
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

enum _SummaryAction { regenerate, save }

class _MetadataRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetadataRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
