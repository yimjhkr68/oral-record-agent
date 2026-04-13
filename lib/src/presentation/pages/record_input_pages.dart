// 파일 목적: RecordInputPage - 기록 입력 화면 3가지 (Windows 버전)
// 1. RecordingPage  - 마이크 녹음 (record 패키지, 즉시 시작)
// 2. FilePickerPage - 영상/음성/문서 파일 업로드 통합
// 3. TextInputPage  - 텍스트 직접 입력 또는 문서 선택

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../providers/pending_content_provider.dart';
import '../providers/settings_provider.dart';
import '../../data/services/file_service.dart';
import '../../data/services/transcription_service.dart';
import '../../data/services/local_transcription_service.dart';
import '../../data/services/document_extraction_service.dart';
import '../widgets/windows_only_guard.dart';

// ========================================
// 1. RecordingPage - 마이크 녹음 (즉시 시작)
// ========================================
class RecordingPage extends ConsumerStatefulWidget {
  const RecordingPage({super.key});

  @override
  ConsumerState<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends ConsumerState<RecordingPage>
    with SingleTickerProviderStateMixin {
  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isTranscribing = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _error;

  // 파형 애니메이션
  late AnimationController _waveController;
  final _random = Random();
  final List<double> _waveHeights = List.generate(24, (_) => 0.1);

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..addListener(_updateWave)..repeat();
    _startRecording();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _updateWave() {
    if (!mounted) return;
    if (_isRecording && !_isPaused) {
      setState(() {
        for (var i = 0; i < _waveHeights.length; i++) {
          _waveHeights[i] = 0.1 + _random.nextDouble() * 0.9;
        }
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() => _error = '마이크 권한이 없습니다. Windows 설정 → 개인 정보 → 마이크에서 허용해주세요.');
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}${Platform.pathSeparator}rec_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _error = null;
      });
      _startTimer();
    } catch (e) {
      if (mounted) setState(() => _error = '녹음 시작 실패: $e');
    }
  }

  Future<void> _pauseOrResume() async {
    if (_isPaused) {
      await _audioRecorder.resume();
      setState(() => _isPaused = false);
      _startTimer();
    } else {
      await _audioRecorder.pause();
      setState(() => _isPaused = true);
      _timer?.cancel();
    }
  }

  Future<void> _stopAndSave() async {
    _timer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
    if (path != null) {
      await _processRecording(path);
    }
  }

  Future<void> _processRecording(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final name = file.uri.pathSegments.last;
    final duration = _formatTime(_elapsedSeconds);

    final settings = ref.read(settingsProvider);
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    String content = '[음성 녹음: $duration]';
    bool transcriptionFailed = false;
    String? transcriptionError;

    setState(() => _isTranscribing = true);

    // 로컬 Whisper 우선 → 실패 시 OpenAI API → 모두 없으면 실패
    final localResult = await LocalTranscriptionService.transcribeFile(
      filePath: path,
      pythonPath: settings.pythonPath,
      model: settings.whisperModel,
      language: settings.transcriptionLanguage,
    );

    if (mounted) setState(() => _isTranscribing = false);

    if (localResult.success) {
      content = localResult.text;
    } else if (!localResult.pythonNotFound && !localResult.whisperNotInstalled) {
      // Python/Whisper는 있지만 전사 실패 → 오류 표시
      transcriptionFailed = true;
      transcriptionError = localResult.error;
    } else {
      // Python/Whisper 없음 → OpenAI API 폴백
      final openAiKey = settings.openAiApiKey;
      if (openAiKey.isNotEmpty) {
        if (mounted) setState(() => _isTranscribing = true);
        final apiResult = await TranscriptionService.transcribeFile(
          filePath: path,
          apiKey: openAiKey,
          mimeType: 'audio/wav',
        );
        if (mounted) setState(() => _isTranscribing = false);
        if (apiResult.success) {
          content = apiResult.text;
        } else {
          transcriptionFailed = true;
          transcriptionError = apiResult.error;
        }
      } else {
        transcriptionFailed = true;
        transcriptionError = '로컬 Whisper를 사용하려면 Python과 openai-whisper를 설치하세요.\n'
            '(pip install openai-whisper)\n\n'
            '또는 설정에서 OpenAI API 키를 입력하면 클라우드 전사를 사용할 수 있습니다.';
      }
    }

    if (!mounted) return;
    ref.read(pendingContentProvider.notifier).state = PendingContent(
      content: content,
      inputType: 'audio',
      fileName: name,
      bytes: bytes,
      fileSize: bytes.length,
      mimeType: 'audio/wav',
      transcriptionFailed: transcriptionFailed,
      transcriptionError: transcriptionError,
      suggestedTitle: '면담 녹음 $dateStr',
    );
    context.push('/metadata-input');
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WindowsOnlyGuard(title: '음성 녹음', child: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('음성 녹음'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            final router = GoRouter.of(context);
            await _audioRecorder.stop();
            if (mounted) router.pop();
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[300]!),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _startRecording,
                  child: const Text('다시 시도'),
                ),
              ] else if (_isTranscribing) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('전사 중...', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                const Text(
                  '모델 크기에 따라 1~3분 소요될 수 있습니다\n(첫 실행 시 모델 다운로드 포함)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                // 녹음 시간
                Text(
                  _formatTime(_elapsedSeconds),
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
                const SizedBox(height: 32),

                // 파형 시각화
                SizedBox(
                  height: 80,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: _waveHeights.map((h) {
                      return Container(
                        width: 4,
                        height: (_isRecording && !_isPaused) ? h * 70 + 8 : 8,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: (_isRecording && !_isPaused)
                              ? Theme.of(context).primaryColor
                              : Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRecording
                      ? (_isPaused ? '일시 정지됨' : '녹음 중...')
                      : '준비 중',
                  style: TextStyle(
                    color: _isRecording && !_isPaused
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
                const SizedBox(height: 40),

                // 컨트롤 버튼
                if (_isRecording) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 일시정지/재개
                      FloatingActionButton(
                        heroTag: 'pause',
                        onPressed: _pauseOrResume,
                        backgroundColor: Colors.orange,
                        child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      ),
                      const SizedBox(width: 24),
                      // 정지 + 저장
                      FloatingActionButton.extended(
                        heroTag: 'stop',
                        onPressed: _stopAndSave,
                        backgroundColor: Colors.red,
                        icon: const Icon(Icons.stop),
                        label: const Text('정지 및 저장'),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================
// 2. FilePickerPage - 영상/음성/문서 파일 업로드 통합
// ========================================
class FilePickerPage extends ConsumerStatefulWidget {
  const FilePickerPage({super.key});

  @override
  ConsumerState<FilePickerPage> createState() => _FilePickerPageState();
}

class _FilePickerPageState extends ConsumerState<FilePickerPage> {
  String? _selectedFilePath;
  String? _selectedFileName;
  int? _selectedFileSize;
  String? _selectedMimeType;
  bool _isReading = false;
  bool _isTranscribing = false;
  bool _isExtracting = false;
  String? _readError;

  static const _supportedExtensions = [
    'mp4', 'avi', 'mov', 'mkv', 'wmv', // 영상
    'mp3', 'wav', 'm4a', 'aac', 'flac', // 음성
    'txt', 'docx', 'pdf', // 문서
  ];

  String _fileTypeLabel(String? mime) {
    if (mime == null) return '파일';
    if (mime.startsWith('video/')) return '영상';
    if (mime.startsWith('audio/')) return '음성';
    return '문서';
  }

  IconData _fileTypeIcon(String? mime) {
    if (mime == null) return Icons.insert_drive_file;
    if (mime.startsWith('video/')) return Icons.videocam;
    if (mime.startsWith('audio/')) return Icons.audiotrack;
    return Icons.description;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _supportedExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;
    final ext = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : '';
    final mime = FileService.mimeTypeFromExt(ext);
    setState(() {
      _selectedFilePath = file.path;
      _selectedFileName = file.name;
      _selectedFileSize = file.size;
      _selectedMimeType = mime;
      _readError = null;
    });
  }

  Future<void> _uploadFile() async {
    final path = _selectedFilePath;
    if (path == null) return;
    setState(() { _isReading = true; _isExtracting = false; _readError = null; });

    try {
      final result = await FileService.readFilePath(path);
      if (!mounted) return;

      String content = result.content;
      bool transcriptionFailed = false;
      String? transcriptionError;

      final ext = (path.split('.').last).toLowerCase();
      final settings = ref.read(settingsProvider);

      // ── PDF / DOCX: Python으로 텍스트 추출 ──
      if (ext == 'pdf' || ext == 'docx') {
        setState(() { _isReading = false; _isExtracting = true; });

        final extracted = await DocumentExtractionService.extractText(
          filePath: path,
          pythonPath: settings.pythonPath,
        );

        if (mounted) setState(() => _isExtracting = false);

        if (extracted.success && extracted.text.isNotEmpty) {
          content = extracted.text;
        } else if (ext == 'docx' && result.content.isNotEmpty &&
            !result.content.startsWith('[')) {
          // Python 실패 시 Dart archive 추출 결과 유지
        } else {
          // 추출 실패 → 사용자에게 알림 (업로드는 계속)
          transcriptionFailed = true;
          transcriptionError = extracted.error ??
              '$ext 파일 텍스트 추출 실패\n'
              'pip install ${ext == 'pdf' ? 'pdfplumber' : 'python-docx'} 를 실행해주세요.';
        }
      }

      // ── 오디오: 로컬 Whisper 우선, OpenAI API 폴백 ──
      else if (result.isAudioOrVideo && result.mimeType.startsWith('audio/')) {
        setState(() { _isReading = false; _isTranscribing = true; });

        final localResult = await LocalTranscriptionService.transcribeFile(
          filePath: path,
          pythonPath: settings.pythonPath,
          model: settings.whisperModel,
          language: settings.transcriptionLanguage,
        );

        if (localResult.success) {
          content = localResult.text;
          if (mounted) setState(() => _isTranscribing = false);
        } else if (!localResult.pythonNotFound && !localResult.whisperNotInstalled) {
          if (mounted) setState(() => _isTranscribing = false);
          transcriptionFailed = true;
          transcriptionError = localResult.error;
        } else {
          final openAiKey = settings.openAiApiKey;
          if (openAiKey.isNotEmpty) {
            final tr = await TranscriptionService.transcribeFile(
              filePath: path,
              apiKey: openAiKey,
              mimeType: result.mimeType,
            );
            if (mounted) setState(() => _isTranscribing = false);
            if (tr.success) {
              content = tr.text;
            } else {
              transcriptionFailed = true;
              transcriptionError = tr.error;
            }
          } else {
            if (mounted) setState(() => _isTranscribing = false);
            transcriptionFailed = true;
            transcriptionError = '로컬 Whisper를 사용하려면 Python과 openai-whisper를 설치하세요.\n'
                '(pip install openai-whisper)\n\n'
                '또는 설정에서 OpenAI API 키를 입력하면 클라우드 전사를 사용할 수 있습니다.';
          }
        }
      }

      if (!mounted) return;
      final inputType = result.mimeType.startsWith('video/')
          ? 'video'
          : result.mimeType.startsWith('audio/')
              ? 'audio'
              : 'document';

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final rawName = result.fileName.contains('.')
          ? result.fileName.substring(0, result.fileName.lastIndexOf('.'))
          : result.fileName;
      final titleFromFile = rawName.replaceAll('_', ' ').replaceAll('-', ' ').trim();

      ref.read(pendingContentProvider.notifier).state = PendingContent(
        content: content,
        inputType: inputType,
        fileName: result.fileName,
        bytes: result.bytes,
        fileSize: result.fileSize,
        mimeType: result.mimeType,
        transcriptionFailed: transcriptionFailed,
        transcriptionError: transcriptionError,
        suggestedTitle: titleFromFile.isNotEmpty ? titleFromFile : '파일 기록 $dateStr',
      );
      context.push('/metadata-input');
    } catch (e) {
      if (!mounted) return;
      setState(() => _readError = '파일 읽기 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isReading = false;
          _isTranscribing = false;
          _isExtracting = false;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const WindowsOnlyGuard(title: '파일 업로드', child: SizedBox.shrink());
    }
    final busy = _isReading || _isTranscribing || _isExtracting;
    return Scaffold(
      appBar: AppBar(title: const Text('파일 업로드')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _fileTypeIcon(_selectedMimeType),
                size: 72,
                color: _selectedMimeType != null
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
              const SizedBox(height: 16),

              if (_selectedFileName == null) ...[
                const Text(
                  '영상, 음성, 문서 파일을 선택하세요',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  '영상: MP4, AVI, MOV, MKV, WMV\n음성: MP3, WAV, M4A, AAC, FLAC\n문서: TXT, DOCX, PDF',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('파일 선택'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_fileTypeLabel(_selectedMimeType)} 파일 선택됨',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedFileName!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (_selectedFileSize != null)
                        Text(
                          _formatSize(_selectedFileSize!),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_readError != null) ...[
                  Text(
                    _readError!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],

                if (busy) ...[
                  const SizedBox(height: 8),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(_isTranscribing
                      ? '음성 전사 중...'
                      : _isExtracting
                          ? '텍스트 추출 중... (PDF/DOCX)'
                          : '파일 읽는 중...'),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _uploadFile,
                    icon: const Icon(Icons.upload),
                    label: const Text('업로드'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() {
                      _selectedFilePath = null;
                      _selectedFileName = null;
                      _selectedFileSize = null;
                      _selectedMimeType = null;
                      _readError = null;
                    }),
                    child: const Text('다시 선택'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ========================================
// 3. TextInputPage - 텍스트 직접 입력 / 문서 선택
// ========================================
class TextInputPage extends ConsumerStatefulWidget {
  const TextInputPage({super.key});

  @override
  ConsumerState<TextInputPage> createState() => _TextInputPageState();
}

class _TextInputPageState extends ConsumerState<TextInputPage> {
  final _textController = TextEditingController();
  String? _selectedFilePath;
  String? _selectedDocument;
  bool _isReading = false;
  bool _isExtracting = false;
  String? _readError;

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;
    setState(() {
      _selectedFilePath = file.path;
      _selectedDocument = file.name;
      _readError = null;
    });
  }

  Future<void> _continueWithText() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('텍스트를 입력하거나 문서를 선택해주세요.')),
      );
      return;
    }

    if (text.isNotEmpty) {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      ref.read(pendingContentProvider.notifier).state = PendingContent(
        content: text,
        inputType: 'text',
        suggestedTitle: '메모 $dateStr',
      );
      context.push('/metadata-input');
      return;
    }

    final path = _selectedFilePath!;
    setState(() { _isReading = true; _isExtracting = false; _readError = null; });

    try {
      final result = await FileService.readFilePath(path);
      if (!mounted) return;

      String content = result.content;
      final ext = path.split('.').last.toLowerCase();

      // PDF / DOCX: Python으로 텍스트 추출
      if (ext == 'pdf' || ext == 'docx') {
        final settings = ref.read(settingsProvider);
        setState(() { _isReading = false; _isExtracting = true; });

        final extracted = await DocumentExtractionService.extractText(
          filePath: path,
          pythonPath: settings.pythonPath,
        );

        if (mounted) setState(() => _isExtracting = false);

        if (extracted.success && extracted.text.isNotEmpty) {
          content = extracted.text;
        } else if (ext == 'docx' && result.content.isNotEmpty &&
            !result.content.startsWith('[')) {
          // Python 실패 시 Dart 추출 결과 유지
        } else if (!extracted.success) {
          setState(() => _readError =
              '텍스트 추출 실패: ${extracted.error}\n'
              'pip install ${ext == 'pdf' ? 'pdfplumber' : 'python-docx'} 를 실행해주세요.');
          return;
        }
      }

      if (!mounted) return;
      final rawName = result.fileName.contains('.')
          ? result.fileName.substring(0, result.fileName.lastIndexOf('.'))
          : result.fileName;
      final titleFromFile = rawName.replaceAll('_', ' ').replaceAll('-', ' ').trim();
      ref.read(pendingContentProvider.notifier).state = PendingContent(
        content: content,
        inputType: 'document',
        fileName: result.fileName,
        bytes: result.bytes,
        fileSize: result.fileSize,
        mimeType: result.mimeType,
        suggestedTitle: titleFromFile.isNotEmpty ? titleFromFile : result.fileName,
      );
      context.push('/metadata-input');
    } catch (e) {
      if (!mounted) return;
      setState(() => _readError = '파일 읽기 실패: $e');
    } finally {
      if (mounted) setState(() { _isReading = false; _isExtracting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('텍스트/문서 입력')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: '문서 선택'),
                      Tab(text: '직접 입력'),
                    ],
                  ),
                  SizedBox(
                    height: 400,
                    child: TabBarView(
                      children: [
                        // 문서 선택 탭
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.description,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              if (_selectedDocument != null) ...[
                                Text(
                                  '선택된 파일: $_selectedDocument',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                              ],
                              if (_readError != null) ...[
                                Text(
                                  _readError!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                              ],
                              ElevatedButton(
                                onPressed: _isReading ? null : _pickDocument,
                                child: Text(_selectedDocument == null
                                    ? '문서 선택'
                                    : '다시 선택'),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '지원 형식: PDF, DOCX, TXT',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        // 직접 입력 탭
                        TextField(
                          controller: _textController,
                          maxLines: null,
                          expands: true,
                          decoration: const InputDecoration(
                            hintText: '텍스트를 입력하세요...',
                            border: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if ((_isReading || _isExtracting) && _readError == null) ...[
              const SizedBox(height: 8),
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: (_isReading || _isExtracting) ? null : _continueWithText,
              child: (_isReading || _isExtracting)
                  ? Text(_isExtracting ? '텍스트 추출 중...' : '읽는 중...')
                  : const Text('계속'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
