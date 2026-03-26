// 파일 목적: 구술자 추가/편집 화면
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/master_data_provider.dart';
import '../../data/models/narrator.dart';
import '../../data/repositories/repository_provider.dart';
import '../../data/services/display_id_service.dart';

class AddEditNarratorPage extends ConsumerStatefulWidget {
  final String? narratorId; // null이면 추가, 값이면 편집
  const AddEditNarratorPage({super.key, this.narratorId});

  @override
  ConsumerState<AddEditNarratorPage> createState() =>
      _AddEditNarratorPageState();
}

class _AddEditNarratorPageState extends ConsumerState<AddEditNarratorPage> {
  final _nameCtrl = TextEditingController();
  final _nationalityCtrl = TextEditingController();
  final _birthPlaceCtrl = TextEditingController();
  final _jobTitleCtrl = TextEditingController();
  final _currentJobTitleCtrl = TextEditingController();
  final _affiliationCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _biographyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _interviewNotesCtrl = TextEditingController();
  final _careerCtrl = TextEditingController();

  String? _gender;
  DateTime? _dateOfBirth;
  List<String> _careerList = [];
  bool _isSaving = false;
  Narrator? _original;

  bool get _isEdit => widget.narratorId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadNarrator());
    }
  }

  void _loadNarrator() {
    final narrators = ref.read(narratorListProvider).valueOrNull;
    final n = narrators?.where((n) => n.id == widget.narratorId).firstOrNull;
    if (n == null) return;
    _original = n;
    _nameCtrl.text = n.name;
    _nationalityCtrl.text = n.nationality ?? '';
    _birthPlaceCtrl.text = n.birthPlace ?? '';
    _jobTitleCtrl.text = n.jobTitle ?? '';
    _currentJobTitleCtrl.text = n.currentJobTitle ?? '';
    _affiliationCtrl.text = n.affiliation ?? '';
    _phoneCtrl.text = n.phone ?? '';
    _emailCtrl.text = n.email ?? '';
    _addressCtrl.text = n.address ?? '';
    _biographyCtrl.text = n.biography ?? '';
    _notesCtrl.text = n.notes ?? '';
    _interviewNotesCtrl.text = n.interviewNotes ?? '';
    setState(() {
      _gender = n.gender;
      _dateOfBirth = n.dateOfBirth;
      _careerList = List.from(n.careerList);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _nationalityCtrl, _birthPlaceCtrl, _jobTitleCtrl,
      _currentJobTitleCtrl, _affiliationCtrl, _phoneCtrl, _emailCtrl,
      _addressCtrl, _biographyCtrl, _notesCtrl, _interviewNotesCtrl,
      _careerCtrl,
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
      final repo = await ref.read(narratorRepositoryProvider.future);
      String? displayId = _original?.displayId;
      if (!_isEdit) {
        final all = await repo.getAllNarrators();
        final existingIds = all
            .where((n) => n.displayId != null)
            .map((n) => n.displayId!)
            .toList();
        displayId = DisplayIdService.generateNarratorId(DateTime.now(), existingIds);
      }
      final narrator = Narrator(
        id: _original?.id,
        name: name,
        nationality: _v(_nationalityCtrl),
        birthPlace: _v(_birthPlaceCtrl),
        jobTitle: _v(_jobTitleCtrl),
        currentJobTitle: _v(_currentJobTitleCtrl),
        affiliation: _v(_affiliationCtrl),
        careerList: _careerList,
        phone: _v(_phoneCtrl),
        email: _v(_emailCtrl),
        address: _v(_addressCtrl),
        biography: _v(_biographyCtrl),
        notes: _v(_notesCtrl),
        interviewNotes: _v(_interviewNotesCtrl),
        gender: _gender,
        dateOfBirth: _dateOfBirth,
        createdAt: _original?.createdAt,
        displayId: displayId,
      );
      if (_isEdit) {
        await repo.updateNarrator(narrator.id, narrator);
      } else {
        await repo.createNarrator(narrator);
      }
      ref.invalidate(narratorListProvider);
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
        title: Text(_isEdit ? '구술자 편집' : '새 구술자 추가'),
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
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: _inputDeco('성별'),
              items: const [
                DropdownMenuItem(value: null, child: Text('선택 안 함')),
                DropdownMenuItem(value: 'M', child: Text('남성')),
                DropdownMenuItem(value: 'F', child: Text('여성')),
                DropdownMenuItem(value: 'Other', child: Text('기타')),
              ],
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_dateOfBirth == null
                  ? '생년월일 선택'
                  : '${_dateOfBirth!.year}년 ${_dateOfBirth!.month}월 ${_dateOfBirth!.day}일'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dateOfBirth ?? DateTime(1960),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _dateOfBirth = d);
              },
            ),
            const SizedBox(height: 12),
            _field(_nationalityCtrl, '국적'),
            const SizedBox(height: 12),
            _field(_birthPlaceCtrl, '출생지'),
            const SizedBox(height: 24),

            _sectionTitle('경력 정보'),
            const SizedBox(height: 8),
            _field(_jobTitleCtrl, '직업/직위 (당시)'),
            const SizedBox(height: 12),
            _field(_currentJobTitleCtrl, '직업/직위 (현재)'),
            const SizedBox(height: 12),
            _field(_affiliationCtrl, '소속 기관'),
            const SizedBox(height: 12),
            // 주요 경력 목록
            const Text('주요 경력',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (int i = 0; i < _careerList.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 8),
                title: Text(_careerList[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      setState(() => _careerList.removeAt(i)),
                ),
              ),
            Row(
              children: [
                Expanded(child: _field(_careerCtrl, '경력 추가')),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    final v = _careerCtrl.text.trim();
                    if (v.isNotEmpty) {
                      setState(() {
                        _careerList.add(v);
                        _careerCtrl.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            _sectionTitle('연락처'),
            const SizedBox(height: 8),
            _field(_phoneCtrl, '전화번호', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_emailCtrl, '이메일',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _field(_addressCtrl, '주소'),
            const SizedBox(height: 24),

            _sectionTitle('메모'),
            const SizedBox(height: 8),
            _field(_biographyCtrl, '약전/소개', maxLines: 4),
            const SizedBox(height: 12),
            _field(_notesCtrl, '특이사항', maxLines: 3),
            const SizedBox(height: 12),
            _field(_interviewNotesCtrl, '면담 전 조사 내용', maxLines: 3),
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
      decoration: _inputDeco(label),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}
