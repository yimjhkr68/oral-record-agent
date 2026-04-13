// 파일 목적: AI 콘텐츠 생성 화면 (선택된 기록을 바탕으로 책/보고서/기사 등 생성)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../data/models/record.dart';
import '../../data/models/narrator.dart';
import '../providers/master_data_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

// ── 챕터 상태 ──────────────────────────────────────────────────────────────
enum _ChapterStatus { pending, generating, done, error }

// ── 챕터 데이터 ────────────────────────────────────────────────────────────
class _ChapterData {
  final int no;
  final String title;
  final String summary;
  final int estimatedPages;
  final String type; // preface | narrator_intro | toc | chapter | conclusion
  _ChapterStatus status = _ChapterStatus.pending;
  String? content;
  String? errorMsg;

  _ChapterData({
    required this.no,
    required this.title,
    required this.summary,
    required this.estimatedPages,
    required this.type,
  });
}

// ── 빠른 템플릿 ────────────────────────────────────────────────────────────
class _QuickTemplate {
  final String emoji;
  final String label;
  final String prompt;
  const _QuickTemplate(
      {required this.emoji, required this.label, required this.prompt});
}

const _quickTemplates = [
  _QuickTemplate(
    emoji: '📖',
    label: '책 편집',
    prompt:
        '구술 내용을 2~3개의 주제로 나누어서 책으로 편집해줘. 구술자의 어투가 잘 살아있도록 만들어줘.',
  ),
  _QuickTemplate(
    emoji: '📋',
    label: '보고서',
    prompt:
        '구술 내용을 분석하여 학술 보고서 형식으로 작성해줘. 주요 주제, 역사적 맥락, 시사점을 포함해줘.',
  ),
  _QuickTemplate(
    emoji: '📰',
    label: '기사',
    prompt: '구술 내용을 바탕으로 읽기 쉬운 인터뷰 기사 형식으로 작성해줘.',
  ),
  _QuickTemplate(
    emoji: '🗂',
    label: '주제별 정리',
    prompt: '구술 내용에서 주요 주제를 추출하고 주제별로 내용을 정리해줘.',
  ),
  _QuickTemplate(
    emoji: '📊',
    label: '연구 자료',
    prompt:
        '구술 내용을 구술사 연구 자료 형식으로 정리해줘. 색인과 참고문헌 형식 포함.',
  ),
];

// ── 페이지 ─────────────────────────────────────────────────────────────────
class AiContentGenerationPage extends ConsumerStatefulWidget {
  final List<Record> selectedRecords;

  const AiContentGenerationPage({
    super.key,
    required this.selectedRecords,
  });

  @override
  ConsumerState<AiContentGenerationPage> createState() =>
      _AiContentGenerationPageState();
}

