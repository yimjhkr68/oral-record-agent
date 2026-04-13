import 'package:flutter/material.dart';
import '../../models/ontology.dart';

/// 클래스 또는 속성 하나의 표준 매핑 카드.
/// 추천 후보 목록, 직접 입력, 확정/확정 취소 기능을 제공한다.
class MappingCard extends StatefulWidget {
  final MappingItem item;

  /// (tag, confirmed) — 저장/적용/확정 시 호출
  final void Function(String tag, bool confirmed) onSave;

  const MappingCard({required this.item, required this.onSave, super.key});

  @override
  State<MappingCard> createState() => _MappingCardState();
}

class _MappingCardState extends State<MappingCard> {
  late TextEditingController _ctrl;
  late bool _confirmed;
  late String _currentTag;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _currentTag = widget.item.currentTag;
    _confirmed = widget.item.isConfirmed;
    _ctrl = TextEditingController(text: _currentTag);
  }

  @override
  void didUpdateWidget(MappingCard old) {
    super.didUpdateWidget(old);
    if (old.item != widget.item) {
      _currentTag = widget.item.currentTag;
      _confirmed = widget.item.isConfirmed;
      _ctrl.text = _currentTag;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bgColor {
    if (_confirmed) return Colors.green.withValues(alpha: 0.07);
    if (_currentTag.isNotEmpty) return Colors.amber.withValues(alpha: 0.06);
    return Colors.transparent;
  }

  Color _parseColor(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      color: _bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 헤더 행 ─────────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // 클래스 색상 dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _parseColor(widget.item.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 이름 + 한국어 레이블
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.item.name}'
                          '${widget.item.labelKo.isNotEmpty ? "  (${widget.item.labelKo})" : ""}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        if (_currentTag.isNotEmpty)
                          Text(
                            _currentTag,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: _confirmed
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                            ),
                          )
                        else
                          Text('매핑 없음',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),

                  // 상태 아이콘
                  if (_confirmed)
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 18)
                  else if (_currentTag.isNotEmpty)
                    Icon(Icons.pending,
                        color: Colors.orange.shade600, size: 18),

                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          // ── 펼침: 추천 + 직접입력 ────────────────────────────────────────
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 추천 후보 목록
                  if (widget.item.suggestions.isNotEmpty) ...[
                    const Text('추천 매핑',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ...widget.item.suggestions.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('${s.priority}',
                                    style: const TextStyle(fontSize: 10)),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${s.uri}  (${s.label})',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace'),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _applyTag(s.uri),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('적용',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],

                  // 직접 입력
                  const Text('직접 입력',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: const TextStyle(
                            fontSize: 13, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: '예: cidoc:E21_Person',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => _applyTag(_ctrl.text.trim()),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('저장'),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  // 확정 / 확정 취소
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (_confirmed)
                      OutlinedButton(
                        onPressed: _unconfirm,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('확정 취소',
                            style: TextStyle(fontSize: 12)),
                      )
                    else
                      ElevatedButton(
                        onPressed: _currentTag.isEmpty ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('확정',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ]),
                ],
              ),
            ),

          const Divider(height: 1),
        ],
      ),
    );
  }

  void _applyTag(String tag) {
    if (tag.isEmpty) return;
    setState(() {
      _currentTag = tag;
      _ctrl.text = tag;
      _confirmed = false;
    });
    widget.onSave(tag, false);
  }

  void _confirm() {
    setState(() => _confirmed = true);
    widget.onSave(_currentTag, true);
  }

  void _unconfirm() {
    setState(() => _confirmed = false);
    widget.onSave(_currentTag, false);
  }
}
