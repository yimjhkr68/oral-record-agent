import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_client.dart';
import '../../api/ontology_api.dart';
import '../../models/ontology.dart';
import '../../models/triple.dart';
import '../../providers/hive_provider.dart';
import '../../providers/ontology_provider.dart';
import '../../providers/triple_provider.dart';

// ── 파일 업로드 결과 모델 ─────────────────────────────────────────────────────
class _ExtractedFile {
  final String filename;
  final String? text;
  final String? error;
  bool added = false;

  _ExtractedFile({
    required this.filename,
    this.text,
    this.error,
  });

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

  // 파일 업로드 탭 — 복수 파일 지원
  List<_ExtractedFile> _extractedFiles = [];
  bool _fileExtracting = false;
  int  _fileProgress   = 0;   // 현재 처리 중인 파일 번호 (1-based)
  int  _fileTotal      = 0;

  // Hive DB 탭
  final _hiveUrlCtrl   = TextEditingController();
  final _hiveQueryCtrl = TextEditingController();
  bool? _hiveConnected;           // null=미확인, true=연결됨, false=실패
  bool  _hiveSearching  = false;
  String? _hiveAnswer;            // v3.0 AI 답변
  List<HiveRecord> _hiveResults  = [];
  final Set<String> _selectedHiveIds = {};

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _hiveUrlCtrl.text = ref.read(hiveUrlProvider);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    _sourceCtrl.dispose();
    _hiveUrlCtrl.dispose();
    _hiveQueryCtrl.dispose();
    super.dispose();
  }

  // ── 텍스트 탭: 목록에 추가 ────────────────────────────────────────────────────
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

  // ── 파일 탭: 복수 파일 선택 + 텍스트 추출 ─────────────────────────────────────
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
            filename: file.name,
            text: res['text'] as String?,
          ));
        });
      } catch (e) {
        setState(() {
          _extractedFiles.add(_ExtractedFile(
            filename: file.name,
            error: e.toString(),
          ));
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${ef.filename}" 추가됨')),
    );
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
      SnackBar(content: Text('${pending.length}개 파일 추가됨')),
    );
  }

  // ── Hive DB 탭: 연결 확인 ────────────────────────────────────────────────────
  Future<bool> _ensureConnected() async {
    final url = _hiveUrlCtrl.text.trim();
    ref.read(hiveUrlProvider.notifier).state = url;
    await saveHiveUrl(url);
    final ok = await HiveApi(url).checkConnection();
    setState(() => _hiveConnected = ok);
    return ok;
  }

  Future<void> _checkHiveConnection() async {
    setState(() => _hiveSearching = true);
    await _ensureConnected();
    setState(() => _hiveSearching = false);
  }

  // ── Hive DB 탭: 검색 (연결 확인 자동 포함) ──────────────────────────────────
  Future<void> _searchHive() async {
    if (_hiveQueryCtrl.text.trim().isEmpty) return;
    setState(() {
      _hiveSearching = true;
      _hiveAnswer    = null;
    });

    // 미확인 상태면 연결 먼저 확인
    if (_hiveConnected != true) {
      final ok = await _ensureConnected();
      if (!ok) {
        setState(() => _hiveSearching = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hive 서버에 연결할 수 없습니다. 서버 주소를 확인해주세요.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    try {
      final url    = _hiveUrlCtrl.text.trim();
      final result = await HiveApi(url)
          .query(_hiveQueryCtrl.text.trim(), topK: 5);
      setState(() {
        _hiveAnswer    = result.answer;
        _hiveResults   = result.sources;
        _hiveSearching = false;
        _selectedHiveIds.clear();
      });
    } catch (e) {
      setState(() => _hiveSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 실패: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Hive DB 탭: 선택 레코드 추가 ─────────────────────────────────────────────
  void _addHiveRecords() {
    final selected =
        _hiveResults.where((r) => _selectedHiveIds.contains(r.displayId));
    for (final r in selected) {
      ref.read(tripleWorkProvider.notifier).addSourceRecord(
            SourceRecord(id: r.displayId, content: r.text),
          );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_selectedHiveIds.length}개 레코드 추가됨')),
    );
    setState(() => _selectedHiveIds.clear());
  }

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(tripleWorkProvider);
    final versions  = ref.watch(ontologyProvider).versions;
    final confirmed = versions
        .where((v) => v.status == OntologyStatus.confirmed)
        .toList();

    return Column(
      children: [
        // ── 온톨로지 선택 + 선택된 레코드 요약 ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('1. 온톨로지 버전 (Confirmed)'),
              const SizedBox(height: 6),
              if (confirmed.isEmpty)
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
                    value: state.selectedVersionId,
                    isExpanded: true,
                    underline: const SizedBox(),
                    hint: const Text('버전 선택'),
                    items: confirmed
                        .map((v) => DropdownMenuItem(
                              value: v.versionId,
                              child: Text(v.versionId),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(tripleWorkProvider.notifier).setVersion(v);
                      }
                    },
                  ),
                ),
              const SizedBox(height: 10),
              // 선택된 레코드 요약
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
            Tab(text: 'Hive DB'),
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
              _HiveTab(
                urlCtrl: _hiveUrlCtrl,
                queryCtrl: _hiveQueryCtrl,
                connected: _hiveConnected,
                searching: _hiveSearching,
                answer: _hiveAnswer,
                results: _hiveResults,
                selectedIds: _selectedHiveIds,
                onCheckConnection: _checkHiveConnection,
                onSearch: _searchHive,
                onToggleSelect: (id) =>
                    setState(() => _selectedHiveIds.contains(id)
                        ? _selectedHiveIds.remove(id)
                        : _selectedHiveIds.add(id)),
                onAddSelected:
                    _selectedHiveIds.isNotEmpty ? _addHiveRecords : null,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // ── 하단: 진행 상황 + 트리플 생성 버튼 ───────────────────────────
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
                const Text(
                  'AI 분석 중... (레코드당 최대 2분)',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
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
                      ? () =>
                          ref.read(tripleWorkProvider.notifier).extractAll()
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

class _TextTab extends StatelessWidget {
  final TextEditingController textCtrl;
  final TextEditingController sourceCtrl;
  final VoidCallback onAdd;
  const _TextTab({
    required this.textCtrl,
    required this.sourceCtrl,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: sourceCtrl,
            decoration: const InputDecoration(
              labelText: '레코드 ID (비워두면 자동 생성)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: textCtrl,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: '구술 텍스트 붙여넣기',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('목록에 추가'),
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 파일 업로드 탭 (복수 파일 지원) ──────────────────────────────────────────

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

          // 진행 상황
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
              value: fileTotal > 0 ? fileProgress / fileTotal : null,
            ),
            const SizedBox(height: 10),
          ],

          // 추출 결과 목록
          if (extractedFiles.isNotEmpty) ...[
            // 전체 추가 버튼
            if (onAddAll != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: Text(
                      '미추가 파일 전체 추가 (${extractedFiles.where((f) => f.isOk && !f.added).length}개)',
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
                                    fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            if (ef.isOk)
                              Text('${ef.text!.length}자 추출됨',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey))
                            else if (ef.error != null)
                              Text('오류: ${ef.error}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.red)),
                          ],
                        ),
                      ),
                      if (ef.isOk && !ef.added)
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('추가', style: TextStyle(fontSize: 12)),
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
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    SizedBox(height: 4),
                    Text('txt / pdf / docx 복수 선택 가능',
                        style: TextStyle(color: Colors.grey, fontSize: 11)),
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
  final bool? connected;       // null=미확인, true=연결됨, false=실패
  final bool searching;
  final String? answer;        // v3.0 AI 답변
  final List<HiveRecord> results;
  final Set<String> selectedIds;
  final VoidCallback onCheckConnection;
  final VoidCallback onSearch;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback? onAddSelected;

  const _HiveTab({
    required this.urlCtrl,
    required this.queryCtrl,
    required this.connected,
    required this.searching,
    required this.answer,
    required this.results,
    required this.selectedIds,
    required this.onCheckConnection,
    required this.onSearch,
    required this.onToggleSelect,
    required this.onAddSelected,
  });

  @override
  Widget build(BuildContext context) {
    final connColor = connected == null
        ? Colors.grey
        : connected!
            ? Colors.green
            : Colors.red;
    final connIcon  = connected == null
        ? Icons.help_outline
        : connected!
            ? Icons.check_circle
            : Icons.error_outline;
    final connLabel = connected == null
        ? '미확인 (검색 시 자동 연결 시도)'
        : connected!
            ? '연결됨'
            : '연결 실패';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 서버 URL
          const Text('v3.0 Hive 서버 주소',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                  hintText: 'http://192.168.0.x:9000',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => onCheckConnection(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: searching ? null : onCheckConnection,
              child: const Text('연결 확인'),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(connIcon, size: 13, color: connColor),
            const SizedBox(width: 4),
            Text(connLabel,
                style: TextStyle(fontSize: 12, color: connColor)),
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
                onSubmitted: (_) => searching ? null : onSearch(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: searching ? null : onSearch,
              child: const Text('검색'),
            ),
          ]),
          const SizedBox(height: 10),

          // 결과
          if (searching)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text('Hive DB 검색 중... (AI 답변 생성 포함, 최대 60초)',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            )
          else if (results.isEmpty)
            const Expanded(
              child: Center(
                child: Text('검색 결과가 여기에 표시됩니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI 답변 (있을 경우)
                  if (answer != null && answer!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        border: Border.all(color: Colors.blue.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.auto_awesome,
                                size: 13, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text('AI 요약',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700)),
                          ]),
                          const SizedBox(height: 4),
                          Text(answer!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87)),
                        ],
                      ),
                    ),

                  // 선택 추가 버튼
                  if (selectedIds.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: Text('선택 ${selectedIds.length}개 추가'),
                          onPressed: onAddSelected,
                        ),
                      ),
                    ),

                  // 레코드 목록
                  Expanded(
                    child: ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final r = results[i];
                        final isSelected = selectedIds.contains(r.displayId);
                        return InkWell(
                          onTap: () => onToggleSelect(r.displayId),
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
                                        size: 13, color: Colors.green),
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
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
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
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)),
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
                Text(
                  record.id,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
          border:
              Border.all(color: Colors.orange.withValues(alpha: 0.4)),
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
                  style: const TextStyle(color: Colors.red, fontSize: 12))),
        ]),
      );
}
