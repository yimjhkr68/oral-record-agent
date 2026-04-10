import 'package:flutter/material.dart';

/// 그래프 상단 오버레이 — 검색창 + 통계 + export + 새로고침
class GraphSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final VoidCallback onRefresh;
  final Map<String, dynamic> stats;
  final String exportTooltip;

  const GraphSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onClear,
    required this.onExport,
    required this.onRefresh,
    required this.stats,
    this.exportTooltip = '전체 그래프 내보내기',
  });

  @override
  State<GraphSearchBar> createState() => _GraphSearchBarState();
}

class _GraphSearchBarState extends State<GraphSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // 검색창
      Expanded(
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(10),
          child: TextField(
            controller: widget.controller,
            decoration: InputDecoration(
              hintText: '노드 또는 관계(속성)로 검색...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: widget.onClear,
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onSubmitted: (v) => widget.onSearch(v.trim()),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // 통계 pill
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '노드 ${widget.stats['nodes'] ?? 0}  ·  트리플 ${widget.stats['triples'] ?? 0}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
      ),
      const SizedBox(width: 8),
      // export 버튼
      _OverlayButton(
        icon: Icons.download_outlined,
        tooltip: widget.exportTooltip,
        onTap: widget.onExport,
      ),
      const SizedBox(width: 6),
      // 새로고침 버튼
      _OverlayButton(
        icon: Icons.refresh,
        tooltip: '새로고침',
        onTap: widget.onRefresh,
      ),
    ]);
  }
}

class _OverlayButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _OverlayButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
