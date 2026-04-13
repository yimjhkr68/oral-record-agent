import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/ontology_api.dart';
import '../../api/record_api.dart';
import '../../models/ontology.dart';
import '../../models/oral_record.dart';
import '../../models/triple.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';

// ── 파일 업로드 결과 모델 ─────────────────────────────────────────────────────
class _ExtractedFile {
  final String filename;
  final String? text;
  final String? error;
  bool added = false;

  _ExtractedFile({required this.filename, this.text, this.error});

  bool get isOk => text != null && error == null;
}

class TripleStep1Extract extends ConsumerStatefulWidget {
  const TripleStep1Extract({super.key});

  @override
  ConsumerState<TripleStep1Extract> createState() => _TripleStep1ExtractState();
}

class _TripleStep1ExtractState extends ConsumerState<TripleStep1Extract>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // 텍스트 입력 탭
  final _textCtrl   = TextEditingController();
  final _sourceCtrl = TextEditingController();

  // 파일 업로드 탭
  List<_ExtractedFile> _extractedFiles = [];
  bool _fileExtracting = false;
  int  _fileProgress   = 0;
  int  _fileTotal      = 0;

  // 저장된 기록 탭
  List<OralRecord> _storedRecords = [];
  bool  _recordsLoading = false;
  String _recordsQuery  = '';
  final Set<String> _selectedRecordIds = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 2 && _storedRecords.isEmpty) {
        _loadStoredRecords('');
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    _sourceCtrl.dispose();
    super.dispose();
  }

  // ── 텍스트 탭 ────────────────────────────────────────────────────────────────
  void _addTextRecord() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final id = _sourceCtrl.text.trim().isEmpty
        ? '구술기록-${DateTime.now().millisecondsSinceEpoch ~/ 1000}'
        : _sourceCtrl.text.trim();
    ref.read(tripleWorkProvider.notifier)
        .addSourceRecord(SourceRecord(id: id, content: text));
    _textCtrl.clear();
    _sourceCtrl.clear();
  }

  // ── 파일 탭 ──────────────────────────────────────────────────────────────────
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'docx'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    final files = result.files.where((f) => f.path != null).toList();
    if (files.isEmpty) return;

    setState(() {
      _fileExtracting = true;
      _fileTotal      = files.length;
      _fileProgress   = 0;
      _extractedFiles = [];
    });

    final api = OntologyApi(ref.read(apiClientProvider));

    for (int i = 0; i < files.length; i++) {
      final file = files[i];
      setState(() => _fileProgress = i + 1);
      try {
        final res = await api.extractTextFromFile(file.path!, file.name);
        setState(() {
          _extractedFiles.add(_ExtractedFile(
              filename: file.name, text: res['text'] as String?));
        });
      } catch (e) {
        setState(() {
          _extractedFiles.add(_ExtractedFile(
              filename: file.name, error: e.toString()));
        });
      }
    }
    setState(() => _fileExtracting = false);
  }

  void _addFileRecord(_ExtractedFile ef) {
    if (!ef.isOk) return;
    ref.read(tripleWorkProvider.notifier)
        .addSourceRecord(SourceRecord(id: ef.filename, content: ef.text!));
    setState(() => ef.added = true);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('"${ef.filename}" 추가됨')));
  }

  void _addAllFileRecords() {
    final pending = _extractedFiles.where((f) => f.isOk && !f.added).toList();
    for (final ef in pending) {
      ref.read(tripleWorkProvider.notifier)
          .addSourceRecord(SourceRecord(id: ef.filename, content: ef.text!));
      ef.added = true;
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${pending.length}개 파일 추가됨')));
  }

  // ── 저장된 기록 탭 ────────────────────────────────────────────────────────────
  Future<void> _loadStoredRecords(String q) async {
    setState(() {
      _recordsLoading = true;
      _recordsQuery   = q;
    });
    try {
      final records = await RecordApi(ref.read(apiClientProvider))
          .list(q: q, limit: 100);
      setState(() {
        _storedRecords  = records;
        _recordsLoading = false;
      });
    } catch (e) {
      setState(() => _recordsLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('기록 로드 실패: $e'),
                backgroundColor: Colors.red));
      }
    }
  }

  void _addSelectedRecords() {
    final selected =
        _storedRecords.where((r) => _selectedRecordIds.contains(r.id));
    for (final r in selected) {
      ref.read(tripleWorkProvider.notifier).addSourceRecord(
            SourceRecord(
                id: r.id,
                content: r.contentPreview ?? r.content ?? ''),
          );
    }
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedRecordIds.length}개 기록 추가됨')));
    setState(() => _selectedRecordIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(tripleWorkProvider);
    final versions  = ref.watch(ontologyProvider).versions;
    // confirmed + draft 허용 (archived는 추출 불가이므로 제외)
    final available = versions
        .where((v) =>
            v.status == OntologyStatus.confirmed ||
            v.status == OntologyStatus.draft)
        .toList();
    final confirmed = versions
        .where((v) => v.status == OntologyStatus.confirmed)
        .toList();

    // 선택된 versionId가 available 목록에 없으면 null로 표시 (assertion 방지)
    final safeValue = available.any((v) => v.versionId == state.selectedVersionId)
        ? state.selectedVersionId
        : null;
    return Column(
      children: [
        // ── 온톨로지 선택 + 선택된 레코드 요약 ────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('1. 온톨로지 버전'),
              const SizedBox(height: 6),
              if (available.isEmpty)
                _WarningBox('Confirmed 온톨로지가 없습니다. 온톨로지 탭에서 먼저 확정해 주세요.')
              else
                InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButton<String>(
                    value: safeValue,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('버전 선택'),
                    items: available
                        .map((v) {
                          final isDraft = v.status == OntologyStatus.draft;
                          return DropdownMenuItem(
                            value: v.versionId,
                            child: Text(
                              isDraft ? '${v.versionId} (Draft)' : v.versionId,
                              style: TextStyle(
                                  color: isDraft ? Colors.orange.shade700 : null),
                            ),
                          );
                        })
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(tripleWorkProvider.notifier).setVersion(v);
                      }
                    },
                  ),
                ),
              // confirmed 온톨로지가 없고 draft만 있을 때
              if (confirmed.isEmpty && available.isNotEmpty) ...[
                const SizedBox(height: 6),
                const _WarningBox('Confirmed 온톨로지가 없습니다. Draft 버전으로 생성은 가능하지만 확정을 권장합니다.'),
              ],
              const SizedBox(height: 10),
              if (state.sourceRecords.isNotEmpty)
                _RecordsSummary(
                  records: state.sourceRecords,
                  onRemove: (i) => ref
                      .read(tripleWorkProvider.notifier)
                      .removeSourceRecord(i),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        const Divider(height: 1),

        // ── 입력 탭바 ─────────────────────────────────────────────────────
        TabBar(
          controller: _tabCtrl,
          labelStyle: const TextStyle(fontSize: 13),
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
                sourceCtrl: _sourceCtrl,
                onAdd: _addTextRecord,
              ),
              _FileTab(
                extractedFiles: _extractedFiles,
                extracting: _fileExtracting,
                fileProgress: _fileProgress,
                fileTotal: _fileTotal,
                onPickFiles: _pickFiles,
                onAddFile: _addFileRecord,
                onAddAll: _extractedFiles.any((f) => f.isOk && !f.added)
                    ? _addAllFileRecords
                    : null,
              ),
              _StoredRecordsTab(
                records: _storedRecords,
                loading: _recordsLoading,
                selectedIds: _selectedRecordIds,
                onRefresh: () => _loadStoredRecords(_recordsQuery),
                onSearch: (q) => _loadStoredRecords(q),
                onToggleSelect: (id) => setState(() =>
                    _selectedRecordIds.contains(id)
                        ? _selectedRecordIds.remove(id)
                        : _selectedRecordIds.add(id)),
                onAddSelected:
                    _selectedRecordIds.isNotEmpty ? _addSelectedRecords : null,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── 하단: 트리플 생성 버튼 ────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              if (state.isExtracting) ...[
                Row(children: [
                  Expanded(
                    child: Text(
                      '처리 중 (${state.extractProgress + 1}/'
                      '${state.extractTotal}): ${state.extractStatus}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: state.extractTotal > 0
                      ? state.extractProgress / state.extractTotal
                      : null,
                ),
                const SizedBox(height: 4),
                const Text('AI 분석 중... (레코드당 최대 2분)',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 8),
              ],
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ErrorBox(state.error!),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: state.isExtracting
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(state.isExtracting
                      ? 'AI 추출 중...'
                      : '트리플 생성'
                          '${state.sourceRecords.isEmpty ? "" : " (${state.sourceRecords.length}개 레코드)"}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: state.canExtract
                      ? () => ref.read(tripleWorkProvider.notifier).extractAll()
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── 텍스트 입력 탭 ─────────────────────────────────────────────────────────────

const int _kMaxChars  = 8000;
const int _kWarnChars = 6000;

class _TextTab extends StatefulWidget {
  final TextEditingController textCtrl;
  final TextEditingController sourceCtrl;
  final VoidCallback onAdd;
  const _TextTab({
    required this.textCtrl,
    required this.sourceCtrl,
    required this.onAdd,
  });

  @override
  State<_TextTab> createState() => _TextTabState();
}

class _TextTabState extends State<_TextTab> {
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _charCount = widget.textCtrl.text.length;
    widget.textCtrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final len = widget.textCtrl.text.length;
    if (len != _charCount) setState(() => _charCount = len);
  }

  @override
  void dispose() {
    widget.textCtrl.removeListener(_onTextChanged);
    super.dispose();
  }

  Color get _borderColor {
    if (_charCount > _kMaxChars) return Colors.red;
    if (_charCount > _kWarnChars) return Colors.orange;
    return Colors.grey.shade400;
  }

  @override
  Widget build(BuildContext context) {
    final isOver = _charCount > _kMaxChars;
    final isWarn = !isOver && _charCount > _kWarnChars;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.sourceCtrl,
            decoration: const InputDecoration(
              labelText: '레코드 ID (비워두면 자동 생성)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),

          // 안내 박스
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '권장: 3,000자 이하  ·  최대: 8,000자\n'
                  '너무 긴 텍스트는 AI가 중요 내용을 놓칠 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          // 텍스트 입력
          TextField(
            controller: widget.textCtrl,
            maxLines: 7,
            decoration: InputDecoration(
              labelText: '구술 텍스트 붙여넣기',
              alignLabelWithHint: true,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _borderColor,
                    width: (isOver || isWarn) ? 1.5 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                    color: _borderColor,
                    width: (isOver || isWarn) ? 1.8 : 1.5),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 글자 수 카운터 + 경고
          Row(
            children: [
              Text(
                '$_charCount / $_kMaxChars 자',
                style: TextStyle(
                  fontSize: 12,
                  color: isOver
                      ? Colors.red
                      : isWarn
                          ? Colors.orange
                          : Colors.grey.shade600,
                  fontWeight: (isOver || isWarn)
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              if (isOver) ...[
                const SizedBox(width: 8),
                const Icon(Icons.warning_amber, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '최대 길이 초과 — 8,000자까지만 AI에 전달됩니다',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (isWarn) ...[
                const SizedBox(width: 8),
                const Icon(Icons.info_outline,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    '긴 텍스트 — AI 분석 품질이 저하될 수 있습니다',
                    style: TextStyle(fontSize: 11, color: Colors.orange),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('목록에 추가'),
              onPressed: widget.onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 파일 업로드 탭 ────────────────────────────────────────────────────────────

class _FileTab extends StatelessWidget {
  final List<_ExtractedFile> extractedFiles;
  final bool extracting;
  final int fileProgress;
  final int fileTotal;
  final VoidCallback onPickFiles;
  final ValueChanged<_ExtractedFile> onAddFile;
  final VoidCallback? onAddAll;

  const _FileTab({
    required this.extractedFiles,
    required this.extracting,
    required this.fileProgress,
    required this.fileTotal,
    required this.onPickFiles,
    required this.onAddFile,
    required this.onAddAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('파일 선택 (복수 가능)'),
              onPressed: extracting ? null : onPickFiles,
            ),
            const SizedBox(width: 8),
            const Text('txt / pdf / docx',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 10),

          if (extracting) ...[
            Row(children: [
              const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('텍스트 추출 중 ($fileProgress / $fileTotal)...',
                  style: const TextStyle(fontSize: 13)),
            ]),
            const SizedBox(height: 6),
            LinearProgressIndicator(
                value: fileTotal > 0 ? fileProgress / fileTotal : null),
            const SizedBox(height: 10),
          ],

          if (extractedFiles.isNotEmpty) ...[
            if (onAddAll != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: Text(
                      '미추가 파일 전체 추가 '
                      '(${extractedFiles.where((f) => f.isOk && !f.added).length}개)',
                    ),
                    onPressed: onAddAll,
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: extractedFiles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final ef = extractedFiles[i];
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ef.added
                            ? Colors.green.shade300
                            : ef.isOk
                                ? Colors.grey.shade300
                                : Colors.red.shade300,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: ef.added
                          ? Colors.green.shade50
                          : ef.isOk
                              ? null
                              : Colors.red.shade50,
                    ),
                    child: Row(children: [
                      Icon(
                        ef.added
                            ? Icons.check_circle
                            : ef.isOk
                                ? Icons.description_outlined
                                : Icons.error_outline,
                        size: 16,
                        color: ef.added
                            ? Colors.green
                            : ef.isOk
                                ? Colors.grey
                                : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ef.filename,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            if (ef.isOk) ...[
                              Text(
                                '${ef.text!.length}자 추출됨',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ef.text!.length > _kMaxChars
                                      ? Colors.red
                                      : ef.text!.length > _kWarnChars
                                          ? Colors.orange
                                          : Colors.grey,
                                  fontWeight: ef.text!.length > _kWarnChars
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (ef.text!.length > _kMaxChars)
                                const Text(
                                  '최대 길이 초과 — 8,000자까지만 AI에 전달됩니다',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.red),
                                )
                              else if (ef.text!.length > _kWarnChars)
                                const Text(
                                  '긴 텍스트 — AI 품질이 저하될 수 있습니다',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.orange),
                                ),
                            ] else if (ef.error != null)
                              Text('오류: ${ef.error}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.red)),
                          ],
                        ),
                      ),
                      if (ef.isOk && !ef.added)
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('추가',
                              style: TextStyle(fontSize: 12)),
                          onPressed: () => onAddFile(ef),
                        )
                      else if (ef.added)
                        const Text('추가됨',
                            style: TextStyle(
                                fontSize: 11, color: Colors.green)),
                    ]),
                  );
                },
              ),
            ),
          ] else if (!extracting)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined,
                        size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('파일을 선택하면 텍스트를 자동 추출합니다.',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('txt / pdf / docx 복수 선택 가능',
                        style: TextStyle(
                            color: Colors.grey, fontSize: 11)),
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
  final Set<String> selectedIds;
  final VoidCallback onRefresh;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback? onAddSelected;

  const _StoredRecordsTab({
    required this.records,
    required this.loading,
    required this.selectedIds,
    required this.onRefresh,
    required this.onSearch,
    required this.onToggleSelect,
    required this.onAddSelected,
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
          // 검색 + 새로고침
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

          // 선택 추가 버튼
          if (widget.selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: Text('선택 ${widget.selectedIds.length}개 추가'),
                  onPressed: widget.onAddSelected,
                ),
              ),
            ),

          // 목록
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
                  final isSelected = widget.selectedIds.contains(r.id);
                  return InkWell(
                    onTap: () => widget.onToggleSelect(r.id),
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
                                        fontSize: 11, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(r.dateLabel,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                            Text('${r.charCount}자',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ],
                        ),
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

// ── 선택된 레코드 요약 ────────────────────────────────────────────────────────

class _RecordsSummary extends StatelessWidget {
  final List<SourceRecord> records;
  final ValueChanged<int> onRemove;
  const _RecordsSummary({required this.records, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '선택된 구술기록 (${records.length}개)',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 5),
            itemBuilder: (_, i) => _RecordCard(
              record: records[i],
              onRemove: () => onRemove(i),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final SourceRecord record;
  final VoidCallback onRemove;
  const _RecordCard({required this.record, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final preview = record.content.isEmpty
        ? '(내용 없음)'
        : record.content.length > 120
            ? '${record.content.replaceAll('\n', ' ').substring(0, 120)}…'
            : record.content.replaceAll('\n', ' ');

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.04),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.description_outlined,
                size: 14, color: Colors.grey),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.id,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(preview,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 24, minHeight: 24),
            tooltip: '제거',
          ),
        ],
      ),
    );
  }
}

// ── 보조 위젯 ─────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Theme.of(context).colorScheme.primary));
}

class _WarningBox extends StatelessWidget {
  final String message;
  const _WarningBox(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined,
              color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(fontSize: 12))),
        ]),
      );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.red, fontSize: 12))),
        ]),
      );
}
