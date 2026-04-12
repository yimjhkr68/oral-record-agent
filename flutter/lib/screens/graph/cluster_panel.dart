import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../providers/graph_provider.dart';
import '../../services/graph_color_settings.dart';
import '../../services/graph_visibility_settings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/graph/graph_node_model.dart';
import '../../widgets/graph/cluster_detector.dart';

/// 우측 범주 관리 패널 (280px)
class ClusterPanel extends ConsumerStatefulWidget {
  final VoidCallback onClose;
  const ClusterPanel({super.key, required this.onClose});

  @override
  ConsumerState<ClusterPanel> createState() => _ClusterPanelState();
}

class _ClusterPanelState extends ConsumerState<ClusterPanel> {
  List<Map<String, dynamic>> _customRaw = [];

  @override
  void initState() {
    super.initState();
    _loadCustomClusters();
  }

  Future<void> _loadCustomClusters() async {
    try {
      final resp =
          await ref.read(apiClientProvider).get('/api/graph/custom-clusters');
      final data = resp.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _customRaw =
              List<Map<String, dynamic>>.from(data['clusters'] as List? ?? []);
        });
      }
    } catch (_) {}
  }

  // ── 전체 토글 ──────────────────────────────────────────────────────────────

  Future<void> _toggleAll(List<NarratorCluster> allClusters) async {
    final anyHidden =
        allClusters.any((c) => !GraphVisibilitySettings.isVisible(c.narratorId));
    for (final cluster in allClusters) {
      await GraphVisibilitySettings.setVisible(cluster.narratorId, anyHidden);
    }
    ref.read(graphProvider.notifier).applyVisibility();
    setState(() {});
  }

  // ── 사용자 정의 범주 생성 ──────────────────────────────────────────────────

  void _showCreateClusterDialog() {
    final nameCtrl = TextEditingController();
    Color selectedColor = const Color(0xFF5C6385);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('새 범주 만들기', style: AppTypography.heading2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '범주 이름',
                  hintText: '예: 제주 4.3 사건 관련',
                ),
              ),
              const SizedBox(height: 16),
              Text('범주 색상', style: AppTypography.caption),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _colorPalette.map((c) => GestureDetector(
                  onTap: () => setDs(() => selectedColor = c),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: selectedColor == c
                          ? Border.all(color: Colors.white, width: 2.5)
                          : Border.all(
                              color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                '범주를 만든 후 [···] 메뉴에서\n노드를 추가할 수 있습니다.',
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();
                await _createCluster(name, selectedColor);
              },
              child: const Text('만들기'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCluster(String name, Color color) async {
    final hex =
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    try {
      await ref
          .read(apiClientProvider)
          .post('/api/graph/custom-clusters', data: {'name': name, 'color': hex});
      await _loadCustomClusters();
    } catch (_) {}
  }

  // ── 이름 변경 ──────────────────────────────────────────────────────────────

  void _showRenameDialog(String clusterId, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('이름 변경', style: AppTypography.heading2),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(labelText: '새 범주 이름'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              try {
                await ref.read(apiClientProvider).patch(
                    '/api/graph/custom-clusters/$clusterId',
                    data: {'name': name});
                await _loadCustomClusters();
              } catch (_) {}
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  // ── 색상 변경 ──────────────────────────────────────────────────────────────

  void _showCustomColorDialog(String clusterId, Color current) {
    showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('색상 변경', style: AppTypography.heading2),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _colorPalette.map((c) => GestureDetector(
            onTap: () => Navigator.of(ctx).pop(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: c == current
                    ? Border.all(color: AppColors.textPrimary, width: 3)
                    : null,
              ),
            ),
          )).toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
        ],
      ),
    ).then((color) async {
      if (color == null) return;
      final hex =
          '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      try {
        await ref.read(apiClientProvider).patch(
            '/api/graph/custom-clusters/$clusterId',
            data: {'color': hex});
        await _loadCustomClusters();
      } catch (_) {}
    });
  }

  // ── 범주 삭제 확인 ─────────────────────────────────────────────────────────

  void _confirmDeleteCluster(String clusterId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('범주 삭제', style: AppTypography.heading2),
        content: Text(
          '"$name" 범주를 삭제하면\n소속 노드는 자동 범주로 복원됩니다.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await ref.read(apiClientProvider).delete(
                    '/api/graph/custom-clusters/$clusterId');
                await _loadCustomClusters();
                ref.read(graphProvider.notifier).reloadClusters();
              } catch (_) {}
            },
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 노드 추가 다이얼로그 ────────────────────────────────────────────────────

  void _showAddNodesDialog(String clusterId) {
    final gs = ref.read(graphProvider);
    final allNodes = gs.nodes;
    String searchQuery = '';
    final selected = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          final filtered = searchQuery.isEmpty
              ? allNodes
              : allNodes
                  .where((n) =>
                      n.id.toLowerCase().contains(searchQuery.toLowerCase()))
                  .toList();
          return AlertDialog(
            title: Text('노드 추가', style: AppTypography.heading2),
            content: SizedBox(
              width: 360,
              height: 380,
              child: Column(children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: '노드 검색...',
                    prefixIcon: Icon(Icons.search, size: 16),
                    isDense: true,
                  ),
                  onChanged: (v) => setDs(() => searchQuery = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final node = filtered[i];
                      return CheckboxListTile(
                        dense: true,
                        value: selected.contains(node.id),
                        onChanged: (v) => setDs(() {
                          if (v == true) {
                            selected.add(node.id);
                          } else {
                            selected.remove(node.id);
                          }
                        }),
                        title: Text(node.id,
                            style: AppTypography.body
                                .copyWith(fontSize: 13)),
                        subtitle: Text(node.type,
                            style: AppTypography.caption),
                      );
                    },
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('취소')),
              ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        Navigator.of(ctx).pop();
                        await _addNodesToCluster(
                            clusterId, selected.toList());
                      },
                child: Text('${selected.length}개 추가'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addNodesToCluster(
      String clusterId, List<String> nodeIds) async {
    try {
      await ref
          .read(apiClientProvider)
          .post('/api/graph/custom-clusters/$clusterId/nodes',
              data: {'node_ids': nodeIds});
      await _loadCustomClusters();
      ref.read(graphProvider.notifier).reloadClusters();
    } catch (_) {}
  }

  // ── 노드 이동 바텀시트 ──────────────────────────────────────────────────────

  void _showMoveNodeMenu(
      String nodeId, String currentClusterId, List<NarratorCluster> all) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            title: Text('노드 이동: $nodeId',
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text('이동할 범주를 선택하세요',
                style: AppTypography.caption),
          ),
          const Divider(height: 1),
          // 다른 모든 범주
          ...all
              .where((c) => c.narratorId != currentClusterId)
              .map((cluster) => ListTile(
                    leading: CircleAvatar(
                      radius: 8,
                      backgroundColor: cluster.color.withValues(alpha: 1.0),
                    ),
                    title: Text(cluster.displayName,
                        style: AppTypography.body),
                    subtitle: Text('${cluster.nodeIds.length}개 노드',
                        style: AppTypography.caption),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await _moveNode(nodeId, currentClusterId, cluster);
                    },
                  )),
          // 자동 범주로 복원 (custom에서만)
          if (currentClusterId.startsWith('custom-')) ...[
            const Divider(height: 1),
            ListTile(
              leading:
                  const Icon(Icons.undo, size: 18, color: AppColors.textMuted),
              title: const Text('자동 범주로 복원'),
              onTap: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(apiClientProvider).delete(
                      '/api/graph/custom-clusters/$currentClusterId/nodes',
                      data: {'node_ids': [nodeId]});
                  await _loadCustomClusters();
                  ref.read(graphProvider.notifier).reloadClusters();
                } catch (_) {}
              },
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _moveNode(
      String nodeId, String fromId, NarratorCluster toCluster) async {
    try {
      if (toCluster.isCustom) {
        // custom 범주로 이동
        await ref.read(apiClientProvider).post(
            '/api/graph/custom-clusters/${toCluster.narratorId}/nodes',
            data: {'node_ids': [nodeId]});
      } else {
        // 자동 범주로 이동 = custom override 제거
        if (fromId.startsWith('custom-')) {
          await ref.read(apiClientProvider).delete(
              '/api/graph/custom-clusters/$fromId/nodes',
              data: {'node_ids': [nodeId]});
        }
      }
      await _loadCustomClusters();
      ref.read(graphProvider.notifier).reloadClusters();
    } catch (_) {}
  }

  // ── 클래스 편집 (자동 범주용) ───────────────────────────────────────────────

  void _showClassEditDialog(String className) {
    final currentColor = GraphColorSettings.colorFor(className);
    Color pickedColor = currentColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('클래스 편집: $className',
              style: AppTypography.heading2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('색상', style: AppTypography.body),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final color = await _pickColor(ctx, pickedColor);
                    if (color != null) setDs(() => pickedColor = color);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: pickedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                  ),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await GraphColorSettings.setColor(className, pickedColor);
                ref.read(graphProvider.notifier).applyColorSettings();
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext ctx, Color current) {
    return showDialog<Color>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('색상 선택'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _colorPalette
              .map((c) => GestureDetector(
                    onTap: () => Navigator.of(dCtx).pop(c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: c == current
                            ? Border.all(
                                color: AppColors.textPrimary, width: 3)
                            : null,
                      ),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('취소')),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(graphProvider);

    // gs.clusters 에는 reloadClusters() 후 custom + auto 모두 포함됨.
    // _customRaw 는 패널 자체 액션(이름·색상 등)에만 사용하고,
    // 목록 표시는 gs.clusters 기준으로만 구성 — 중복 방지.
    final customClusters =
        _customRaw.map(NarratorCluster.fromCustomJson).toList();
    final autoClusters =
        gs.clusters.where((c) => !c.isCustom).toList();
    final allClusters = [...customClusters, ...autoClusters];

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(children: [
        // ── 헤더 ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            const Icon(Icons.layers_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('범주 관리', style: AppTypography.heading2),
            const Spacer(),
            TextButton(
              onPressed: () => _toggleAll(allClusters),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: Text('전체',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
            // 새 범주 만들기 버튼
            Tooltip(
              message: '새 범주 만들기',
              child: IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    size: 18, color: AppColors.primary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _showCreateClusterDialog,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close,
                  size: 18, color: AppColors.textMuted),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '닫기',
              onPressed: widget.onClose,
            ),
          ]),
        ),

        // ── 범주 목록 ─────────────────────────────────────────────────────
        Expanded(
          child: allClusters.isEmpty
              ? Center(
                  child: Text('범주 없음', style: AppTypography.caption))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: allClusters.length,
                  itemBuilder: (_, i) {
                    final cluster = allClusters[i];
                    final visible = GraphVisibilitySettings.isVisible(
                        cluster.narratorId);
                    return _ClusterTile(
                      cluster: cluster,
                      visible: visible,
                      nodes: gs.nodes,
                      allClusters: allClusters,
                      onVisibilityChanged: (v) async {
                        await GraphVisibilitySettings.setVisible(
                            cluster.narratorId, v);
                        ref
                            .read(graphProvider.notifier)
                            .applyVisibility();
                        setState(() {});
                      },
                      onClassEdit: (className) =>
                          _showClassEditDialog(className),
                      onAddNodes: () =>
                          _showAddNodesDialog(cluster.narratorId),
                      onRename: () => _showRenameDialog(
                          cluster.narratorId, cluster.displayName),
                      onChangeColor: () => _showCustomColorDialog(
                          cluster.narratorId, cluster.color),
                      onDelete: () => _confirmDeleteCluster(
                          cluster.narratorId, cluster.displayName),
                      onMoveNode: (nodeId) => _showMoveNodeMenu(
                          nodeId, cluster.narratorId, allClusters),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ── 온톨로지 클래스 한글 레이블 ──────────────────────────────────────────────────

const _kClassLabelKo = <String, String>{
  'OralHistoryNarrator':    '구술자',
  'Interviewer':            '면담자',
  'Victim':                 '희생자',
  'SurvivorFamily':         '유가족 / 생존 가족',
  'MilitaryUnit':           '군·경 부대 / 무장 세력',
  'HistoricalMassacreEvent':'집단 학살 사건',
  'HistoricalPeriod':       '역사적 시기',
  'DeathEvent':             '사망 / 희생',
  'Place':                  '장소',
  'OralHistoryRecord':      '구술 기록',
  'InterviewSession':       '면담 세션',
  'CommemorativeAct':       '추모 / 제례 행위',
  'SocialStigma':           '사회적 낙인 / 연좌제 피해',
  'StateRecognition':       '국가 공인 / 명예 회복',
  'Archive':                '아카이브 / 컬렉션',
};

/// className에 해당하는 표시 이름: "한글명 (ClassName)" 또는 "ClassName"
String _classDisplayName(String className) {
  final ko = _kClassLabelKo[className];
  return ko != null ? '$ko ($className)' : className;
}

// ── 색상 팔레트 ────────────────────────────────────────────────────────────────

const _colorPalette = [
  Color(0xFFEF4444), Color(0xFFF97316), Color(0xFFF59E0B),
  Color(0xFF84CC16), Color(0xFF22C55E), Color(0xFF10B981),
  Color(0xFF14B8A6), Color(0xFF06B6D4), Color(0xFF3B82F6),
  Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFEC4899),
  Color(0xFF880E4F), Color(0xFF2E7D32), Color(0xFF1565C0),
  Color(0xFF64748B), Color(0xFF78716C), Color(0xFF1E293B),
];

// ── 범주 타일 ──────────────────────────────────────────────────────────────────

class _ClusterTile extends StatefulWidget {
  final NarratorCluster cluster;
  final bool visible;
  final List<LayoutNode> nodes;
  final List<NarratorCluster> allClusters;
  final ValueChanged<bool> onVisibilityChanged;
  final ValueChanged<String> onClassEdit;
  final VoidCallback onAddNodes;
  final VoidCallback onRename;
  final VoidCallback onChangeColor;
  final VoidCallback onDelete;
  final ValueChanged<String> onMoveNode;

  const _ClusterTile({
    required this.cluster,
    required this.visible,
    required this.nodes,
    required this.allClusters,
    required this.onVisibilityChanged,
    required this.onClassEdit,
    required this.onAddNodes,
    required this.onRename,
    required this.onChangeColor,
    required this.onDelete,
    required this.onMoveNode,
  });

  @override
  State<_ClusterTile> createState() => _ClusterTileState();
}

class _ClusterTileState extends State<_ClusterTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cluster = widget.cluster;
    final clusterNodes = widget.nodes
        .where((n) => cluster.nodeIds.contains(n.id))
        .toList();

    final byClass = <String, List<String>>{};
    for (final n in clusterNodes) {
      (byClass[n.type] ??= []).add(n.id);
    }

    // 배경 색상 (불투명 버전)
    final clusterColor = cluster.color.withValues(alpha: 1.0);

    return Column(children: [
      // ── 범주 헤더 ──────────────────────────────────────────────────────
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.visible
                ? clusterColor.withValues(alpha: 0.12)
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.visible
                  ? clusterColor.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(children: [
            // 표시/숨김 토글
            GestureDetector(
              onTap: () =>
                  widget.onVisibilityChanged(!widget.visible),
              child: Icon(
                widget.visible
                    ? Icons.visibility
                    : Icons.visibility_off,
                size: 16,
                color: widget.visible
                    ? AppColors.primary
                    : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            // 범주명
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cluster.displayName,
                    style: AppTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: widget.visible
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (cluster.isCustom)
                    Text('사용자 정의',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.primary, fontSize: 10)),
                ],
              ),
            ),
            // 노드 수
            Text('${clusterNodes.length}개',
                style: AppTypography.caption),
            const SizedBox(width: 4),

            // 사용자 정의: 팝업 메뉴 / 자동: 접기 아이콘
            if (cluster.isCustom)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 16, color: AppColors.textMuted),
                iconSize: 16,
                padding: EdgeInsets.zero,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onSelected: (v) {
                  if (v == 'add') widget.onAddNodes();
                  if (v == 'rename') widget.onRename();
                  if (v == 'color') widget.onChangeColor();
                  if (v == 'delete') widget.onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: Row(children: [
                      Icon(Icons.add, size: 16),
                      SizedBox(width: 8),
                      Text('노드 추가'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('이름 변경'),
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'color',
                    child: Row(children: [
                      Icon(Icons.palette_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('색상 변경'),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('범주 삭제',
                          style: TextStyle(color: Colors.red)),
                    ]),
                  ),
                ],
              )
            else
              Icon(
                _expanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 16,
                color: AppColors.textMuted,
              ),
          ]),
        ),
      ),

      // ── 클래스/노드 목록 (펼침 시) ──────────────────────────────────────
      if (_expanded)
        Container(
          margin:
              const EdgeInsets.only(left: 12, top: 2, bottom: 2),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: clusterColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          // 자동·사용자 정의 범주 모두 동일한 _ClassRow 형식으로 표시
          child: byClass.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text('노드 없음',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                )
              : Column(
                  children: byClass.entries
                      .map((entry) => _ClassRow(
                            className: entry.key,
                            nodeCount: entry.value.length,
                            nodeIds: entry.value,
                            color: GraphColorSettings.colorFor(entry.key),
                            onEdit: () =>
                                widget.onClassEdit(entry.key),
                            onMoveNode: widget.onMoveNode,
                          ))
                      .toList(),
                ),
        ),

      const SizedBox(height: 4),
    ]);
  }
}

// ── 클래스 행 ─────────────────────────────────────────────────────────────────

class _ClassRow extends StatefulWidget {
  final String className;
  final int nodeCount;
  final List<String> nodeIds;
  final Color color;
  final VoidCallback onEdit;
  final ValueChanged<String> onMoveNode;

  const _ClassRow({
    required this.className,
    required this.nodeCount,
    required this.nodeIds,
    required this.color,
    required this.onEdit,
    required this.onMoveNode,
  });

  @override
  State<_ClassRow> createState() => _ClassRowState();
}

class _ClassRowState extends State<_ClassRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 클래스 헤더 (탭 → 노드 목록 펼침)
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          onLongPress: widget.onEdit,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
            child: Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_classDisplayName(widget.className),
                    style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary)),
              ),
              Text('${widget.nodeCount}',
                  style: AppTypography.caption
                      .copyWith(fontFamily: 'monospace')),
              const SizedBox(width: 4),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 12,
                color: AppColors.textMuted,
              ),
            ]),
          ),
        ),
        // 노드 목록 (펼침 시)
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(left: 18, bottom: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.nodeIds
                  .map((nid) => GestureDetector(
                        onLongPress: () => widget.onMoveNode(nid),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(children: [
                            Expanded(
                              child: Text(nid,
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.textMuted,
                                      fontSize: 10),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            const Icon(Icons.open_with,
                                size: 10, color: AppColors.textMuted),
                          ]),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
