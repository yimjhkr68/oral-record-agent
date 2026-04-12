import 'package:flutter/material.dart';

/// 그래프 상단 오버레이 — 검색창 + 통계 + export + 새로고침
class GraphSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onClear;
  final VoidCallback onExport;
  final VoidCallback onRefresh;
  final VoidCallback onFitScreen;
  final ValueChanged<String> onPrint; // 'png' | 'pdf'
  final ValueChanged<String> onLayout; // 'save' | 'load'
  final VoidCallback onToggleClusterPanel;
  final bool clusterPanelActive;
  final Map<String, dynamic> stats;
  final String exportTooltip;

  const GraphSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onClear,
    required this.onExport,
    required this.onRefresh,
    required this.onFitScreen,
    required this.onPrint,
    required this.onLayout,
    required this.onToggleClusterPanel,
    required this.stats,
    this.clusterPanelActive = false,
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
      Builder(builder: (_) {
        final total    = widget.stats['nodes']         ?? 0;
        final visible  = widget.stats['visible_nodes'] ?? total;
        final totalE   = widget.stats['triples']        ?? 0;
        final visibleE = widget.stats['visible_edges']  ?? totalE;
        final filtered = visible < total;
        final label = filtered
            ? '노드 $visible / $total  ·  트리플 $visibleE / $totalE'
            : '노드 $total  ·  트리플 $totalE';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: filtered
                ? Colors.amber.shade800.withValues(alpha: 0.80)
                : Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500),
          ),
        );
      }),
      const SizedBox(width: 8),
      // export 버튼
      _OverlayButton(
        icon: Icons.download_outlined,
        tooltip: widget.exportTooltip,
        onTap: widget.onExport,
      ),
      const SizedBox(width: 6),
      // 전체 보기 버튼
      _OverlayButton(
        icon: Icons.fit_screen,
        tooltip: '전체 보기',
        onTap: widget.onFitScreen,
      ),
      const SizedBox(width: 6),
      // 레이아웃 저장/불러오기 버튼
      _LayoutButton(onLayout: widget.onLayout),
      const SizedBox(width: 6),
      // 출력 버튼 (PNG / PDF 팝업)
      _PrintButton(onPrint: widget.onPrint),
      const SizedBox(width: 6),
      // 새로고침 버튼
      _OverlayButton(
        icon: Icons.refresh,
        tooltip: '새로고침',
        onTap: widget.onRefresh,
      ),
      const SizedBox(width: 6),
      // 범주 패널 토글 버튼
      Tooltip(
        message: '범주 관리',
        child: Material(
          color: widget.clusterPanelActive
              ? Colors.white.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onToggleClusterPanel,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.tune,
                color: widget.clusterPanelActive
                    ? Colors.black87
                    : Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _LayoutButton extends StatelessWidget {
  final ValueChanged<String> onLayout;
  const _LayoutButton({required this.onLayout});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '레이아웃 저장/불러오기',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.save_outlined, color: Colors.white, size: 20),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: onLayout,
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'save',
              child: Row(children: [
                Icon(Icons.save_outlined, size: 18),
                SizedBox(width: 8),
                Text('현재 레이아웃 저장'),
              ]),
            ),
            PopupMenuItem(
              value: 'load',
              child: Row(children: [
                Icon(Icons.folder_open_outlined, size: 18),
                SizedBox(width: 8),
                Text('저장된 레이아웃 불러오기'),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintButton extends StatelessWidget {
  final ValueChanged<String> onPrint;
  const _PrintButton({required this.onPrint});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '출력',
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.print_outlined, color: Colors.white, size: 20),
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onSelected: onPrint,
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'png',
              child: Row(children: [
                Icon(Icons.image_outlined, size: 18),
                SizedBox(width: 8),
                Text('PNG 이미지로 저장'),
              ]),
            ),
            const PopupMenuItem(
              value: 'pdf',
              child: Row(children: [
                Icon(Icons.picture_as_pdf_outlined, size: 18),
                SizedBox(width: 8),
                Text('PDF로 인쇄/저장'),
              ]),
            ),
          ],
        ),
      ),
    );
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
