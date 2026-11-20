import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart' hide Dialog;
import 'package:flutter_hbb/models/key_mapping_model.dart';
import 'package:flutter_hbb/models/model.dart';

Future<void> showBbsKeyMappingDialog(BuildContext context, {FFI? ffi}) async {
  BbsKeyMappingCenter.instance.ensureInitialized();
  await showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              width: 920,
              height: 680,
              decoration: BoxDecoration(
                color: Theme.of(ctx).brightness == Brightness.dark
                    ? const Color(0xFF0F172A).withOpacity(0.88)
                    : Colors.white.withOpacity(0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.24),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.32),
                    blurRadius: 36,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.keyboard_command_key_rounded,
                            color: Color(0xFF38BDF8), size: 22),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'BBS-Remote 按键映射中心 (Mac ⇄ Windows 双向实时生效)',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          tooltip: '关闭',
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Expanded(
                    child: BbsKeyMappingView(compactHeader: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class BbsKeyMappingView extends StatefulWidget {
  final bool compactHeader;

  const BbsKeyMappingView({Key? key, this.compactHeader = false})
      : super(key: key);

  @override
  State<BbsKeyMappingView> createState() => _BbsKeyMappingViewState();
}

class _BbsKeyMappingViewState extends State<BbsKeyMappingView> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _categoryFilter = 'all'; // all | system | office | creative | gaming | custom
  String _peerFilter = 'all'; // all | windows | macos | enabled

  @override
  void initState() {
    super.initState();
    BbsKeyMappingCenter.instance.ensureInitialized();
    BbsKeyMappingCenter.instance.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    BbsKeyMappingCenter.instance.removeListener(_onModelChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onModelChanged() {
    if (mounted) setState(() {});
  }

  List<BbsKeyMapEntry> _filteredEntries() {
    final center = BbsKeyMappingCenter.instance;
    final q = _query.trim().toLowerCase();
    return center.allEntries.where((e) {
      if (_categoryFilter != 'all' && e.category != _categoryFilter) {
        return false;
      }
      if (_peerFilter == 'windows' &&
          e.peer != 'windows' &&
          e.peer != 'all') {
        return false;
      }
      if (_peerFilter == 'macos' && e.peer != 'macos' && e.peer != 'all') {
        return false;
      }
      if (_peerFilter == 'enabled' && !center.isRuleEnabled(e.id)) {
        return false;
      }
      if (q.isNotEmpty) {
        final hay =
            '${e.name} ${e.desc} ${e.subGroup} ${e.srcDisplay} ${e.dstDisplay}'
                .toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _openCreateCustomDialog() async {
    final nameCtrl = TextEditingController();
    String peer = 'all';
    String srcKey = 'c';
    bool srcCtrl = false;
    bool srcAlt = true;
    bool srcShift = false;
    bool srcMeta = false;

    String dstKey = 'c';
    bool dstCtrl = true;
    bool dstAlt = false;
    bool dstShift = false;
    bool dstMeta = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              backgroundColor:
                  isDark ? const Color(0xFF151E31) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('新增自定义按键映射',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: '映射名称 (例如: 一键连招 / 快捷复制)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('生效远端系统',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final (val, label) in [
                            ('all', 'Mac & Windows 通用'),
                            ('windows', '仅远端 Windows'),
                            ('macos', '仅远端 macOS'),
                          ])
                            ChoiceChip(
                              label: Text(label),
                              selected: peer == val,
                              onSelected: (_) =>
                                  setModalState(() => peer = val),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('当本机按下 (触发键位)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('⌘ Cmd / Win'),
                            selected: srcMeta,
                            onSelected: (v) =>
                                setModalState(() => srcMeta = v),
                          ),
                          FilterChip(
                            label: const Text('⌃ Ctrl'),
                            selected: srcCtrl,
                            onSelected: (v) =>
                                setModalState(() => srcCtrl = v),
                          ),
                          FilterChip(
                            label: const Text('⌥ Opt / Alt'),
                            selected: srcAlt,
                            onSelected: (v) => setModalState(() => srcAlt = v),
                          ),
                          FilterChip(
                            label: const Text('⇧ Shift'),
                            selected: srcShift,
                            onSelected: (v) =>
                                setModalState(() => srcShift = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: srcKey,
                        decoration: InputDecoration(
                          labelText: '本机主键',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: kBbsAllKeys
                            .where((k) =>
                                k.code != 'ctrl_alt_del' &&
                                k.code != 'lock_screen' &&
                                k.code != 'shift' &&
                                k.code != 'ctrl' &&
                                k.code != 'alt' &&
                                k.code != 'meta')
                            .map((k) => DropdownMenuItem(
                                  value: k.code,
                                  child: Text(k.label),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => srcKey = v);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('发送至远端电脑 (目标键位)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Ctrl'),
                            selected: dstCtrl,
                            onSelected: (v) =>
                                setModalState(() => dstCtrl = v),
                          ),
                          FilterChip(
                            label: const Text('Win / ⌘ Cmd'),
                            selected: dstMeta,
                            onSelected: (v) =>
                                setModalState(() => dstMeta = v),
                          ),
                          FilterChip(
                            label: const Text('Alt / ⌥ Opt'),
                            selected: dstAlt,
                            onSelected: (v) => setModalState(() => dstAlt = v),
                          ),
                          FilterChip(
                            label: const Text('Shift'),
                            selected: dstShift,
                            onSelected: (v) =>
                                setModalState(() => dstShift = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: dstKey,
                        decoration: InputDecoration(
                          labelText: '远端目标按键/动作',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          isDense: true,
                        ),
                        items: kBbsAllKeys
                            .map((k) => DropdownMenuItem(
                                  value: k.code,
                                  child: Text(k.label),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setModalState(() => dstKey = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await BbsKeyMappingCenter.instance.addCustomRule(
                      name: nameCtrl.text,
                      peer: peer,
                      srcKey: srcKey,
                      srcCtrl: srcCtrl,
                      srcAlt: srcAlt,
                      srcShift: srcShift,
                      srcMeta: srcMeta,
                      dstKey: dstKey,
                      dstCtrl: dstCtrl,
                      dstAlt: dstAlt,
                      dstShift: dstShift,
                      dstMeta: dstMeta,
                    );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    showToast('已添加自定义按键映射并实时生效');
                  },
                  child: const Text('保存并启用'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = BbsKeyMappingCenter.instance;
    final entries = _filteredEntries();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final glassBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.white.withOpacity(0.75);
    final glassBorder = isDark
        ? Colors.white.withOpacity(0.11)
        : const Color(0xFFCBD5E1).withOpacity(0.75);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, widget.compactHeader ? 14 : 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.compactHeader) ...[
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '按键映射中心',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '内置 540+ 项 Mac ⇄ Windows 系统、办公、设计编程与电竞游戏键位映射，支持自定义新增',
                        style:
                            TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openCreateCustomDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('新增自定义映射',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          // Master glass banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: glassBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: glassBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全局按键映射引擎 · 共内置 ${center.totalCount} 项规则 (当前已启用 ${center.enabledCount} 项)',
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '远程会话中实时拦截转换，自动匹配远端 Mac / Windows 系统，零卡键无延迟',
                        style: TextStyle(fontSize: 12, color: subColor),
                      ),
                    ],
                  ),
                ),
                if (widget.compactHeader) ...[
                  OutlinedButton.icon(
                    onPressed: _openCreateCustomDialog,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('自定义映射'),
                  ),
                  const SizedBox(width: 10),
                ],
                Switch.adaptive(
                  value: center.masterEnabled,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (v) => center.setMasterEnabled(v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Scene presets row
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kBbsKeyPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, idx) {
                final preset = kBbsKeyPresets[idx];
                final active = center.activePreset == preset.id;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    center.applyPreset(preset.id);
                    showToast('已切换预设方案：${preset.name}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: active
                          ? const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)])
                          : null,
                      color: active ? null : glassBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: active ? Colors.transparent : glassBorder),
                    ),
                    child: Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? Colors.white : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Search + Category + OS filters
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          '搜索 540+ 快捷键 (如: 复制、截图、VS Code、PS、Blender、原神、FPS、LOL...)',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: glassBg,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: glassBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: glassBorder),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              for (final (catId, catLabel) in [
                ('all', '全部 (${center.totalCount})'),
                ('system', '系统互转'),
                ('office', '办公/浏览器'),
                ('creative', '开发/设计/3D'),
                ('gaming', '电竞/游戏'),
                if (center.customEntries.isNotEmpty)
                  ('custom', '自定义 (${center.customEntries.length})'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(catLabel,
                        style: const TextStyle(fontSize: 11.5)),
                    selected: _categoryFilter == catId,
                    onSelected: (_) =>
                        setState(() => _categoryFilter = catId),
                  ),
                ),
              DropdownButton<String>(
                value: _peerFilter,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部系统')),
                  DropdownMenuItem(value: 'windows', child: Text('远端 Win')),
                  DropdownMenuItem(value: 'macos', child: Text('远端 Mac')),
                  DropdownMenuItem(value: 'enabled', child: Text('仅已启用')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _peerFilter = v);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Virtualized rule list
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text('未找到匹配的按键映射规则',
                        style: TextStyle(color: subColor)),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = entries[index];
                      final enabled = center.isRuleEnabled(item.id);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: glassBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: enabled
                                ? const Color(0xFF38BDF8).withOpacity(0.35)
                                : glassBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0EA5E9)
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.directionBadge,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF38BDF8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          item.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.subGroup} · ${item.desc}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5, color: subColor),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildKeycapPill(item.srcDisplay, isDark),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: Color(0xFF38BDF8)),
                            ),
                            _buildKeycapPill(item.dstDisplay, isDark,
                                highlight: true),
                            const SizedBox(width: 12),
                            if (item.isCustom)
                              IconButton(
                                tooltip: '删除自定义规则',
                                onPressed: () =>
                                    center.deleteCustomRule(item.id),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 18, color: Colors.redAccent),
                              ),
                            Switch.adaptive(
                              value: enabled,
                              activeColor: const Color(0xFF38BDF8),
                              onChanged: (v) =>
                                  center.toggleRule(item.id, v),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeycapPill(String label, bool isDark, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFF0EA5E9).withOpacity(0.14)
            : (isDark
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? const Color(0xFF38BDF8).withOpacity(0.45)
              : Colors.white.withOpacity(0.14),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w700,
          color: highlight ? const Color(0xFF38BDF8) : null,
        ),
      ),
    );
  }
}