class _AiContentGenerationPageState
    extends ConsumerState<AiContentGenerationPage> {
  int _step = 0; // 0=confirm, 1=prompt, 2=generating, 3=complete

  // Step 1 state
  final _promptCtrl = TextEditingController();
  int _targetPages = 100;
  String _outputFormat = 'Word';
  bool _includePreface = true;
  bool _includeConclusion = true;
  bool _includeToc = true;
  bool _includeNarratorIntro = true;

  // Step 2 state
  String? _generatedTitle;
  List<_ChapterData> _chapters = [];
  bool _isGenerating = false;
  bool _isCancelled = false;
  String? _generationError;

  // Step 3 state
  String? _savedDocxPath;
  String? _savedTxtPath;

  @override
  void initState() {
    super.initState();
    _promptCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  // ── 전사 완료 기록만 필터링 ────────────────────────────────────────────
  List<Record> get _validRecords => widget.selectedRecords
      .where((r) => r.content.trim().isNotEmpty)
      .toList();

  int get _totalChars =>
      _validRecords.fold(0, (sum, r) => sum + r.content.length);

  // ── 전체 구술 내용 조합 ────────────────────────────────────────────────
  String _buildCombinedContent(Map<String, Narrator> narratorMap) {
    final buffer = StringBuffer();
    for (final record in _validRecords) {
      final narrator = narratorMap[record.narratorId];
      final narratorName = narrator?.name ?? '구술자';
      buffer.writeln('=== [${record.displayId ?? record.title}] 구술자: $narratorName ===');
      buffer.writeln(record.content.trim());
      buffer.writeln();
    }
    final content = buffer.toString();
    if (content.length > 50000) {
      return '${content.substring(0, 50000)}\n\n[내용이 길어 일부 생략됨]';
    }
    return content;
  }

  // ── Claude API 호출 ────────────────────────────────────────────────────
  Future<String> _callClaudeApi(String prompt) async {
    final apiKey = ref.read(settingsProvider).apiKey;
    if (apiKey.isEmpty) {
      throw Exception(
          'API 키가 없습니다. 설정 > API 설정에서 Claude API 키를 입력해주세요.');
    }

    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'content-type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': 'claude-sonnet-4-6',
            'max_tokens': 8192,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 180));

    if (response.statusCode != 200) {
      final Map<String, dynamic> errBody =
          jsonDecode(utf8.decode(response.bodyBytes));
      throw Exception(
          'API 오류 (${response.statusCode}): ${errBody['error']?['message'] ?? response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['content'][0]['text'] as String;
  }

  // ── 구조 설계 + 챕터별 생성 ───────────────────────────────────────────
  Future<void> _startGeneration() async {
    if (_promptCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('생성할 산출물을 설명해주세요.')),
      );
      return;
    }

    final narratorMap = ref.read(narratorMapProvider).valueOrNull ?? {};
    final combinedContent = _buildCombinedContent(narratorMap);

    setState(() {
      _step = 2;
      _isGenerating = true;
      _isCancelled = false;
      _generationError = null;
      _chapters = [];
      _generatedTitle = null;
    });

    try {
      // ── 1단계: 구조 설계 ─────────────────────────────────────────────
      final includeItems = <String>[
        if (_includePreface) '머리말',
        if (_includeNarratorIntro) '구술자 소개',
        if (_includeToc) '목차',
        '본문 챕터',
        if (_includeConclusion) '맺는말',
      ];

      final structurePrompt = '''
아래 구술 기록을 바탕으로 요청에 맞는 산출물의 구조를 설계해줘.

요청: ${_promptCtrl.text.trim()}
목표 분량: $_targetPages쪽 (A4 기준)
포함 항목: ${includeItems.join(', ')}

반드시 아래 JSON 형식으로만 응답해줘. JSON 외 다른 텍스트는 포함하지 마.
{
  "title": "산출물 제목",
  "chapters": [
    {"no": 1, "title": "챕터 제목", "summary": "이 챕터에서 다룰 핵심 내용 (2~3문장)", "estimated_pages": 10, "type": "preface"}
  ]
}

type 규칙: "preface"(머리말), "narrator_intro"(구술자 소개), "toc"(목차), "chapter"(본문), "conclusion"(맺는말)

구술 기록:
$combinedContent''';

      if (_isCancelled) {
        setState(() => _isGenerating = false);
        return;
      }

      final structureResponse = await _callClaudeApi(structurePrompt);
      if (_isCancelled || !mounted) {
        if (mounted) setState(() => _isGenerating = false);
        return;
      }

      // JSON 추출 (마크다운 코드블록 제거)
      String jsonStr = structureResponse.trim();
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(jsonStr);
      if (jsonMatch != null) jsonStr = jsonMatch.group(0)!;

      final Map<String, dynamic> structure = jsonDecode(jsonStr);
      final title = (structure['title'] as String?) ?? '구술 기록 산출물';
      final chaptersRaw = (structure['chapters'] as List<dynamic>?) ?? [];

      final chapters = chaptersRaw.indexed.map(((int, dynamic) pair) {
        final i = pair.$1;
        final c = pair.$2 as Map<String, dynamic>;
        final chCount = chaptersRaw.isNotEmpty ? chaptersRaw.length : 1;
        return _ChapterData(
          no: (c['no'] as num?)?.toInt() ?? (i + 1),
          title: (c['title'] as String?) ?? '챕터 ${i + 1}',
          summary: (c['summary'] as String?) ?? '',
          estimatedPages:
              (c['estimated_pages'] as num?)?.toInt() ?? (_targetPages ~/ chCount),
          type: (c['type'] as String?) ?? 'chapter',
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _generatedTitle = title;
        _chapters = chapters;
      });

      // ── 2단계: 챕터별 순차 생성 ─────────────────────────────────────
      for (int i = 0; i < _chapters.length; i++) {
        if (_isCancelled || !mounted) break;

        // 목차는 API 없이 자동 생성
        if (_chapters[i].type == 'toc') {
          final tocLines = _chapters
              .where((c) => c.type == 'chapter')
              .map((c) => '${c.no}장. ${c.title}')
              .join('\n');
          if (mounted) {
            setState(() {
              _chapters[i].status = _ChapterStatus.done;
              _chapters[i].content = tocLines.isNotEmpty ? tocLines : '(목차 자동 생성)';
            });
          }
          continue;
        }

        if (mounted) {
          setState(() => _chapters[i].status = _ChapterStatus.generating);
        }

        try {
          final content =
              await _generateChapterContent(i, narratorMap, combinedContent);
          if (!mounted) break;
          setState(() {
            _chapters[i].status = _ChapterStatus.done;
            _chapters[i].content = content;
          });
        } catch (e) {
          if (!mounted) break;
          setState(() {
            _chapters[i].status = _ChapterStatus.error;
            _chapters[i].errorMsg = e.toString();
          });
        }
      }

      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        if (!_isCancelled) _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
        _generationError = e.toString();
      });
    }
  }

  // ── 챕터 내용 생성 ─────────────────────────────────────────────────────
  Future<String> _generateChapterContent(
    int index,
    Map<String, Narrator> narratorMap,
    String combinedContent, {
    String? modificationRequest,
  }) async {
    final chapter = _chapters[index];

    final previousSummaries = _chapters
        .take(index)
        .where((c) => c.status == _ChapterStatus.done && c.type != 'toc')
        .map((c) => '  - ${c.title}: ${c.summary}')
        .join('\n');

    String typeInstruction;
    switch (chapter.type) {
      case 'preface':
        typeInstruction =
            '따뜻하고 인간적인 머리말을 써줘. 이 기록들의 의미와 가치를 담아서. 약 ${chapter.estimatedPages}쪽 분량.';
        break;
      case 'narrator_intro':
        final names = _validRecords
            .map((r) => narratorMap[r.narratorId]?.name ?? '구술자')
            .toSet()
            .join(', ');
        typeInstruction =
            '$names 구술자를 소개하는 글을 써줘. 구술 내용에서 파악한 인물 특성과 배경 중심으로. 구술자당 약 1쪽.';
        break;
      case 'conclusion':
        typeInstruction =
            '전체 내용을 아우르는 맺는말을 써줘. 기록의 의미와 앞으로의 과제를 담아서. 약 ${chapter.estimatedPages}쪽 분량.';
        break;
      default: // chapter
        typeInstruction =
            '"${chapter.title}" 챕터를 써줘. 약 ${chapter.estimatedPages}쪽 분량. 핵심 내용: ${chapter.summary}';
    }

    final modNote = modificationRequest != null
        ? '\n수정 요청: $modificationRequest\n'
        : '';

    final prompt = '''
아래 구술 기록을 바탕으로 다음 챕터를 작성해줘.

챕터: ${chapter.title}
$typeInstruction$modNote

글쓰기 지침:
- 구술자의 어투와 실제 표현을 최대한 살려서 써줘
- 자연스러운 문어체로 편집해줘
- 단락은 빈 줄로 명확히 구분해줘
- 요청: ${_promptCtrl.text.trim()}

이전 챕터 흐름:
$previousSummaries

구술 기록:
$combinedContent''';

    return _callClaudeApi(prompt);
  }

  // ── 챕터 재생성 ────────────────────────────────────────────────────────
  Future<void> _regenerateChapter(int index,
      {String? modificationRequest}) async {
    final narratorMap = ref.read(narratorMapProvider).valueOrNull ?? {};
    final combinedContent = _buildCombinedContent(narratorMap);

    if (!mounted) return;
    setState(() {
      _chapters[index].status = _ChapterStatus.generating;
      _chapters[index].content = null;
      _chapters[index].errorMsg = null;
    });

    try {
      final content = await _generateChapterContent(
        index, narratorMap, combinedContent,
        modificationRequest: modificationRequest,
      );
      if (!mounted) return;
      setState(() {
        _chapters[index].status = _ChapterStatus.done;
        _chapters[index].content = content;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chapters[index].status = _ChapterStatus.error;
        _chapters[index].errorMsg = e.toString();
      });
    }
  }

  // ── TXT 저장 ───────────────────────────────────────────────────────────
  Future<String> _saveTxt() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${docsDir.path}/OralRecordAgent/outputs');
    await outputDir.create(recursive: true);

    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final safeTitle = (_generatedTitle ?? '구술기록산출물')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final filePath = '${outputDir.path}/${safeTitle}_$dateStr.txt';

    final buffer = StringBuffer();
    buffer.writeln(_generatedTitle ?? '');
    buffer.writeln('=' * 60);
    buffer.writeln();
    for (final ch in _chapters) {
      if (ch.content != null) {
        buffer.writeln(ch.title);
        buffer.writeln('-' * 40);
        buffer.writeln(ch.content);
        buffer.writeln();
      }
    }
    await File(filePath).writeAsString(buffer.toString(), flush: true);
    return filePath;
  }

  // ── Word (.docx) 저장 via Python ───────────────────────────────────────
  Future<String> _saveDocx() async {
    final pythonPath = ref.read(settingsProvider).pythonPath;
    final python = pythonPath.isNotEmpty ? pythonPath : 'python';

    final docsDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${docsDir.path}/OralRecordAgent/outputs');
    await outputDir.create(recursive: true);

    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final safeTitle = (_generatedTitle ?? '구술기록산출물')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final docxPath = '${outputDir.path}/${safeTitle}_$dateStr.docx';

    final jsonData = {
      'title': _generatedTitle ?? '구술 기록 산출물',
      'output_path': docxPath,
      'chapters': _chapters
          .where((c) => c.content != null)
          .map((c) => {
                'no': c.no,
                'title': c.title,
                'content': c.content,
                'type': c.type,
              })
          .toList(),
    };

    final tempDir = await getTemporaryDirectory();
    final jsonPath =
        '${tempDir.path}/docx_data_${now.millisecondsSinceEpoch}.json';
    await File(jsonPath).writeAsString(
        const JsonEncoder.withIndent('  ').convert(jsonData));

    // Script 위치 탐색 (개발 환경 기준)
    final execDir = File(Platform.resolvedExecutable).parent.path;
    final scriptCandidates = [
      'scripts/create_docx.py',
      '$execDir/scripts/create_docx.py',
      '$execDir/../../../scripts/create_docx.py',
    ];
    final scriptPath = scriptCandidates.firstWhere(
      (p) => File(p).existsSync(),
      orElse: () => 'scripts/create_docx.py',
    );

    // stdoutEncoding 지정 않고 raw bytes로 받아 직접 UTF-8 디코딩
    // (Windows 콘솔 CP949 인코딩과 충돌 방지)
    final result = await Process.run(
      python,
      [scriptPath, jsonPath],
    );

    try {
      File(jsonPath).deleteSync();
    } catch (_) {}

    // ── 최우선 판단: 파일 실제 존재 여부 ─────────────────────────────
    final fileExists = File(docxPath).existsSync();
    final fileSize = fileExists ? File(docxPath).lengthSync() : 0;
    if (fileExists && fileSize > 0) {
      return docxPath; // 파일이 있으면 무조건 성공
    }

    // ── 파일 없을 때 오류 분석 ─────────────────────────────────────
    if (result.exitCode != 0) {
      // stdout/stderr 둘 다 시도해서 JSON 에러 추출
      String errMsg = '';
      for (final raw in [result.stderr, result.stdout]) {
        final s = _decodeProcessOutput(raw);
        // { 로 시작하는 JSON 라인 찾기
        final jsonLine = s
            .split('\n')
            .map((l) => l.trim())
            .firstWhere((l) => l.startsWith('{'), orElse: () => '');
        if (jsonLine.isNotEmpty) {
          try {
            final m = jsonDecode(jsonLine) as Map<String, dynamic>;
            errMsg = m['error']?.toString() ?? '';
            break;
          } catch (_) {}
        }
        if (errMsg.isEmpty && s.trim().isNotEmpty) errMsg = s.trim();
      }
      throw Exception('Word 변환 실패:\n${errMsg.isNotEmpty ? errMsg : '알 수 없는 오류'}');
    }

    throw Exception('Word 파일이 생성되지 않았습니다.');
  }

  // ── Process 출력 디코딩 (CP949 / UTF-8 모두 시도) ─────────────────────
  String _decodeProcessOutput(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    // raw bytes인 경우 UTF-8 → CP949 순으로 시도
    final bytes = raw as List<int>;
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  // ── 헬퍼 ───────────────────────────────────────────────────────────────
  int get _estimatedTotalPages => _chapters
      .where((c) => c.content != null)
      .fold(0, (sum, c) => sum + (c.content!.length ~/ 600).clamp(1, 999));

  int get _doneCount =>
      _chapters.where((c) => c.status == _ChapterStatus.done).length;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatNumber(int n) {
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}만';
    return n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final titles = ['AI 콘텐츠 생성', '어떤 산출물을 만들까요?', 'AI 생성 중...', '생성 완료!'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_step.clamp(0, 3)]),
        leading: (_step == 2 && _isGenerating)
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
        actions: [
          if (_step == 2 && _isGenerating)
            TextButton(
              onPressed: () => setState(() => _isCancelled = true),
              child: const Text('중단', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: switch (_step) {
        0 => _buildConfirmStep(),
        1 => _buildPromptStep(),
        2 => _buildGeneratingStep(),
        3 => _buildCompleteStep(),
        _ => const SizedBox.shrink(),
      },
    );
  }

  // ── Step 0: 기록 확인 ──────────────────────────────────────────────────
  Widget _buildConfirmStep() {
    final validCount = _validRecords.length;
    final invalidCount = widget.selectedRecords.length - validCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '선택된 기록 (${widget.selectedRecords.length}건)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.selectedRecords.length,
            itemBuilder: (context, i) {
              final record = widget.selectedRecords[i];
              final hasContent = record.content.trim().isNotEmpty;
              final sizeStr = record.fileSize != null
                  ? _formatFileSize(record.fileSize!)
                  : '${_formatNumber(record.content.length)}자';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    hasContent ? Icons.check_circle : Icons.warning_amber,
                    color: hasContent ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  title: Text(
                    record.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: hasContent ? null : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    '${record.displayId != null ? '${record.displayId!} · ' : ''}$sizeStr · ${hasContent ? '전사완료' : '전사미완료'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '총 전사 분량: 약 ${_formatNumber(_totalChars)}자',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              if (invalidCount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '전사 미완료 기록 $invalidCount건은 제외됩니다',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      validCount > 0 ? () => setState(() => _step = 1) : null,
                  child: const Text('다음'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Step 1: 프롬프트 입력 ──────────────────────────────────────────────
  Widget _buildPromptStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _promptCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  '어떤 산출물을 만들고 싶으신가요?\n예: 구술 내용을 2~3개의 주제로 나누어 책으로 편집해줘. 구술자의 어투가 잘 살아있도록 만들어줘.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          // 빠른 템플릿
          const Text('빠른 템플릿',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _quickTemplates
                .map((t) => ActionChip(
                      label: Text('${t.emoji} ${t.label}'),
                      onPressed: () =>
                          setState(() => _promptCtrl.text = t.prompt),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),

          // 산출물 설정
          const Text('산출물 설정',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('목표 분량 (A4): '),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: _targetPages.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    suffixText: '쪽',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null && parsed > 0) {
                      setState(() => _targetPages = parsed);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('출력 형식'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['Word', 'TXT'].map((fmt) {
              return ChoiceChip(
                label: Text(fmt == 'Word' ? '📄 Word' : '📝 TXT'),
                selected: _outputFormat == fmt,
                onSelected: (_) => setState(() => _outputFormat = fmt),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // 자동 포함
          const Text('자동 포함',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          _buildCheckRow('머리말/맺는말 자동 작성', _includePreface, (v) {
            setState(() {
              _includePreface = v;
              _includeConclusion = v;
            });
          }),
          _buildCheckRow('목차 자동 생성', _includeToc,
              (v) => setState(() => _includeToc = v)),
          _buildCheckRow('구술자 소개 자동 포함', _includeNarratorIntro,
              (v) => setState(() => _includeNarratorIntro = v)),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step = 0),
                  child: const Text('이전'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _startGeneration,
                  child: const Text('AI 생성 시작'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckRow(
      String label, bool value, void Function(bool) onChanged) {
    return CheckboxListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      contentPadding: EdgeInsets.zero,
    );
  }

  // ── Step 2: 생성 중 ────────────────────────────────────────────────────
  Widget _buildGeneratingStep() {
    final total = _chapters.length;
    final done = _doneCount;
    final progress = total > 0 ? done / total : 0.0;

    return Column(
      children: [
        // 오류 배너
        if (_generationError != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.error.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_generationError!,
                      style:
                          const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
                TextButton(
                  onPressed: _startGeneration,
                  child: const Text('재시도'),
                ),
              ],
            ),
          ),

        // 진행 상황
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: _chapters.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('챕터 구조 분석 중...',
                        style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('$done/$total 챕터',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
        ),
        if (_generatedTitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              _generatedTitle!,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

        // 챕터 목록
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _chapters.length,
            itemBuilder: (context, i) =>
                _buildChapterItem(i, showPreview: true),
          ),
        ),

        // 하단 분량 표시
        if (_estimatedTotalPages > 0)
          Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xFFF4F6FA),
            child: Text(
              '생성된 분량: 약 $_estimatedTotalPages쪽 / 목표 $_targetPages쪽',
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
      ],
    );
  }

  // ── Step 3: 완료 ───────────────────────────────────────────────────────
  Widget _buildCompleteStep() {
    final doneCount = _chapters.where((c) => c.content != null).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Center(
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, size: 48, color: AppTheme.primary),
                const SizedBox(height: 12),
                Text(
                  _generatedTitle ?? '구술 기록 산출물',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  '총 $doneCount개 챕터 · 약 $_estimatedTotalPages쪽',
                  style: const TextStyle(
                      fontSize: 14, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 챕터 목록
          const Text('생성된 챕터',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...List.generate(
              _chapters.length, (i) => _buildChapterItem(i, showPreview: true)),
          const SizedBox(height: 24),

          // 내보내기
          const Text('내보내기',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.description),
              label: const Text('Word로 저장 (.docx)'),
              onPressed: () => _exportAs('Word'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.text_snippet),
              label: const Text('TXT로 저장'),
              onPressed: () => _exportAs('TXT'),
            ),
          ),

          // 저장 완료 표시
          if (_savedDocxPath != null || _savedTxtPath != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 6),
                      Text('저장 완료',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                  if (_savedDocxPath != null) ...[
                    const SizedBox(height: 4),
                    Text(_savedDocxPath!,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                  if (_savedTxtPath != null) ...[
                    const SizedBox(height: 4),
                    Text(_savedTxtPath!,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('폴더 열기'),
                    style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: () {
                      final path = _savedDocxPath ?? _savedTxtPath!;
                      final dir = File(path).parent.path;
                      Process.run('explorer', [dir]);
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 챕터 아이템 ────────────────────────────────────────────────────────
  Widget _buildChapterItem(int index, {bool showPreview = false}) {
    final chapter = _chapters[index];

    final Widget leading = switch (chapter.status) {
      _ChapterStatus.done =>
        const Icon(Icons.check_circle, color: Colors.green, size: 20),
      _ChapterStatus.generating => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2)),
      _ChapterStatus.error =>
        const Icon(Icons.error_outline, color: AppTheme.error, size: 20),
      _ChapterStatus.pending =>
        Icon(Icons.schedule, color: Colors.grey.shade400, size: 20),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapter.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: chapter.status == _ChapterStatus.done
                        ? FontWeight.w500
                        : FontWeight.normal,
                    color: chapter.status == _ChapterStatus.pending
                        ? Colors.grey
                        : null,
                  ),
                ),
                if (chapter.status == _ChapterStatus.generating)
                  const Text('생성 중...',
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary)),
                if (chapter.status == _ChapterStatus.error)
                  Text(chapter.errorMsg ?? '오류 발생',
                      style:
                          const TextStyle(fontSize: 11, color: AppTheme.error),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                if (chapter.status == _ChapterStatus.done &&
                    chapter.content != null)
                  Text(
                    '약 ${(chapter.content!.length ~/ 600).clamp(1, 999)}쪽',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          if (showPreview && chapter.status == _ChapterStatus.done)
            TextButton(
              onPressed: () => _showChapterPreview(index),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('미리보기', style: TextStyle(fontSize: 12)),
            ),
          if (chapter.status == _ChapterStatus.error)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '재시도',
              onPressed: () => _regenerateChapter(index),
            ),
        ],
      ),
    );
  }

  // ── 챕터 미리보기 ──────────────────────────────────────────────────────
  void _showChapterPreview(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _ChapterPreviewDialog(
        chapter: _chapters[index],
        onRegenerate: () {
          Navigator.of(ctx).pop();
          _regenerateChapter(index);
        },
        onModificationRequest: (request) {
          Navigator.of(ctx).pop();
          _regenerateChapter(index, modificationRequest: request);
        },
      ),
    );
  }

  // ── 내보내기 ───────────────────────────────────────────────────────────
  Future<void> _exportAs(String format) async {
    try {
      final String path;
      if (format == 'TXT') {
        path = await _saveTxt();
        if (mounted) setState(() => _savedTxtPath = path);
      } else {
        path = await _saveDocx();
        if (mounted) setState(() => _savedDocxPath = path);
      }
      if (!mounted) return;
      _showSaveSuccessDialog(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('저장 실패: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _showSaveSuccessDialog(String filePath) {
    final file = File(filePath);
    final fileName = filePath.split(Platform.pathSeparator).last;
    final dirPath = file.parent.path;
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final sizeStr = fileSize > 0 ? _formatFileSize(fileSize) : '-';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('저장 완료!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow2('파일명', fileName),
            const SizedBox(height: 6),
            _InfoRow2('위치', dirPath),
            const SizedBox(height: 6),
            _InfoRow2('크기', sizeStr),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('폴더 열기'),
            onPressed: () {
              Process.run('explorer', [dirPath]);
              Navigator.of(ctx).pop();
            },
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}

// ── 챕터 미리보기 다이얼로그 ───────────────────────────────────────────────
class _ChapterPreviewDialog extends StatefulWidget {
  final _ChapterData chapter;
  final VoidCallback onRegenerate;
  final void Function(String request) onModificationRequest;

  const _ChapterPreviewDialog({
    required this.chapter,
    required this.onRegenerate,
    required this.onModificationRequest,
  });

  @override
  State<_ChapterPreviewDialog> createState() => _ChapterPreviewDialogState();
}

class _ChapterPreviewDialogState extends State<_ChapterPreviewDialog> {
  bool _showModInput = false;
  final _modCtrl = TextEditingController();

  @override
  void dispose() {
    _modCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final pageEst = chapter.content != null
        ? (chapter.content!.length ~/ 600).clamp(1, 999)
        : 0;

    return AlertDialog(
      title: Text(chapter.title, style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  chapter.content ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.7),
                ),
              ),
            ),
            const Divider(),
            Text('분량: 약 $pageEst쪽',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
            if (_showModInput) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _modCtrl,
                maxLines: 2,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText:
                      '수정 요청 (예: 더 구어체로 써줘, 구술자의 실제 표현을 더 살려줘)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onRegenerate,
          child: const Text('다시 생성'),
        ),
        if (!_showModInput)
          TextButton(
            onPressed: () => setState(() => _showModInput = true),
            child: const Text('수정 요청'),
          )
        else
          ElevatedButton(
            onPressed: _modCtrl.text.trim().isEmpty
                ? null
                : () => widget.onModificationRequest(_modCtrl.text.trim()),
            child: const Text('수정 요청 전송'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

// ── 저장 성공 다이얼로그 정보 행 ───────────────────────────────────────────
class _InfoRow2 extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow2(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 44,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ],
    );
  }
}
