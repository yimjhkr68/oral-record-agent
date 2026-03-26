// 파일 목적: 면담자 추가/편집 화면
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/master_data_provider.dart';
import '../../data/models/interviewer.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/services/display_id_service.dart';

class AddEditInterviewerPage extends ConsumerStatefulWidget {
  final String? interviewerId;
  const AddEditInterviewerPage({super.key, this.interviewerId});

  @override
  ConsumerState<AddEditInterviewerPage> createState() =>
      _AddEditInterviewerPageState();
}

class _AddEditInterviewerPageState
    extends ConsumerState<AddEditInterviewerPage> {
  final _nameCtrl = TextEditingController();
  final _affiliationCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;
  Interviewer? _original;

  bool get _isEdit => widget.interviewerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInterviewer());
    }
  }

  void _loadInterviewer() {
    final list = ref.read(interviewerListProvider).valueOrNull;
    final iv = list?.where((i) => i.id == widget.interviewerId).firstOrNull;
    if (iv == null) return;
    _original = iv;
    _nameCtrl.text = iv.name;
    _affiliationCtrl.text = iv.affiliation ?? '';
    _jobTitleCtrl.text = iv.jobTitle ?? '';
    _specializationCtrl.text = iv.specialization ?? '';
    _phoneCtrl.text = iv.phone ?? '';
    _emailCtrl.text = iv.email ?? '';
    _notesCtrl.text = iv.notes ?? '';
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _affiliationCtrl, _jobTitleCtrl, _specializationCtrl,
      _phoneCtrl, _emailCtrl, _notesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이름은 필수 항목입니다.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final repo = await ref.read(interviewerRepositoryProvider.future);
      String? displayId = _original?.displayId;
      if (!_isEdit) {
        final all = await repo.getAllInterviewers();
        final existingIds = all
            .where((i) => i.displayId != null)
            .map((i) => i.displayId!)
            .toList();
        displayId = DisplayIdService.generateInterviewerId(DateTime.now(), existingIds);
      }
      final interviewer = Interviewer(
        id: _original?.id,
        name: name,
        affiliation: _v(_affiliationCtrl),
        jobTitle: _v(_jobTitleCtrl),
        specialization: _v(_specializationCtrl),
        phone: _v(_phoneCtrl),
        email: _v(_emailCtrl),
        notes: _v(_notesCtrl),
        createdAt: _original?.createdAt,
        displayId: displayId,
      );
      if (_isEdit) {
        await repo.updateInterviewer(interviewer.id, interviewer);
      } else {
        await repo.createInterviewer(interviewer);
      }
      ref.invalidate(interviewerListProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '면담자 편집' : '새 면담자 추가'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('기본 정보'),
            const SizedBox(height: 8),
            _field(_nameCtrl, '이름 *'),
            const SizedBox(height: 12),
            _field(_affiliationCtrl, '소속 기관'),
            const SizedBox(height: 12),
            _field(_jobTitleCtrl, '직위'),
            const SizedBox(height: 12),
            _field(_specializationCtrl, '전문 분야'),
            const SizedBox(height: 24),

            _sectionTitle('연락처'),
            const SizedBox(height: 8),
            _field(_phoneCtrl, '전화번호', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_emailCtrl, '이메일',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 24),

            _sectionTitle('메모'),
            const SizedBox(height: 8),
            _field(_notesCtrl, '메모', maxLines: 4),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isEdit ? '수정 저장' : '추가',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(color: Theme.of(context).colorScheme.primary));

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
