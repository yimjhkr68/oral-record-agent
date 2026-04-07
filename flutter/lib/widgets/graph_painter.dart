import 'package:flutter/material.dart';

// ── 타입별 색상 팔레트 ────────────────────────────────────────────────────────

const _palette = [
  Color(0xFF1565C0), // 진파랑
  Color(0xFF2E7D32), // 진초록
  Color(0xFF6A1B9A), // 보라
  Color(0xFFE65100), // 주황
  Color(0xFF00695C), // 청록
  Color(0xFFC62828), // 빨강
  Color(0xFF4527A0), // 남보라
  Color(0xFF558B2F), // 올리브
  Color(0xFF1565C0), // 청
  Color(0xFF827717), // 황토
];

Color nodeColorForType(String type) {
  if (type.isEmpty) return const Color(0xFF607D8B);
  return _palette[type.hashCode.abs() % _palette.length];
}

// ── 노드 위젯 ────────────────────────────────────────────────────────────────

class GraphNodeWidget extends StatelessWidget {
  final String nodeId;
  final String nodeType;
  final bool highlighted;
  final VoidCallback? onTap;

  const GraphNodeWidget({
    super.key,
    required this.nodeId,
    required this.nodeType,
    this.highlighted = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = nodeColorForType(nodeType);
    final size = highlighted ? 72.0 : 56.0;
    final label = nodeId.length > 8 ? '${nodeId.substring(0, 8)}…' : nodeId;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.88),
          border: highlighted
              ? Border.all(color: Colors.amber, width: 3)
              : Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: highlighted ? 10 : 4,
              spreadRadius: highlighted ? 2 : 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: highlighted ? 10 : 9,
            color: Colors.white,
            fontWeight:
                highlighted ? FontWeight.bold : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
