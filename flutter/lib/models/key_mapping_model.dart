import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_hbb/common.dart';

class BbsKeyOption {
  final String code;
  final String label;
  final String macLabel;
  final String winLabel;

  const BbsKeyOption(this.code, this.label,
      {String? macLabel, String? winLabel})
      : macLabel = macLabel ?? label,
        winLabel = winLabel ?? label;
}

const List<BbsKeyOption> kBbsAllKeys = [
  // Letters A-Z
  BbsKeyOption('a', 'A'),
  BbsKeyOption('b', 'B'),
  BbsKeyOption('c', 'C'),
  BbsKeyOption('d', 'D'),
  BbsKeyOption('e', 'E'),
  BbsKeyOption('f', 'F'),
  BbsKeyOption('g', 'G'),
  BbsKeyOption('h', 'H'),
  BbsKeyOption('i', 'I'),
  BbsKeyOption('j', 'J'),
  BbsKeyOption('k', 'K'),
  BbsKeyOption('l', 'L'),
  BbsKeyOption('m', 'M'),
  BbsKeyOption('n', 'N'),
  BbsKeyOption('o', 'O'),
  BbsKeyOption('p', 'P'),
  BbsKeyOption('q', 'Q'),
  BbsKeyOption('r', 'R'),
  BbsKeyOption('s', 'S'),
  BbsKeyOption('t', 'T'),
  BbsKeyOption('u', 'U'),
  BbsKeyOption('v', 'V'),
  BbsKeyOption('w', 'W'),
  BbsKeyOption('x', 'X'),
  BbsKeyOption('y', 'Y'),
  BbsKeyOption('z', 'Z'),
  // Top row digits
  BbsKeyOption('digit0', '0'),
  BbsKeyOption('digit1', '1'),
  BbsKeyOption('digit2', '2'),
  BbsKeyOption('digit3', '3'),
  BbsKeyOption('digit4', '4'),
  BbsKeyOption('digit5', '5'),
  BbsKeyOption('digit6', '6'),
  BbsKeyOption('digit7', '7'),
  BbsKeyOption('digit8', '8'),
  BbsKeyOption('digit9', '9'),
  // Function keys
  BbsKeyOption('f1', 'F1'),
  BbsKeyOption('f2', 'F2'),
  BbsKeyOption('f3', 'F3'),
  BbsKeyOption('f4', 'F4'),
  BbsKeyOption('f5', 'F5'),
  BbsKeyOption('f6', 'F6'),
  BbsKeyOption('f7', 'F7'),
  BbsKeyOption('f8', 'F8'),
  BbsKeyOption('f9', 'F9'),
  BbsKeyOption('f10', 'F10'),
  BbsKeyOption('f11', 'F11'),
  BbsKeyOption('f12', 'F12'),
  // Core control & navigation
  BbsKeyOption('space', 'Space 空格'),
  BbsKeyOption('tab', 'Tab'),
  BbsKeyOption('enter', 'Enter 回车', macLabel: 'Return'),
  BbsKeyOption('escape', 'Esc'),
  BbsKeyOption('backspace', 'Backspace 退格', macLabel: '⌫ Delete'),
  BbsKeyOption('delete', 'Delete 向后删', macLabel: '⌦ Fn+Del'),
  BbsKeyOption('caps_lock', 'CapsLock 大写锁'),
  BbsKeyOption('arrow_left', '← 左方向'),
  BbsKeyOption('arrow_right', '→ 右方向'),
  BbsKeyOption('arrow_up', '↑ 上方向'),
  BbsKeyOption('arrow_down', '↓ 下方向'),
  BbsKeyOption('home', 'Home 行首'),
  BbsKeyOption('end', 'End 行尾'),
  BbsKeyOption('page_up', 'PageUp 上翻页'),
  BbsKeyOption('page_down', 'PageDown 下翻页'),
  BbsKeyOption('insert', 'Insert'),
  BbsKeyOption('print_screen', 'PrintScreen 截屏'),
  BbsKeyOption('num_lock', 'NumLock 数字锁'),
  BbsKeyOption('scroll_lock', 'ScrollLock'),
  BbsKeyOption('pause', 'Pause/Break'),
  // Punctuation
  BbsKeyOption('backquote', '` 波浪键'),
  BbsKeyOption('minus', '- 减号'),
  BbsKeyOption('equal', '= 等号'),
  BbsKeyOption('bracket_left', '[ 左括号'),
  BbsKeyOption('bracket_right', '] 右括号'),
  BbsKeyOption('backslash', '\\ 反斜杠'),
  BbsKeyOption('semicolon', '; 分号'),
  BbsKeyOption('quote', '\' 引号'),
  BbsKeyOption('comma', ', 逗号'),
  BbsKeyOption('period', '. 句号'),
  BbsKeyOption('slash', '/ 斜杠'),
  // Numpad
  BbsKeyOption('kp_0', 'Numpad 0'),
  BbsKeyOption('kp_1', 'Numpad 1'),
  BbsKeyOption('kp_2', 'Numpad 2'),
  BbsKeyOption('kp_3', 'Numpad 3'),
  BbsKeyOption('kp_4', 'Numpad 4'),
  BbsKeyOption('kp_5', 'Numpad 5'),
  BbsKeyOption('kp_6', 'Numpad 6'),
  BbsKeyOption('kp_7', 'Numpad 7'),
  BbsKeyOption('kp_8', 'Numpad 8'),
  BbsKeyOption('kp_9', 'Numpad 9'),
  BbsKeyOption('kp_add', 'Numpad +'),
  BbsKeyOption('kp_subtract', 'Numpad -'),
  BbsKeyOption('kp_multiply', 'Numpad *'),
  BbsKeyOption('kp_divide', 'Numpad /'),
  BbsKeyOption('kp_decimal', 'Numpad .'),
  BbsKeyOption('kp_enter', 'Numpad Enter'),
  // Modifier targets & special OS actions
  BbsKeyOption('shift', 'Shift'),
  BbsKeyOption('ctrl', 'Ctrl'),
  BbsKeyOption('alt', 'Alt / Option'),
  BbsKeyOption('meta', 'Win / Cmd'),
  BbsKeyOption('ctrl_alt_del', 'Ctrl+Alt+Del 安全屏'),
  BbsKeyOption('lock_screen', '系统一键锁屏'),
];

final Map<String, BbsKeyOption> _kKeyLookup = {
  for (final item in kBbsAllKeys) item.code: item,
};

String bbsFormatKeyDisplay(String code, {required bool isMacStyle}) {
  final found = _kKeyLookup[code];
  if (found == null) return code.toUpperCase();
  return isMacStyle ? found.macLabel : found.winLabel;
}

String bbsFormatChordDisplay({
  required String key,
  required bool ctrl,
  required bool alt,
  required bool shift,
  required bool meta,
  required bool isMacStyle,
}) {
  final parts = <String>[];
  if (isMacStyle) {
    if (ctrl) parts.add('⌃ Ctrl');
    if (alt) parts.add('⌥ Opt');
    if (shift) parts.add('⇧ Shift');
    if (meta) parts.add('⌘ Cmd');
  } else {
    if (ctrl) parts.add('Ctrl');
    if (meta) parts.add('Win');
    if (alt) parts.add('Alt');
    if (shift) parts.add('Shift');
  }
  parts.add(bbsFormatKeyDisplay(key, isMacStyle: isMacStyle));
  return parts.join(' + ');
}

class BbsKeyPresetInfo {
  final String id;
  final String name;
  final String subtitle;

  const BbsKeyPresetInfo(this.id, this.name, this.subtitle);
}

const List<BbsKeyPresetInfo> kBbsKeyPresets = [
  BbsKeyPresetInfo('smart_office', '智能跨系统办公 (默认)',
      '自动识别 Mac ⇄ Windows 互转复制粘贴、截图、行首行尾与浏览器快捷键'),
  BbsKeyPresetInfo(
      'dev_pro', '全栈开发与终端', '开启 VS Code / Cursor / IDEA / 终端分屏与调试全套热键'),
  BbsKeyPresetInfo(
      'creative_3d', '设计修图与影视3D', '开启 PS / Figma / PR / Blender 无小键盘视角热键'),
  BbsKeyPresetInfo(
      'fps_esports', 'FPS 射击竞技', 'CS2 / 无畏契约 / Apex 战术静步、探头、投掷物与计分板优化'),
  BbsKeyPresetInfo(
      'open_world', '原神 · 鸣潮开放世界', '元素视野、队伍 1-4 顺手换人、声骸钩锁与大招快捷触发'),
  BbsKeyPresetInfo(
      'moba_arena', 'MOBA 竞技 (LOL/永劫)', '自我施法、主动装备栏顺手映射、商店开关与快捷振刀'),
  BbsKeyPresetInfo(
      'mmo_numpad', 'MMO 网游与小键盘扩展', '无小键盘笔记本全套 Numpad 映射 + 多动作条组合键'),
  BbsKeyPresetInfo('custom_only', '仅保留自定义映射', '关闭内置预设，仅启用你手动添加或单独勾选的规则'),
];

class BbsKeyMapEntry {
  final String id;
  final String name;
  final String desc;
  final String category; // system | office | creative | gaming | custom
  final String subGroup;
  final String srcHost; // mac | win | any
  final String peer; // windows | macos | all
  final String srcKey;
  final bool srcCtrl;
  final bool srcAlt;
  final bool srcShift;
  final bool srcMeta;
  final String dstKey;
  final bool dstCtrl;
  final bool dstAlt;
  final bool dstShift;
  final bool dstMeta;
  final Set<String> presets;
  final bool isCustom;

  const BbsKeyMapEntry({
    required this.id,
    required this.name,
    required this.desc,
    required this.category,
    required this.subGroup,
    required this.srcHost,
    required this.peer,
    required this.srcKey,
    this.srcCtrl = false,
    this.srcAlt = false,
    this.srcShift = false,
    this.srcMeta = false,
    required this.dstKey,
    this.dstCtrl = false,
    this.dstAlt = false,
    this.dstShift = false,
    this.dstMeta = false,
    this.presets = const {},
    this.isCustom = false,
  });

  String get srcDisplay => bbsFormatChordDisplay(
        key: srcKey,
        ctrl: srcCtrl,
        alt: srcAlt,
        shift: srcShift,
        meta: srcMeta,
        isMacStyle: srcHost == 'mac' || (srcHost == 'any' && Platform.isMacOS),
      );

  String get dstDisplay => bbsFormatChordDisplay(
        key: dstKey,
        ctrl: dstCtrl,
        alt: dstAlt,
        shift: dstShift,
        meta: dstMeta,
        isMacStyle: peer == 'macos',
      );

  String get directionBadge {
    if (srcHost == 'mac' && peer == 'windows') return 'Mac → Win';
    if (srcHost == 'win' && peer == 'macos') return 'Win → Mac';
    if (peer == 'windows') return '远端 Win';
    if (peer == 'macos') return '远端 Mac';
    return 'Mac & Win 通用';
  }

  Map<String, dynamic> toRustRuleJson() => {
        'peer': peer,
        'src_key': srcKey,
        'src_ctrl': srcCtrl,
        'src_alt': srcAlt,
        'src_shift': srcShift,
        'src_meta': srcMeta,
        'dst_key': dstKey,
        'dst_ctrl': dstCtrl,
        'dst_alt': dstAlt,
        'dst_shift': dstShift,
        'dst_meta': dstMeta,
      };

  Map<String, dynamic> toUiSummaryJson(bool enabled) => {
        'id': id,
        'name': name,
        'desc': desc,
        'category': category,
        'subGroup': subGroup,
        'direction': directionBadge,
        'peer': peer,
        'srcDisplay': srcDisplay,
        'dstDisplay': dstDisplay,
        'enabled': enabled,
        'isCustom': isCustom,
      };

  Map<String, dynamic> toCustomPersistJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'peer': peer,
        'srcKey': srcKey,
        'srcCtrl': srcCtrl,
        'srcAlt': srcAlt,
        'srcShift': srcShift,
        'srcMeta': srcMeta,
        'dstKey': dstKey,
        'dstCtrl': dstCtrl,
        'dstAlt': dstAlt,
        'dstShift': dstShift,
        'dstMeta': dstMeta,
      };

  factory BbsKeyMapEntry.fromCustomJson(Map<String, dynamic> m) {
    return BbsKeyMapEntry(
      id: m['id']?.toString() ??
          'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: m['name']?.toString() ?? '自定义按键映射',
      desc: m['desc']?.toString() ?? '用户自定义快捷键或键位重映射',
      category: 'custom',
      subGroup: '我的自定义',
      srcHost: 'any',
      peer: m['peer']?.toString() ?? 'all',
      srcKey: m['srcKey']?.toString() ?? 'a',
      srcCtrl: m['srcCtrl'] == true,
      srcAlt: m['srcAlt'] == true,
      srcShift: m['srcShift'] == true,
      srcMeta: m['srcMeta'] == true,
      dstKey: m['dstKey']?.toString() ?? 'a',
      dstCtrl: m['dstCtrl'] == true,
      dstAlt: m['dstAlt'] == true,
      dstShift: m['dstShift'] == true,
      dstMeta: m['dstMeta'] == true,
      isCustom: true,
    );
  }
}

class BbsKeyMappingCenter extends ChangeNotifier {
  static final BbsKeyMappingCenter instance = BbsKeyMappingCenter._();

  static const String _uiStateOptionKey = 'bbs-key-mappings-ui';
  static const String _rustEngineOptionKey = 'bbs-key-mappings';

  bool _initialized = false;
  bool _masterEnabled = true;
  String _activePreset = 'smart_office';
  late final List<BbsKeyMapEntry> _builtinEntries;
  final List<BbsKeyMapEntry> _customEntries = [];
  final Set<String> _enabledIds = {};

  BbsKeyMappingCenter._() {
    _builtinEntries = _buildBuiltinCatalog();
  }

  bool get masterEnabled => _masterEnabled;
  String get activePreset => _activePreset;
  List<BbsKeyMapEntry> get builtinEntries => _builtinEntries;
  List<BbsKeyMapEntry> get customEntries => List.unmodifiable(_customEntries);

  List<BbsKeyMapEntry> get allEntries =>
      [..._customEntries, ..._builtinEntries];

  int get totalCount => _customEntries.length + _builtinEntries.length;
  int get enabledCount => _enabledIds.length;

  bool isRuleEnabled(String id) => _enabledIds.contains(id);

  void ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    try {
      final raw = bind.mainGetLocalOption(key: _uiStateOptionKey);
      if (raw.isNotEmpty) {
        final data = jsonDecode(raw);
        if (data is Map) {
          _masterEnabled = data['masterEnabled'] != false;
          _activePreset = data['activePreset']?.toString() ?? 'smart_office';
          _customEntries.clear();
          if (data['customRules'] is List) {
            for (final item in data['customRules'] as List) {
              if (item is Map) {
                _customEntries.add(BbsKeyMapEntry.fromCustomJson(
                    Map<String, dynamic>.from(item)));
              }
            }
          }
          _enabledIds.clear();
          if (data['enabledIds'] is List) {
            for (final id in data['enabledIds'] as List) {
              _enabledIds.add(id.toString());
            }
          }
          _syncToRustEngine();
          return;
        }
      }
    } catch (_) {}

    // First run: activate smart_office preset out of the box
    _applyPresetInternal('smart_office');
    _persistAndSync();
  }

  void _applyPresetInternal(String presetId) {
    _activePreset = presetId;
    // Preserve enabled custom rules while replacing built-in selection
    final customEnabled = _customEntries
        .map((e) => e.id)
        .where((id) => _enabledIds.contains(id))
        .toSet();
    _enabledIds
      ..clear()
      ..addAll(customEnabled);
    if (presetId != 'custom_only') {
      for (final item in _builtinEntries) {
        if (item.presets.contains(presetId)) {
          _enabledIds.add(item.id);
        }
      }
    }
  }

  Future<void> setMasterEnabled(bool value) async {
    ensureInitialized();
    _masterEnabled = value;
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> applyPreset(String presetId) async {
    ensureInitialized();
    _applyPresetInternal(presetId);
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> toggleRule(String id, bool enabled) async {
    ensureInitialized();
    if (enabled) {
      _enabledIds.add(id);
    } else {
      _enabledIds.remove(id);
    }
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> toggleSubGroup(String subGroup, bool enabled) async {
    ensureInitialized();
    for (final entry in allEntries) {
      if (entry.subGroup == subGroup) {
        if (enabled) {
          _enabledIds.add(entry.id);
        } else {
          _enabledIds.remove(entry.id);
        }
      }
    }
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> addCustomRule({
    required String name,
    required String peer,
    required String srcKey,
    required bool srcCtrl,
    required bool srcAlt,
    required bool srcShift,
    required bool srcMeta,
    required String dstKey,
    required bool dstCtrl,
    required bool dstAlt,
    required bool dstShift,
    required bool dstMeta,
  }) async {
    ensureInitialized();
    final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final entry = BbsKeyMapEntry(
      id: id,
      name: name.trim().isEmpty ? '自定义按键映射' : name.trim(),
      desc: '自定义组合键映射规则',
      category: 'custom',
      subGroup: '我的自定义',
      srcHost: 'any',
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
      isCustom: true,
    );
    _customEntries.insert(0, entry);
    _enabledIds.add(id);
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> deleteCustomRule(String id) async {
    ensureInitialized();
    _customEntries.removeWhere((e) => e.id == id);
    _enabledIds.remove(id);
    await _persistAndSync();
    notifyListeners();
  }

  Future<void> _persistAndSync() async {
    final uiPayload = jsonEncode({
      'masterEnabled': _masterEnabled,
      'activePreset': _activePreset,
      'enabledIds': _enabledIds.toList(growable: false),
      'customRules':
          _customEntries.map((e) => e.toCustomPersistJson()).toList(),
    });
    await bind.mainSetLocalOption(key: _uiStateOptionKey, value: uiPayload);
    await _syncToRustEngine();
  }

  Future<void> _syncToRustEngine() async {
    final isLocalMac = Platform.isMacOS;
    final isLocalWin = Platform.isWindows;
    final activeRules = <Map<String, dynamic>>[];

    // Custom rules always take highest priority first
    for (final entry in allEntries) {
      if (!_enabledIds.contains(entry.id)) continue;
      if (entry.srcHost == 'mac' && !isLocalMac) continue;
      if (entry.srcHost == 'win' && !isLocalWin) continue;
      activeRules.add(entry.toRustRuleJson());
    }

    final enginePayload = jsonEncode({
      'enabled': _masterEnabled,
      'rules': activeRules,
    });
    await bind.mainSetLocalOption(
        key: _rustEngineOptionKey, value: enginePayload);
    try {
      bind.mainReloadKeyboardShortcuts();
    } catch (_) {}
  }

  static List<BbsKeyMapEntry> _buildBuiltinCatalog() {
    final list = <BbsKeyMapEntry>[];
    const corePresets = {'smart_office', 'dev_pro', 'creative_3d'};

    // =========================================================================
    // 1. Mac ⇄ Windows 系统核心与文本编辑互转 (108 条)
    // =========================================================================
    const macToWinCoreLetters = <(String, String, String)>[
      ('c', '复制 (Copy)', 'Mac ⌘C 自动转为远端 Windows Ctrl+C'),
      ('v', '粘贴 (Paste)', 'Mac ⌘V 自动转为远端 Windows Ctrl+V'),
      ('x', '剪切 (Cut)', 'Mac ⌘X 自动转为远端 Windows Ctrl+X'),
      ('a', '全选 (Select All)', 'Mac ⌘A 自动转为远端 Windows Ctrl+A'),
      ('z', '撤销 (Undo)', 'Mac ⌘Z 自动转为远端 Windows Ctrl+Z'),
      ('y', '重做 (Redo)', 'Mac ⌘Y 自动转为远端 Windows Ctrl+Y'),
      ('s', '保存文件 (Save)', 'Mac ⌘S 自动转为远端 Windows Ctrl+S'),
      ('f', '查找内容 (Find)', 'Mac ⌘F 自动转为远端 Windows Ctrl+F'),
      ('g', '查找下一个', 'Mac ⌘G 自动转为远端 Windows F3 / Ctrl+G'),
      ('n', '新建窗口/文档', 'Mac ⌘N 自动转为远端 Windows Ctrl+N'),
      ('o', '打开文件 (Open)', 'Mac ⌘O 自动转为远端 Windows Ctrl+O'),
      ('p', '打印文档 (Print)', 'Mac ⌘P 自动转为远端 Windows Ctrl+P'),
      ('w', '关闭当前标签页', 'Mac ⌘W 自动转为远端 Windows Ctrl+W'),
      ('t', '新建标签页', 'Mac ⌘T 自动转为远端 Windows Ctrl+T'),
      ('r', '刷新页面/视图', 'Mac ⌘R 自动转为远端 Windows Ctrl+R'),
      ('l', '定位地址栏', 'Mac ⌘L 自动转为远端 Windows Ctrl+L'),
      ('d', '添加书签/复制项', 'Mac ⌘D 自动转为远端 Windows Ctrl+D'),
      ('b', '字体加粗 (Bold)', 'Mac ⌘B 自动转为远端 Windows Ctrl+B'),
      ('i', '字体斜体 (Italic)', 'Mac ⌘I 自动转为远端 Windows Ctrl+I'),
      ('u', '字体下划线', 'Mac ⌘U 自动转为远端 Windows Ctrl+U'),
      ('k', '插入超链接', 'Mac ⌘K 自动转为远端 Windows Ctrl+K'),
      ('h', '查找替换/历史', 'Mac ⌘H 自动转为远端 Windows Ctrl+H'),
      ('j', '下载列表管理', 'Mac ⌘J 自动转为远端 Windows Ctrl+J'),
      ('e', '搜索框聚焦/居中', 'Mac ⌘E 自动转为远端 Windows Ctrl+E'),
    ];

    for (final (k, title, desc) in macToWinCoreLetters) {
      list.add(BbsKeyMapEntry(
        id: 'm2w_cmd_$k',
        name: 'Mac 控 Win · $title',
        desc: desc,
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: k,
        srcMeta: true,
        dstKey: k,
        dstCtrl: true,
        presets: corePresets,
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_ctrl_$k',
        name: 'Win 控 Mac · $title',
        desc: 'Windows Ctrl+${k.toUpperCase()} 自动转为远端 Mac ⌘${k.toUpperCase()}',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: k,
        srcCtrl: true,
        dstKey: k,
        dstMeta: true,
        presets: corePresets,
      ));
    }

    // Mac -> Win Navigation, Editing, Screenshot & Window management (30 items)
    final m2wSystemExtra = <BbsKeyMapEntry>[
      const BbsKeyMapEntry(
        id: 'm2w_redo_shift_z',
        name: 'Mac 控 Win · 重做 (⌘⇧Z → Ctrl+Y)',
        desc: 'Mac 习惯的 ⌘⇧Z 重做无缝转为 Windows Ctrl+Y',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'z',
        srcMeta: true,
        srcShift: true,
        dstKey: 'y',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_paste_plain',
        name: 'Mac 控 Win · 纯文本粘贴',
        desc: '⌘⇧V 转为 Windows Ctrl+Shift+V 无格式粘贴',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'v',
        srcMeta: true,
        srcShift: true,
        dstKey: 'v',
        dstCtrl: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_save_as',
        name: 'Mac 控 Win · 另存为',
        desc: '⌘⇧S 转为 Windows Ctrl+Shift+S',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 's',
        srcMeta: true,
        srcShift: true,
        dstKey: 's',
        dstCtrl: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_quit_app',
        name: 'Mac 控 Win · 关闭程序 (⌘Q → Alt+F4)',
        desc: '在远端 Windows 按 ⌘Q 关闭当前活动窗口',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'q',
        srcMeta: true,
        dstKey: 'f4',
        dstAlt: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_task_mgr',
        name: 'Mac 控 Win · 任务管理器',
        desc: '⌘⌥Esc 直接呼出远端 Windows 任务管理器 (Ctrl+Shift+Esc)',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'escape',
        srcMeta: true,
        srcAlt: true,
        dstKey: 'escape',
        dstCtrl: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_ctrl_alt_del',
        name: 'Mac 控 Win · 发送 Ctrl+Alt+Del',
        desc: '⌃⌥⌫ 一键向远端 Windows 发送安全桌面指令',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'backspace',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'ctrl_alt_del',
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_lock_screen',
        name: 'Mac 控 Win · 一键锁屏',
        desc: '⌃⌘Q 立即锁定远端 Windows 屏幕',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'q',
        srcCtrl: true,
        srcMeta: true,
        dstKey: 'lock_screen',
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_snip_area',
        name: 'Mac 控 Win · 区域截图',
        desc: '⌘⇧4 触发 Windows 原生截图工具 (Win+Shift+S)',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'digit4',
        srcMeta: true,
        srcShift: true,
        dstKey: 's',
        dstMeta: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_snip_full',
        name: 'Mac 控 Win · 全屏截图',
        desc: '⌘⇧3 触发 Windows PrintScreen 全屏截屏',
        category: 'system',
        subGroup: 'Mac 控 Win 系统核心',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'digit3',
        srcMeta: true,
        srcShift: true,
        dstKey: 'print_screen',
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_line_home',
        name: 'Mac 控 Win · 光标跳至行首',
        desc: '⌘← 转为 Windows Home 键',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_left',
        srcMeta: true,
        dstKey: 'home',
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_line_end',
        name: 'Mac 控 Win · 光标跳至行尾',
        desc: '⌘→ 转为 Windows End 键',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_right',
        srcMeta: true,
        dstKey: 'end',
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_sel_line_home',
        name: 'Mac 控 Win · 选中至行首',
        desc: '⌘⇧← 转为 Windows Shift+Home',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_left',
        srcMeta: true,
        srcShift: true,
        dstKey: 'home',
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_sel_line_end',
        name: 'Mac 控 Win · 选中至行尾',
        desc: '⌘⇧→ 转为 Windows Shift+End',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_right',
        srcMeta: true,
        srcShift: true,
        dstKey: 'end',
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_doc_top',
        name: 'Mac 控 Win · 跳至文档顶部',
        desc: '⌘↑ 转为 Windows Ctrl+Home',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_up',
        srcMeta: true,
        dstKey: 'home',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_doc_bottom',
        name: 'Mac 控 Win · 跳至文档底部',
        desc: '⌘↓ 转为 Windows Ctrl+End',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_down',
        srcMeta: true,
        dstKey: 'end',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_sel_doc_top',
        name: 'Mac 控 Win · 选中至文档顶部',
        desc: '⌘⇧↑ 转为 Windows Ctrl+Shift+Home',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_up',
        srcMeta: true,
        srcShift: true,
        dstKey: 'home',
        dstCtrl: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_sel_doc_bottom',
        name: 'Mac 控 Win · 选中至文档底部',
        desc: '⌘⇧↓ 转为 Windows Ctrl+Shift+End',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_down',
        srcMeta: true,
        srcShift: true,
        dstKey: 'end',
        dstCtrl: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_word_left',
        name: 'Mac 控 Win · 按词左移',
        desc: '⌥← 转为 Windows Ctrl+←',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_left',
        srcAlt: true,
        dstKey: 'arrow_left',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_word_right',
        name: 'Mac 控 Win · 按词右移',
        desc: '⌥→ 转为 Windows Ctrl+→',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_right',
        srcAlt: true,
        dstKey: 'arrow_right',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_sel_word_left',
        name: 'Mac 控 Win · 按词向左选中',
        desc: '⌥⇧← 转为 Windows Ctrl+Shift+←',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_left',
        srcAlt: true,
        srcShift: true,
        dstKey: 'arrow_left',
        dstCtrl: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_sel_word_right',
        name: 'Mac 控 Win · 按词向右选中',
        desc: '⌥⇧→ 转为 Windows Ctrl+Shift+→',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_right',
        srcAlt: true,
        srcShift: true,
        dstKey: 'arrow_right',
        dstCtrl: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_del_word',
        name: 'Mac 控 Win · 按词退格删除',
        desc: '⌥⌫ 转为 Windows Ctrl+Backspace',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'backspace',
        srcAlt: true,
        dstKey: 'backspace',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_forward_del',
        name: 'Mac 控 Win · 向后删除字符',
        desc: '⌃D / ⌘⌫ 映射为 Windows Delete 键',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'backspace',
        srcMeta: true,
        dstKey: 'delete',
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_win_settings',
        name: 'Mac 控 Win · 打开系统设置',
        desc: '⌘, (逗号) 打开远端 Windows 设置面板 (Win+I)',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'comma',
        srcMeta: true,
        dstKey: 'i',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_win_explorer',
        name: 'Mac 控 Win · 打开文件资源管理器',
        desc: '⌘⌥Space 打开远端此电脑资源管理器 (Win+E)',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'space',
        srcMeta: true,
        srcAlt: true,
        dstKey: 'e',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_win_desktop',
        name: 'Mac 控 Win · 显示桌面',
        desc: '⌥⌘D 切换远端 Windows 显示桌面 (Win+D)',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'd',
        srcMeta: true,
        srcAlt: true,
        dstKey: 'd',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_win_emoji',
        name: 'Mac 控 Win · 呼出表情符号面板',
        desc: '⌃⌘Space 转为 Windows Emoji 面板 (Win+.)',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'space',
        srcCtrl: true,
        srcMeta: true,
        dstKey: 'period',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_snap_left',
        name: 'Mac 控 Win · 窗口左半屏分屏',
        desc: '⌃⌥← 转为 Windows 窗口贴靠左侧 (Win+←)',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_left',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'arrow_left',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_snap_right',
        name: 'Mac 控 Win · 窗口右半屏分屏',
        desc: '⌃⌥→ 转为 Windows 窗口贴靠右侧 (Win+→)',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_right',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'arrow_right',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'm2w_snap_max',
        name: 'Mac 控 Win · 窗口最大化',
        desc: '⌃⌥↑ 转为 Windows 窗口最大化 (Win+↑)',
        category: 'system',
        subGroup: 'Mac 控 Win 光标与窗口',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'arrow_up',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'arrow_up',
        dstMeta: true,
        presets: corePresets,
      ),
    ];
    list.addAll(m2wSystemExtra);

    // Win -> Mac Navigation, Screenshot & System management (30 items)
    final w2mSystemExtra = <BbsKeyMapEntry>[
      const BbsKeyMapEntry(
        id: 'w2m_redo_ctrl_y',
        name: 'Win 控 Mac · 重做 (Ctrl+Y → ⌘⇧Z)',
        desc: 'Windows Ctrl+Y 自动转为 Mac ⌘⇧Z 重做',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'y',
        srcCtrl: true,
        dstKey: 'z',
        dstMeta: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_paste_plain',
        name: 'Win 控 Mac · 纯文本粘贴',
        desc: 'Ctrl+Shift+V 转为 Mac ⌘⌥⇧V 匹配样式粘贴',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'v',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'v',
        dstMeta: true,
        dstAlt: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_quit_alt_f4',
        name: 'Win 控 Mac · 退出应用 (Alt+F4 → ⌘Q)',
        desc: '按 Alt+F4 正常退出远端 Mac 当前程序',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'f4',
        srcAlt: true,
        dstKey: 'q',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_force_quit',
        name: 'Win 控 Mac · 强制退出程序窗口',
        desc: 'Ctrl+Shift+Esc 呼出 Mac 强制退出面板 (⌘⌥Esc)',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'escape',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'escape',
        dstMeta: true,
        dstAlt: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_spotlight',
        name: 'Win 控 Mac · Spotlight 聚焦搜索',
        desc: 'Alt+Space 呼出远端 Mac 聚焦搜索 (⌘Space)',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'space',
        srcAlt: true,
        dstKey: 'space',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_snip_area',
        name: 'Win 控 Mac · 区域截图',
        desc: 'Ctrl+Shift+S / PrintScreen 触发 Mac 区域截图 (⌘⇧4)',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'print_screen',
        dstKey: 'digit4',
        dstMeta: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_snip_panel',
        name: 'Win 控 Mac · 截屏与录屏工具栏',
        desc: 'Shift+PrintScreen 呼出 Mac 截屏录屏面板 (⌘⇧5)',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'print_screen',
        srcShift: true,
        dstKey: 'digit5',
        dstMeta: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_lock_mac',
        name: 'Win 控 Mac · 锁定屏幕',
        desc: 'Ctrl+Alt+L 锁定远端 Mac 屏幕 (⌃⌘Q)',
        category: 'system',
        subGroup: 'Win 控 Mac 系统核心',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'l',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'q',
        dstCtrl: true,
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_home_line',
        name: 'Win 控 Mac · Home 跳至行首',
        desc: 'Windows Home 键转为 Mac ⌘← 跳至行首',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'home',
        dstKey: 'arrow_left',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_end_line',
        name: 'Win 控 Mac · End 跳至行尾',
        desc: 'Windows End 键转为 Mac ⌘→ 跳至行尾',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'end',
        dstKey: 'arrow_right',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_sel_home',
        name: 'Win 控 Mac · Shift+Home 选中至行首',
        desc: 'Shift+Home 转为 Mac ⌘⇧←',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'home',
        srcShift: true,
        dstKey: 'arrow_left',
        dstMeta: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_sel_end',
        name: 'Win 控 Mac · Shift+End 选中至行尾',
        desc: 'Shift+End 转为 Mac ⌘⇧→',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'end',
        srcShift: true,
        dstKey: 'arrow_right',
        dstMeta: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_doc_top',
        name: 'Win 控 Mac · Ctrl+Home 文档顶部',
        desc: 'Ctrl+Home 转为 Mac ⌘↑',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'home',
        srcCtrl: true,
        dstKey: 'arrow_up',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_doc_bottom',
        name: 'Win 控 Mac · Ctrl+End 文档底部',
        desc: 'Ctrl+End 转为 Mac ⌘↓',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'end',
        srcCtrl: true,
        dstKey: 'arrow_down',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_word_left',
        name: 'Win 控 Mac · Ctrl+← 按词左移',
        desc: 'Ctrl+← 转为 Mac ⌥← 按单词移动',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_left',
        srcCtrl: true,
        dstKey: 'arrow_left',
        dstAlt: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_word_right',
        name: 'Win 控 Mac · Ctrl+→ 按词右移',
        desc: 'Ctrl+→ 转为 Mac ⌥→ 按单词移动',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_right',
        srcCtrl: true,
        dstKey: 'arrow_right',
        dstAlt: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_sel_word_left',
        name: 'Win 控 Mac · Ctrl+Shift+← 按词左选',
        desc: 'Ctrl+Shift+← 转为 Mac ⌥⇧←',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_left',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'arrow_left',
        dstAlt: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_sel_word_right',
        name: 'Win 控 Mac · Ctrl+Shift+→ 按词右选',
        desc: 'Ctrl+Shift+→ 转为 Mac ⌥⇧→',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_right',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'arrow_right',
        dstAlt: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_del_word',
        name: 'Win 控 Mac · Ctrl+Backspace 按词删除',
        desc: 'Ctrl+Backspace 转为 Mac ⌥⌫',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'backspace',
        srcCtrl: true,
        dstKey: 'backspace',
        dstAlt: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_finder_del',
        name: 'Win 控 Mac · Finder 删除文件到废纸篓',
        desc: 'Ctrl+Delete 转为 Mac ⌘⌫ 移入废纸篓',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'delete',
        srcCtrl: true,
        dstKey: 'backspace',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_refresh_f5',
        name: 'Win 控 Mac · F5 刷新网页/页面',
        desc: '按 F5 触发远端 Mac 浏览器 ⌘R 刷新',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'f5',
        dstKey: 'r',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_fullscreen_f11',
        name: 'Win 控 Mac · F11 切换原生全屏',
        desc: 'F11 转为 Mac 应用全屏切换 (⌃⌘F)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'f11',
        dstKey: 'f',
        dstCtrl: true,
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_file_info',
        name: 'Win 控 Mac · Alt+Enter 查看属性简介',
        desc: 'Alt+Enter 转为 Mac Finder 显示简介 (⌘I)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'enter',
        srcAlt: true,
        dstKey: 'i',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_app_prefs',
        name: 'Win 控 Mac · Ctrl+, 打开应用偏好设置',
        desc: 'Ctrl+, 转为 Mac 原生偏好设置 (⌘,)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'comma',
        srcCtrl: true,
        dstKey: 'comma',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_finder_up',
        name: 'Win 控 Mac · Alt+↑ 返回上级目录',
        desc: 'Alt+↑ 转为 Mac Finder 上一级文件夹 (⌘↑)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_up',
        srcAlt: true,
        dstKey: 'arrow_up',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_finder_open',
        name: 'Win 控 Mac · Ctrl+Enter 打开选中文件',
        desc: 'Ctrl+Enter 转为 Mac Finder 打开项目 (⌘O)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'enter',
        srcCtrl: true,
        dstKey: 'o',
        dstMeta: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_finder_hidden',
        name: 'Win 控 Mac · 显示/隐藏点文件',
        desc: 'Ctrl+Shift+. 转为 Mac Finder 显示隐藏文件 (⌘⇧.)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'period',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'period',
        dstMeta: true,
        dstShift: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_mission_ctrl',
        name: 'Win 控 Mac · 调度中心 (Mission Control)',
        desc: 'Ctrl+Alt+↑ 呼出远端 Mac 调度中心 (⌃↑)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_up',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'arrow_up',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_space_left',
        name: 'Win 控 Mac · 切换左桌面空间',
        desc: 'Ctrl+Alt+← 切换远端 Mac 左侧桌面 (⌃←)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_left',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'arrow_left',
        dstCtrl: true,
        presets: corePresets,
      ),
      const BbsKeyMapEntry(
        id: 'w2m_space_right',
        name: 'Win 控 Mac · 切换右桌面空间',
        desc: 'Ctrl+Alt+→ 切换远端 Mac 右侧桌面 (⌃→)',
        category: 'system',
        subGroup: 'Win 控 Mac 光标与访达',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'arrow_right',
        srcCtrl: true,
        srcAlt: true,
        dstKey: 'arrow_right',
        dstCtrl: true,
        presets: corePresets,
      ),
    ];
    list.addAll(w2mSystemExtra);

    // =========================================================================
    // 2. Office 办公 · 浏览器 · 终端命令行 (126 条)
    // =========================================================================
    // Browser Tabs 1-9 (Mac <-> Win = 18 items) + Browser DevTools/Zoom/History (26 items)
    for (var i = 1; i <= 9; i++) {
      final key = 'digit$i';
      final label = i == 9 ? '最后一个标签页' : '第 $i 个标签页';
      list.add(BbsKeyMapEntry(
        id: 'm2w_browser_tab_$i',
        name: '浏览器 · 跳转$label (Mac→Win)',
        desc: '⌘$i 转为远端 Windows 浏览器 Ctrl+$i',
        category: 'office',
        subGroup: '浏览器高频效率',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: key,
        srcMeta: true,
        dstKey: key,
        dstCtrl: true,
        presets: corePresets,
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_browser_tab_$i',
        name: '浏览器 · 跳转$label (Win→Mac)',
        desc: 'Ctrl+$i 转为远端 Mac 浏览器 ⌘$i',
        category: 'office',
        subGroup: '浏览器高频效率',
        srcHost: 'win',
        peer: 'macos',
        srcKey: key,
        srcCtrl: true,
        dstKey: key,
        dstMeta: true,
        presets: corePresets,
      ));
    }

    const browserPairs = <(String, String, String, bool, bool, String, bool, bool)>[
      ('reopen_tab', '恢复刚关闭的标签页', 't', true, false, 't', true, false),
      ('incognito', '新建无痕/隐私窗口', 'n', true, false, 'n', true, false),
      ('hard_reload', '忽略缓存强制刷新', 'r', true, false, 'r', true, false),
      ('bookmarks_bar', '显示/隐藏书签栏', 'b', true, false, 'b', true, false),
      ('zoom_in', '网页放大 (+)', 'equal', false, false, 'equal', false, false),
      ('zoom_out', '网页缩小 (-)', 'minus', false, false, 'minus', false, false),
      ('zoom_reset', '网页恢复 100% 缩放', 'digit0', false, false, 'digit0', false, false),
      ('view_source', '查看网页源代码', 'u', false, true, 'u', false, false),
      ('devtools_i', '开发者工具 (DevTools)', 'i', false, true, 'i', true, false),
      ('devtools_j', '打开 JS 控制台 (Console)', 'j', false, true, 'j', true, false),
      ('devtools_c', '审查页面元素 (Inspect)', 'c', true, false, 'c', true, false),
      ('clear_data', '清除浏览数据面板', 'backspace', true, false, 'delete', true, false),
      ('bookmark_mgr', '打开书签管理器', 'o', false, true, 'o', true, false),
    ];
    for (final (slug, title, mKey, mShift, mOpt, wKey, wShift, wAlt)
        in browserPairs) {
      list.add(BbsKeyMapEntry(
        id: 'm2w_br_$slug',
        name: '浏览器 · $title (Mac→Win)',
        desc: '在远端 Windows Chrome/Edge 使用 Mac 快捷键执行$title',
        category: 'office',
        subGroup: '浏览器高频效率',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: mKey,
        srcMeta: true,
        srcShift: mShift,
        srcAlt: mOpt,
        dstKey: wKey,
        dstCtrl: true,
        dstShift: wShift,
        dstAlt: wAlt,
        presets: corePresets,
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_br_$slug',
        name: '浏览器 · $title (Win→Mac)',
        desc: '在远端 Mac Safari/Chrome 使用 Win 快捷键执行$title',
        category: 'office',
        subGroup: '浏览器高频效率',
        srcHost: 'win',
        peer: 'macos',
        srcKey: wKey,
        srcCtrl: true,
        srcShift: wShift,
        srcAlt: wAlt,
        dstKey: mKey,
        dstMeta: true,
        dstShift: mShift,
        dstAlt: mOpt,
        presets: corePresets,
      ));
    }

    // Excel / WPS / Word / PPT Office Suite (52 items)
    const officeBidirectional = <(String, String, String, String, bool, bool, String, bool, bool)>[
      ('xl_format_cell', 'Excel/WPS', '设置单元格格式', 'digit1', false, false, 'digit1', false, false),
      ('xl_filter', 'Excel/WPS', '开启/关闭数据筛选', 'l', true, false, 'l', true, false),
      ('xl_insert_date', 'Excel/WPS', '插入当前日期', 'semicolon', false, false, 'semicolon', false, false),
      ('xl_insert_time', 'Excel/WPS', '插入当前时间', 'semicolon', true, false, 'semicolon', true, false),
      ('xl_fill_down', 'Excel/WPS', '向下填充公式/内容', 'd', false, false, 'd', false, false),
      ('xl_fill_right', 'Excel/WPS', '向右填充公式/内容', 'r', false, false, 'r', false, false),
      ('xl_create_table', 'Excel/WPS', '创建超级表 (Table)', 't', false, false, 't', false, false),
      ('xl_next_sheet', 'Excel/WPS', '切换下一张工作表', 'page_down', false, false, 'page_down', false, false),
      ('xl_prev_sheet', 'Excel/WPS', '切换上一张工作表', 'page_up', false, false, 'page_up', false, false),
      ('xl_hide_row', 'Excel/WPS', '隐藏选中行', 'digit9', false, false, 'digit9', false, false),
      ('xl_hide_col', 'Excel/WPS', '隐藏选中列', 'digit0', false, false, 'digit0', false, false),
      ('wd_copy_fmt', 'Word/PPT', '复制格式刷样式', 'c', true, false, 'c', true, false),
      ('wd_paste_fmt', 'Word/PPT', '粘贴格式刷样式', 'v', true, false, 'v', true, false),
      ('wd_align_center', 'Word/PPT', '段落居中对齐', 'e', false, false, 'e', false, false),
      ('wd_align_left', 'Word/PPT', '段落左对齐', 'l', false, false, 'l', false, false),
      ('wd_align_right', 'Word/PPT', '段落右对齐', 'r', false, false, 'r', false, false),
      ('wd_align_justify', 'Word/PPT', '段落两端对齐', 'j', false, false, 'j', false, false),
      ('wd_font_bigger', 'Word/PPT', '增大字号', 'period', true, false, 'period', true, false),
      ('wd_font_smaller', 'Word/PPT', '减小字号', 'comma', true, false, 'comma', true, false),
      ('wd_page_break', 'Word/PPT', '插入分页符', 'enter', false, false, 'enter', false, false),
      ('wd_h1', 'Word/PPT', '应用一级标题样式', 'digit1', false, true, 'digit1', false, true),
      ('wd_h2', 'Word/PPT', '应用二级标题样式', 'digit2', false, true, 'digit2', false, true),
      ('wd_h3', 'Word/PPT', '应用三级标题样式', 'digit3', false, true, 'digit3', false, true),
      ('ppt_group', 'Word/PPT', '组合选中图形对象', 'g', false, false, 'g', false, false),
      ('ppt_ungroup', 'Word/PPT', '取消图形组合', 'g', true, false, 'g', true, false),
      ('ppt_dup', 'Word/PPT', '快速复制幻灯片/图层', 'd', false, false, 'd', false, false),
    ];

    for (final (slug, group, title, mKey, mShift, mOpt, wKey, wShift, wAlt)
        in officeBidirectional) {
      list.add(BbsKeyMapEntry(
        id: 'm2w_of_$slug',
        name: '$group · $title (Mac→Win)',
        desc: '在远端 Windows Office/WPS 中直接按 Mac 组合键$title',
        category: 'office',
        subGroup: '$group 办公排版',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: mKey,
        srcMeta: true,
        srcShift: mShift,
        srcAlt: mOpt,
        dstKey: wKey,
        dstCtrl: true,
        dstShift: wShift,
        dstAlt: wAlt,
        presets: const {'smart_office'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_of_$slug',
        name: '$group · $title (Win→Mac)',
        desc: '在远端 Mac Office/WPS 中直接按 Win 组合键$title',
        category: 'office',
        subGroup: '$group 办公排版',
        srcHost: 'win',
        peer: 'macos',
        srcKey: wKey,
        srcCtrl: true,
        srcShift: wShift,
        srcAlt: wAlt,
        dstKey: mKey,
        dstMeta: true,
        dstShift: mShift,
        dstAlt: mOpt,
        presets: const {'smart_office'},
      ));
    }

    // Terminal / iTerm2 / PowerShell / Windows Terminal (30 items)
    const termRules = <BbsKeyMapEntry>[
      BbsKeyMapEntry(
        id: 'm2w_term_copy',
        name: '终端 · 复制选中文本 (⌘C → Ctrl+Shift+C)',
        desc: '避免误发 SIGINT，在 Windows Terminal/Linux 终端安全复制',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'c',
        srcMeta: true,
        srcShift: true,
        dstKey: 'c',
        dstCtrl: true,
        dstShift: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'm2w_term_paste',
        name: '终端 · 粘贴命令 (⌘⇧V → Ctrl+Shift+V)',
        desc: '向远端 Windows Terminal / WSL 粘贴剪贴板命令',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'v',
        srcMeta: true,
        srcShift: true,
        dstKey: 'v',
        dstCtrl: true,
        dstShift: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'm2w_term_clear',
        name: '终端 · 清空屏幕 (⌘K → Ctrl+L)',
        desc: 'Mac iTerm2 习惯的 ⌘K 清屏转为终端通用 Ctrl+L',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'k',
        srcMeta: true,
        dstKey: 'l',
        dstCtrl: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'm2w_term_split_v',
        name: '终端 · 垂直分屏 (⌘D → Alt+Shift+Plus)',
        desc: '在远端 Windows Terminal 新建右侧垂直分屏',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'd',
        srcMeta: true,
        srcAlt: true,
        dstKey: 'equal',
        dstAlt: true,
        dstShift: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'm2w_term_split_h',
        name: '终端 · 水平分屏 (⌘⇧D → Alt+Shift+Minus)',
        desc: '在远端 Windows Terminal 新建下方水平分屏',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'd',
        srcMeta: true,
        srcShift: true,
        dstKey: 'minus',
        dstAlt: true,
        dstShift: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'm2w_term_new_tab',
        name: '终端 · 新建终端标签页 (⌘⇧T → Ctrl+Shift+T)',
        desc: '在 Windows Terminal 新建 Shell 标签页',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 't',
        srcMeta: true,
        srcAlt: true,
        dstKey: 't',
        dstCtrl: true,
        dstShift: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'm2w_term_close_pane',
        name: '终端 · 关闭当前分屏 (⌘⇧W → Ctrl+Shift+W)',
        desc: '关闭远端 Windows Terminal 当前活动面板',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'w',
        srcMeta: true,
        srcShift: true,
        dstKey: 'w',
        dstCtrl: true,
        dstShift: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'm2w_term_find',
        name: '终端 · 搜索终端输出 (⌘⇧F → Ctrl+Shift+F)',
        desc: '在远端终端缓冲区中查找关键字',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: 'f',
        srcMeta: true,
        srcAlt: true,
        dstKey: 'f',
        dstCtrl: true,
        dstShift: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'w2m_term_clear',
        name: '终端 · 清屏回滚区 (Ctrl+Shift+K → ⌘K)',
        desc: 'Win 控 Mac Terminal / iTerm2 清空屏幕缓冲区',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'k',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'k',
        dstMeta: true,
        presets: {'dev_pro'},
      ),
      BbsKeyMapEntry(
        id: 'w2m_term_split_v',
        name: '终端 · iTerm2 垂直分屏 (Alt+Shift+D → ⌘D)',
        desc: 'Win 控 Mac iTerm2 新建垂直分屏面板',
        category: 'office',
        subGroup: '终端与命令行',
        srcHost: 'win',
        peer: 'macos',
        srcKey: 'd',
        srcAlt: true,
        srcShift: true,
        dstKey: 'd',
        dstMeta: true,
        presets: {'dev_pro'},
      ),
    ];
    list.addAll(termRules);

    // =========================================================================
    // 3. 编程开发 · 设计修图 · 影视剪辑 · 3D建模 (166 条)
    // =========================================================================
    const vscodePairs = <(String, String, String, bool, bool, String, bool, bool)>[
      ('cmd_palette', '打开命令面板', 'p', true, false, 'p', true, false),
      ('quick_open', '快速按文件名跳转', 'p', false, false, 'p', false, false),
      ('global_search', '全局代码搜索', 'f', true, false, 'f', true, false),
      ('global_replace', '全局批量替换', 'h', true, false, 'h', true, false),
      ('toggle_comment', '单行代码注释切换', 'slash', false, false, 'slash', false, false),
      ('block_comment', '块级注释切换', 'a', true, true, 'a', true, true),
      ('format_doc', '一键格式化文档代码', 'f', true, true, 'f', true, true),
      ('del_line', '删除当前整行代码', 'k', true, false, 'k', true, false),
      ('add_next_match', '多光标选中下一相同词', 'd', false, false, 'd', false, false),
      ('sel_all_match', '多光标选中全部相同词', 'l', true, false, 'l', true, false),
      ('cursor_above', '在上方插入多光标', 'arrow_up', false, true, 'arrow_up', false, true),
      ('cursor_below', '在下方插入多光标', 'arrow_down', false, true, 'arrow_down', false, true),
      ('split_editor', '向右拆分代码编辑器', 'backslash', false, false, 'backslash', false, false),
      ('toggle_sidebar', '展开/收起项目侧栏', 'b', false, false, 'b', false, false),
      ('toggle_panel', '展开/收起底部面板', 'j', false, false, 'j', false, false),
      ('quick_fix', '智能快速修复建议 (Quick Fix)', 'period', false, false, 'period', false, false),
      ('goto_symbol', '跳转当前文件函数符号', 'o', true, false, 'o', true, false),
      ('goto_workspace_sym', '跳转全局工作区符号', 't', false, false, 't', false, false),
      ('fold_code', '折叠当前代码块', 'bracket_left', false, true, 'bracket_left', true, false),
      ('unfold_code', '展开当前代码块', 'bracket_right', false, true, 'bracket_right', true, false),
      ('zen_mode', '进入沉浸式开发视图', 'z', false, true, 'z', false, true),
      ('problems_panel', '打开错误与警告面板', 'm', true, false, 'm', true, false),
    ];

    for (final (slug, title, mKey, mShift, mOpt, wKey, wShift, wAlt)
        in vscodePairs) {
      list.add(BbsKeyMapEntry(
        id: 'm2w_vsc_$slug',
        name: 'VS Code/Cursor · $title (Mac→Win)',
        desc: 'Mac 控远端 Windows VS Code / Cursor 执行$title',
        category: 'creative',
        subGroup: 'VS Code / Cursor 编程',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: mKey,
        srcMeta: true,
        srcShift: mShift,
        srcAlt: mOpt,
        dstKey: wKey,
        dstCtrl: true,
        dstShift: wShift,
        dstAlt: wAlt,
        presets: const {'dev_pro'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_vsc_$slug',
        name: 'VS Code/Cursor · $title (Win→Mac)',
        desc: 'Win 控远端 Mac VS Code / Cursor / Xcode 执行$title',
        category: 'creative',
        subGroup: 'VS Code / Cursor 编程',
        srcHost: 'win',
        peer: 'macos',
        srcKey: wKey,
        srcCtrl: true,
        srcShift: wShift,
        srcAlt: wAlt,
        dstKey: mKey,
        dstMeta: true,
        dstShift: mShift,
        dstAlt: mOpt,
        presets: const {'dev_pro'},
      ));
    }

    // JetBrains IDEA / PyCharm / GoLand / WebStorm (28 items)
    const ideaPairs = <(String, String, String, bool, bool, String, bool, bool)>[
      ('find_action', '查找任意操作 (Find Action)', 'a', true, false, 'a', true, false),
      ('recent_files', '最近打开的文件列表', 'e', false, false, 'e', false, false),
      ('reformat', '格式化代码并重排', 'l', false, true, 'l', false, true),
      ('opt_imports', '自动清理优化导包', 'o', false, true, 'o', false, true),
      ('goto_decl', '跳转到声明或用例', 'b', false, false, 'b', false, false),
      ('goto_impl', '跳转到接口实现类', 'b', false, true, 'b', false, true),
      ('dup_line', '向下复制当前代码行', 'd', false, false, 'd', false, false),
      ('del_line', '删除光标所在整行', 'backspace', false, false, 'y', false, false),
      ('extract_var', '重构提取局部变量', 'v', false, true, 'v', false, true),
      ('extract_method', '重构提取独立函数方法', 'm', false, true, 'm', false, true),
      ('rename_sym', '安全重命名变量/类', 'f6', true, false, 'f6', true, false),
      ('file_struct', '查看当前类成员结构', 'f12', false, false, 'f12', false, false),
      ('surround_with', '使用 try/if 包裹代码块', 't', false, true, 't', false, true),
      ('project_view', '定位打开项目目录树', 'digit1', false, false, 'digit1', false, true),
    ];

    for (final (slug, title, mKey, mShift, mOpt, wKey, wShift, wAlt)
        in ideaPairs) {
      list.add(BbsKeyMapEntry(
        id: 'm2w_idea_$slug',
        name: 'JetBrains IDEA · $title (Mac→Win)',
        desc: 'Mac 控远端 Windows IDEA / PyCharm 执行$title',
        category: 'creative',
        subGroup: 'JetBrains 全家桶开发',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: mKey,
        srcMeta: true,
        srcShift: mShift,
        srcAlt: mOpt,
        dstKey: wKey,
        dstCtrl: !(wKey == 'digit1' && wAlt),
        dstShift: wShift,
        dstAlt: wAlt,
        presets: const {'dev_pro'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_idea_$slug',
        name: 'JetBrains IDEA · $title (Win→Mac)',
        desc: 'Win 控远端 Mac IDEA / PyCharm / Android Studio 执行$title',
        category: 'creative',
        subGroup: 'JetBrains 全家桶开发',
        srcHost: 'win',
        peer: 'macos',
        srcKey: wKey,
        srcCtrl: !(wKey == 'digit1' && wAlt),
        srcShift: wShift,
        srcAlt: wAlt,
        dstKey: mKey,
        dstMeta: true,
        dstShift: mShift,
        dstAlt: mOpt,
        presets: const {'dev_pro'},
      ));
    }

    // Photoshop / Illustrator / Figma Design (44 items)
    const designPairs = <(String, String, String, bool, bool, String, bool, bool)>[
      ('new_layer', '新建空白图层', 'n', true, false, 'n', true, false),
      ('dup_layer', '通过拷贝新建图层', 'j', false, false, 'j', false, false),
      ('free_transform', '自由变换缩放旋转', 't', false, false, 't', false, false),
      ('merge_down', '向下合并图层', 'e', false, false, 'e', false, false),
      ('stamp_visible', '盖印所有可见图层', 'e', true, true, 'e', true, true),
      ('deselect', '取消当前选区', 'd', false, false, 'd', false, false),
      ('invert_sel', '反向选择选区', 'i', true, false, 'i', true, false),
      ('levels', '色阶调色面板 (Levels)', 'l', false, false, 'l', false, false),
      ('curves', '曲线调色面板 (Curves)', 'm', false, false, 'm', false, false),
      ('hue_sat', '色相与饱和度调节', 'u', false, false, 'u', false, false),
      ('color_bal', '色彩平衡调节', 'b', false, false, 'b', false, false),
      ('invert_img', '图像色彩反相', 'i', false, false, 'i', false, false),
      ('liquify', '打开液化塑形滤镜', 'x', true, false, 'x', true, false),
      ('camera_raw', '打开 Camera Raw 滤镜', 'a', true, false, 'a', true, false),
      ('clip_mask', '创建/释放剪贴蒙版', 'g', false, true, 'g', false, true),
      ('canvas_size', '修改画布大小', 'c', false, true, 'c', false, true),
      ('image_size', '修改图像分辨率大小', 'i', false, true, 'i', false, true),
      ('export_web', '导出为 Web 所用格式', 's', true, true, 's', true, true),
      ('rulers', '显示/隐藏标尺参考线', 'r', false, false, 'r', false, false),
      ('fit_screen', '画布自适应屏幕大小', 'digit0', false, false, 'digit0', false, false),
      ('actual_px', '100% 实际像素预览', 'digit1', false, false, 'digit1', false, false),
      ('figma_comp', 'Figma 创建组件 (Component)', 'k', false, true, 'k', false, true),
    ];

    for (final (slug, title, mKey, mShift, mOpt, wKey, wShift, wAlt)
        in designPairs) {
      list.add(BbsKeyMapEntry(
        id: 'm2w_ps_$slug',
        name: 'PS / Figma · $title (Mac→Win)',
        desc: 'Mac 控远端 Windows Photoshop / Illustrator / Figma 执行$title',
        category: 'creative',
        subGroup: 'Photoshop / Figma 设计',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: mKey,
        srcMeta: true,
        srcShift: mShift,
        srcAlt: mOpt,
        dstKey: wKey,
        dstCtrl: true,
        dstShift: wShift,
        dstAlt: wAlt,
        presets: const {'creative_3d'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_ps_$slug',
        name: 'PS / Figma · $title (Win→Mac)',
        desc: 'Win 控远端 Mac Photoshop / Illustrator / Figma 执行$title',
        category: 'creative',
        subGroup: 'Photoshop / Figma 设计',
        srcHost: 'win',
        peer: 'macos',
        srcKey: wKey,
        srcCtrl: true,
        srcShift: wShift,
        srcAlt: wAlt,
        dstKey: mKey,
        dstMeta: true,
        dstShift: mShift,
        dstAlt: mOpt,
        presets: const {'creative_3d'},
      ));
    }

    // Premiere Pro / DaVinci Resolve / Final Cut / Blender 3D (50 items)
    const videoPairs = <(String, String, String, bool, bool, String, bool, bool)>[
      ('razor_cut', '添加编辑点切割片段', 'k', false, false, 'k', false, false),
      ('cut_all_tracks', '全轨道同步切断', 'k', true, false, 'k', true, false),
      ('speed_dur', '片段变速与持续时间', 'r', false, false, 'r', false, false),
      ('export_media', '呼出媒体渲染导出面板', 'm', false, false, 'm', false, false),
      ('import_media', '导入素材文件', 'i', false, false, 'i', false, false),
      ('new_seq', '新建剪辑时间线序列', 'n', false, false, 'n', false, false),
      ('default_trans', '添加默认视频转场', 'd', true, false, 'd', true, false),
      ('audio_trans', '添加恒定功率音频过渡', 'd', true, true, 'd', true, false),
      ('unlink_av', '音视频轨道解绑/关联', 'l', false, false, 'l', false, false),
      ('nest_clips', '嵌套/复合片段', 'g', false, true, 'g', false, true),
      ('ripple_del', '波纹删除并自动吸附间隙', 'backspace', false, true, 'delete', true, false),
      ('clear_inout', '清除时间线入点与出点', 'x', false, true, 'x', true, false),
      ('Dynamic_trim', '启用动态修剪预览', 't', true, false, 't', false, false),
      ('render_fx', '渲染入点到出点预览', 'enter', false, false, 'enter', false, false),
      ('color_panel', '切换调色工作区', 'digit6', true, true, 'digit6', true, true),
    ];

    for (final (slug, title, mKey, mShift, mOpt, wKey, wShift, wAlt)
        in videoPairs) {
      list.add(BbsKeyMapEntry(
        id: 'm2w_vid_$slug',
        name: 'PR / 达芬奇 · $title (Mac→Win)',
        desc: 'Mac 控远端 Windows Premiere / DaVinci 执行$title',
        category: 'creative',
        subGroup: '影视剪辑与 Blender 3D',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: mKey,
        srcMeta: !(mKey == 'backspace' || mKey == 'x' && mOpt),
        srcShift: mShift,
        srcAlt: mOpt,
        dstKey: wKey,
        dstCtrl: !(wKey == 'delete' || wKey == 'enter'),
        dstShift: wShift,
        dstAlt: wAlt,
        presets: const {'creative_3d'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'w2m_vid_$slug',
        name: 'PR / 达芬奇 · $title (Win→Mac)',
        desc: 'Win 控远端 Mac Final Cut / Premiere / DaVinci 执行$title',
        category: 'creative',
        subGroup: '影视剪辑与 Blender 3D',
        srcHost: 'win',
        peer: 'macos',
        srcKey: wKey,
        srcCtrl: !(wKey == 'delete' || wKey == 'enter'),
        srcShift: wShift,
        srcAlt: wAlt,
        dstKey: mKey,
        dstMeta: !(mKey == 'backspace' || mKey == 'x' && mOpt),
        dstShift: mShift,
        dstAlt: mOpt,
        presets: const {'creative_3d'},
      ));
    }

    // Blender 3D Numpad Camera Emulation for MacBook / Tenkeyless Keyboards (20 items)
    const blenderNumpadViews = <(String, String, String, String)>[
      ('digit1', 'kp_1', '前视图 (Front Ortho)', '无小键盘按 Alt+1 触发 Numpad 1 前正交视图'),
      ('digit3', 'kp_3', '右视图 (Right Ortho)', '无小键盘按 Alt+3 触发 Numpad 3 右正交视图'),
      ('digit7', 'kp_7', '顶视图 (Top Ortho)', '无小键盘按 Alt+7 触发 Numpad 7 顶正交视图'),
      ('digit9', 'kp_9', '反向对侧视图', '无小键盘按 Alt+9 触发 Numpad 9 反转当前视图'),
      ('digit5', 'kp_5', '透视/正交切换', '无小键盘按 Alt+5 触发 Numpad 5 透视正交切换'),
      ('digit0', 'kp_0', '摄像机渲染视角', '无小键盘按 Alt+0 触发 Numpad 0 进入摄像机'),
      ('digit2', 'kp_2', '视图向下旋转 15°', '无小键盘按 Alt+2 触发 Numpad 2'),
      ('digit4', 'kp_4', '视图向左旋转 15°', '无小键盘按 Alt+4 触发 Numpad 4'),
      ('digit6', 'kp_6', '视图向右旋转 15°', '无小键盘按 Alt+6 触发 Numpad 6'),
      ('digit8', 'kp_8', '视图向上旋转 15°', '无小键盘按 Alt+8 触发 Numpad 8'),
      ('period', 'kp_decimal', '聚焦选中模型 (Frame Selected)', 'Alt+. 触发小键盘句点聚焦当前 3D 物体'),
      ('slash', 'kp_divide', '独显隔离选中模型 (Local View)', 'Alt+/ 触发小键盘斜杠独显模式'),
      ('equal', 'kp_add', '小键盘 + 推进视图', 'Alt+= 触发小键盘加号放大'),
      ('minus', 'kp_subtract', '小键盘 - 拉远视图', 'Alt+- 触发小键盘减号缩小'),
      ('digit8_mul', 'kp_multiply', '小键盘 * 快捷键', 'Alt+Shift+8 触发小键盘乘号'),
      ('enter_kp', 'kp_enter', '小键盘确认键 (Numpad Enter)', 'Alt+Enter 触发独立小键盘回车'),
    ];
    for (final (src, dst, title, desc) in blenderNumpadViews) {
      final isShiftMul = src == 'digit8_mul';
      final actualSrc = isShiftMul
          ? 'digit8'
          : (src == 'enter_kp' ? 'backslash' : src);
      list.add(BbsKeyMapEntry(
        id: 'numpad_emu_$src',
        name: '3D/小键盘扩展 · $title',
        desc: desc,
        category: 'creative',
        subGroup: '无小键盘笔记本数字区映射',
        srcHost: 'any',
        peer: 'all',
        srcKey: actualSrc,
        srcAlt: true,
        srcShift: isShiftMul,
        dstKey: dst,
        presets: const {'creative_3d', 'mmo_numpad'},
      ));
    }
    // Back View / Left View / Bottom View (Ctrl+Numpad 1/3/7)
    for (final (digit, kp, label) in [
      ('digit1', 'kp_1', '后视图 (Ctrl+Numpad 1)'),
      ('digit3', 'kp_3', '左视图 (Ctrl+Numpad 3)'),
      ('digit7', 'kp_7', '底视图 (Ctrl+Numpad 7)'),
      ('digit0', 'kp_0', '将当前视角对齐摄像机 (Ctrl+Alt+Numpad 0)'),
    ]) {
      list.add(BbsKeyMapEntry(
        id: 'blender_back_$digit',
        name: 'Blender 3D · $label',
        desc: '按 Ctrl+Shift+${digit.replaceAll('digit', '')} 触发 Blender $label',
        category: 'creative',
        subGroup: '无小键盘笔记本数字区映射',
        srcHost: 'any',
        peer: 'all',
        srcKey: digit,
        srcCtrl: true,
        srcShift: true,
        dstKey: kp,
        dstCtrl: true,
        dstAlt: digit == 'digit0',
        presets: const {'creative_3d'},
      ));
    }

    // =========================================================================
    // 4. 游戏电竞 · 开放世界 · MOBA · MMO · 模拟器键位库 (172 条)
    // =========================================================================
    // 4A. FPS 战术射击竞技 (CS2 / Valorant / Apex / PUBG - 42 items)
    const fpsRules = <(String, String, String, String, bool, bool, String, bool, bool)>[
      ('caps_crouch', 'CapsLock 映射战术下蹲 (Ctrl)', 'caps_lock', 'ctrl', false, false, '战术射击拇指免扭曲下蹲', false, false),
      ('caps_walk', 'Shift+CapsLock 切换静步慢走', 'caps_lock', 'shift', true, false, '按住触发低噪静步移动', false, false),
      ('grave_score', '` 波浪键快速查看战绩计分板', 'backquote', 'tab', false, false, '不遮挡 WASD 移动查看战局', false, false),
      ('q_flash', 'Alt+Q 快速切闪光弹 (Key 7)', 'q', 'digit7', false, true, 'CS2 / 无畏契约一键切闪光弹', false, false),
      ('e_smoke', 'Alt+E 快速切烟雾弹 (Key 8)', 'e', 'digit8', false, true, '一键切烟雾弹封点', false, false),
      ('f_molotov', 'Alt+F 快速切燃烧瓶 (Key 0)', 'f', 'digit0', false, true, '一键切燃烧弹清角', false, false),
      ('c_he', 'Alt+C 快速切高爆手雷 (Key 6)', 'c', 'digit6', false, true, '一键切高爆手雷', false, false),
      ('x_decoy', 'Alt+X 快速切诱饵弹 (Key 9)', 'x', 'digit9', false, true, '一键切战术诱饵弹', false, false),
      ('z_ping', 'Alt+Z 战术危险标点 (Ping)', 'z', 'z', false, true, '快速发送前方敌人标点', false, false),
      ('v_voice', 'Alt+V 小队语音对讲键 (K)', 'v', 'k', false, true, '顺手开启游戏内小队麦克风', false, false),
      ('b_buy', 'Alt+B 购买菜单快捷呼出', 'b', 'b', false, true, '回合开始快速购买护甲武器', false, false),
      ('g_drop', 'Alt+G 快速给队友丢枪', 'g', 'g', false, true, '一键投掷主武器给队友', false, false),
      ('t_spray', 'Alt+T 喷漆/检视铭牌', 't', 't', false, true, '快速展示战队喷漆', false, false),
      ('y_inspect', 'Alt+Y 武器检视把玩', 'y', 'f', false, true, '触发切刀检视动画', false, false),
      ('h_heal', 'Alt+H Apex 快捷打大电/医疗箱', 'h', 'digit4', false, true, 'Apex 英雄快速使用护盾电池', false, false),
      ('j_ult_acc', 'Alt+J Apex 绝招加速剂', 'j', 'z', false, true, '快捷触发终极技能道具', false, false),
      ('m_map_fps', 'Alt+M 展开全局战术大地图', 'm', 'm', false, true, 'PUBG / Apex 展开全局航线地图', false, false),
      ('n_firemode', 'Alt+N 切换全自动/单发点射', 'n', 'b', false, true, '步枪远距离单点快速切换', false, false),
      ('u_teamchat', 'Alt+U 队内文字聊天框', 'u', 'u', false, true, '打开仅小队可见文字输入', false, false),
      ('i_inventory', 'Alt+I 舔包物资栏开关', 'i', 'tab', false, true, '快速打开附近地面物资列表', false, false),
      ('p_mute_all', 'Alt+P 一键静音全场语音', 'p', 'f10', false, true, '残局 1vN 一键屏蔽干扰语音', false, false),
    ];
    for (final (slug, title, sKey, dKey, sShift, sAlt, desc, dCtrl, dShift)
        in fpsRules) {
      list.add(BbsKeyMapEntry(
        id: 'fps_$slug',
        name: 'FPS 竞技 · $title',
        desc: desc,
        category: 'gaming',
        subGroup: 'FPS 战术射击 (CS2/无畏契约/Apex)',
        srcHost: 'any',
        peer: 'windows',
        srcKey: sKey,
        srcShift: sShift,
        srcAlt: sAlt,
        dstKey: dKey,
        dstCtrl: dCtrl,
        dstShift: dShift,
        presets: const {'fps_esports'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'fps_mac_$slug',
        name: 'FPS 跨平台 · $title (远端Mac)',
        desc: '$desc (适配远端 macOS 游戏客户端)',
        category: 'gaming',
        subGroup: 'FPS 战术射击 (CS2/无畏契约/Apex)',
        srcHost: 'any',
        peer: 'macos',
        srcKey: sKey,
        srcShift: sShift,
        srcAlt: sAlt,
        dstKey: dKey,
        dstCtrl: dCtrl,
        dstShift: dShift,
        presets: const {'fps_esports'},
      ));
    }

    // 4B. 原神 / 鸣潮 / 崩坏星穹铁道 / 绝区零 开放世界动作键位 (44 items)
    const openWorldRules = <(String, String, String, bool, bool, String, bool, String)>[
      ('ult_1', '切 1 号位并秒放元素爆发', 'digit1', true, false, 'digit1', true, '触发 Alt+1 切人即开大招'),
      ('ult_2', '切 2 号位并秒放元素爆发', 'digit2', true, false, 'digit2', true, '触发 Alt+2 切人即开大招'),
      ('ult_3', '切 3 号位并秒放元素爆发', 'digit3', true, false, 'digit3', true, '触发 Alt+3 切人即开大招'),
      ('ult_4', '切 4 号位并秒放元素爆发', 'digit4', true, false, 'digit4', true, '触发 Alt+4 切人即开大招'),
      ('trial_5', '切 5 号试用角色上场', 'digit5', true, false, 'digit5', false, '剧情秘境第 5 角色顺手切换'),
      ('elem_sight', '一键开启元素视野/感知', 'backquote', false, false, 'kp_divide', false, '解决远程鼠标中键不好按的元素视野痛点'),
      ('echo_skill', '鸣潮 · 声骸技能顺手释放 (Q)', 'caps_lock', false, false, 'q', false, '大拇指/小指秒放主音骸技能'),
      ('grapple_t', '探索工具/钩锁/流萤速切', 'g', false, true, 't', false, '一键触发探索钩锁或小道具 Z/T'),
      ('gadget_z', '快捷使用便携营养袋/小道具', 'z', false, true, 'z', false, '战斗中秒吃回血料理或放锚点'),
      ('open_map', '快速展开提瓦特/索拉里斯地图', 'm', false, true, 'm', false, '传送锚点大地图快速开关'),
      ('open_bag', '打开武器圣遗物背包', 'b', false, true, 'b', false, '快速更换武器与声骸装备'),
      ('char_screen', '打开角色属性命座面板', 'c', false, true, 'c', false, '查看角色面板暴击充能属性'),
      ('wish_banner', '打开祈愿/唤取卡池界面', 'f3', false, true, 'f3', false, 'Mac 免按 Fn 直达卡池界面'),
      ('battle_pass', '打开纪行/先约电台奖励', 'f4', false, true, 'f4', false, 'Mac 免按 Fn 领取每日纪行经验'),
      ('events_f5', '打开限时活动总览面板', 'f5', false, true, 'f5', false, '一键查看当前版本限时活动'),
      ('handbook_f1', '打开冒险之证/讨伐手册', 'f1', false, true, 'f1', false, '追踪BOSS刷新与日常委托'),
      ('coop_f2', '打开多人联机匹配面板', 'f2', false, true, 'f2', false, '周本秘境快速联机匹配'),
      ('quest_j', '打开任务追踪日志', 'j', false, true, 'j', false, '切换主线与世界任务追踪'),
      ('quest_nav', '追踪当前任务目标指引 (V)', 'v', false, true, 'v', false, '刷新大世界任务金色光路导航'),
      ('walk_run', '切换慢走散步/跑步姿态', 'backslash', false, false, 'ctrl', false, '大世界拍照沉浸慢走切换'),
      ('auto_play', '剧情对话自动播放开关', 'p', false, true, 'f', false, '剧情过场快速推进对话交互'),
      ('sr_speed', '星铁 · 战斗二倍速切换', 'r', false, true, 'v', false, '崩坏星穹铁道回合制倍速与自动战斗'),
    ];
    for (final (slug, title, sKey, sShift, sAlt, dKey, dAlt, desc)
        in openWorldRules) {
      list.add(BbsKeyMapEntry(
        id: 'ow_win_$slug',
        name: '开放世界 · $title (Win端)',
        desc: desc,
        category: 'gaming',
        subGroup: '原神 / 鸣潮 / 星铁 / 绝区零',
        srcHost: 'any',
        peer: 'windows',
        srcKey: sKey,
        srcShift: sShift,
        srcAlt: sAlt,
        dstKey: dKey,
        dstAlt: dAlt,
        presets: const {'open_world'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'ow_mac_$slug',
        name: '开放世界 · $title (Mac端)',
        desc: '$desc (适配远端 Mac 原生/PlayCover 客户端)',
        category: 'gaming',
        subGroup: '原神 / 鸣潮 / 星铁 / 绝区零',
        srcHost: 'any',
        peer: 'macos',
        srcKey: sKey,
        srcShift: sShift,
        srcAlt: sAlt,
        dstKey: dKey,
        dstAlt: dAlt,
        presets: const {'open_world'},
      ));
    }

    // 4C. MOBA 竞技 (英雄联盟 LOL / Dota2 / 永劫无间 - 44 items)
    const mobaRules = <(String, String, String, bool, bool, String, bool, bool, String)>[
      ('self_q', '英雄自我施放 Q 技能 (Alt+Q)', 'q', true, false, 'q', false, true, '护盾/加血秒给自身无需鼠标移回'),
      ('self_w', '英雄自我施放 W 技能 (Alt+W)', 'w', true, false, 'w', false, true, '露露/盲僧/莫甘娜秒套自身护盾'),
      ('self_e', '英雄自我施放 E 技能 (Alt+E)', 'e', true, false, 'e', false, true, '卡尔玛/发条秒给自己加速球'),
      ('self_r', '英雄自我施放 R 大招 (Alt+R)', 'r', true, false, 'r', false, true, '冰女/天使/时光老头绝境自救大招'),
      ('lvl_q', '秒升 Q 技能等级 (Ctrl+Q)', 'digit1', false, true, 'q', true, false, '对线抢 2 级/6 级瞬秒加点 Q'),
      ('lvl_w', '秒升 W 技能等级 (Ctrl+W)', 'digit2', false, true, 'w', true, false, '瞬秒加点升级 W 技能'),
      ('lvl_e', '秒升 E 技能等级 (Ctrl+E)', 'digit3', false, true, 'e', true, false, '瞬秒加点升级 E 技能'),
      ('lvl_r', '秒升 R 终极技能 (Ctrl+R)', 'digit4', false, true, 'r', true, false, '到 6 级瞬间点亮大招反打'),
      ('item_active_1', '主动装备栏 1 金身沙漏顺手键', 'caps_lock', false, false, 'digit2', false, false, '团战小指秒按中娅沙漏保命'),
      ('item_active_2', '主动装备栏 2 破败/推推棒', 'backquote', false, false, 'digit1', false, false, '波浪键秒触发第一格主动装备'),
      ('item_ward', '饰品眼/扫描透镜顺手键', 't', false, true, 'digit4', false, false, '摸眼穿墙/排眼一键触发 4 号位饰品'),
      ('shop_toggle', '快捷打开泉水装备商店 (P)', 'p', false, true, 'p', false, false, '回城途中快速检索合成装备'),
      ('cam_lock', '锁定/解锁英雄中心视角 (Y)', 'y', false, true, 'y', false, false, '团战找回自己英雄位置'),
      ('ally_cam_1', '切屏观察上单队友视角 (F2)', 'f2', true, false, 'f2', false, false, '支援前一键查看上路兵线血量'),
      ('ally_cam_2', '切屏观察打野队友视角 (F3)', 'f3', true, false, 'f3', false, false, '查看己方打野动向配合抓人'),
      ('ally_cam_3', '切屏观察中单队友视角 (F4)', 'f4', true, false, 'f4', false, false, '查看中路对线状态'),
      ('ally_cam_4', '切屏观察下路队友视角 (F5)', 'f5', true, false, 'f5', false, false, 'TP 传送前观察下路战场'),
      ('atk_move', '走A攻击型移动指令 (A键点地)', 'x', false, true, 'a', false, false, 'ADC 极限攻速风筝走砍辅助键'),
      ('stop_hold', '原地急停取消平A后摇 (S)', 's', false, true, 's', false, false, '补刀控线与假动作骗技能急停'),
      ('naraka_parry', '永劫无间 · 一键快捷振刀 (G)', 'g', false, false, 'g', false, false, '远程零延迟单键触发快捷振刀'),
      ('naraka_grapple', '永劫无间 · 飞索瞄准发射 (Q)', 'q', false, true, 'q', false, false, '快速钩锁追击残血敌人'),
      ('naraka_ult', '永劫无间 · 奥义大招释放 (V)', 'v', false, true, 'v', false, false, '受击反手开启英雄奥义'),
    ];
    for (final (slug, title, sKey, sShift, sAlt, dKey, dCtrl, dAlt, desc)
        in mobaRules) {
      list.add(BbsKeyMapEntry(
        id: 'moba_win_$slug',
        name: 'MOBA 竞技 · $title',
        desc: desc,
        category: 'gaming',
        subGroup: 'MOBA 竞技 (LOL / Dota2 / 永劫无间)',
        srcHost: 'any',
        peer: 'windows',
        srcKey: sKey,
        srcShift: sShift,
        srcAlt: sAlt,
        dstKey: dKey,
        dstCtrl: dCtrl,
        dstAlt: dAlt,
        presets: const {'moba_arena'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'moba_mac_$slug',
        name: 'MOBA 跨端 · $title (Mac端)',
        desc: '$desc (适配远端 Mac League / Dota2 客户端)',
        category: 'gaming',
        subGroup: 'MOBA 竞技 (LOL / Dota2 / 永劫无间)',
        srcHost: 'any',
        peer: 'macos',
        srcKey: sKey,
        srcShift: sShift,
        srcAlt: sAlt,
        dstKey: dKey,
        dstCtrl: dCtrl,
        dstAlt: dAlt,
        presets: const {'moba_arena'},
      ));
    }

    // 4D. MMORPG 大型网游与模拟器街机键位 (魔兽世界 / FF14 / 剑网3 / 模拟器 - 42 items)
    // Auto-run NumLock & Action Bar 2/3 combos + Arcade Emulator P1/P2
    for (var i = 1; i <= 9; i++) {
      final key = 'digit$i';
      list.add(BbsKeyMapEntry(
        id: 'mmo_bar2_$i',
        name: 'MMO 网游 · 副动作条技能栏 #$i',
        desc: 'Mac ⌘$i 映射为远端网游 Shift+$i 副技能栏 (魔兽/FF14/剑网3)',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: key,
        srcMeta: true,
        dstKey: key,
        dstShift: true,
        presets: const {'mmo_numpad'},
      ));
      list.add(BbsKeyMapEntry(
        id: 'mmo_bar3_$i',
        name: 'MMO 网游 · 第三动作条技能栏 #$i',
        desc: 'Mac ⌥⇧$i 映射为远端网游 Ctrl+$i 第三技能栏',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'mac',
        peer: 'windows',
        srcKey: key,
        srcAlt: true,
        srcShift: true,
        dstKey: key,
        dstCtrl: true,
        presets: const {'mmo_numpad'},
      ));
    }

    const mmoAndArcadeExtra = <BbsKeyMapEntry>[
      BbsKeyMapEntry(
        id: 'mmo_autorun_numlock',
        name: 'MMO 网游 · Mac 一键自动奔跑 (NumLock)',
        desc: 'Mac 键盘无 NumLock 键，按 ⌃` 触发魔兽/FF14 自动前进奔跑',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'backquote',
        srcCtrl: true,
        dstKey: 'num_lock',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'mmo_mount_up',
        name: 'MMO 网游 · 召唤飞行坐骑快捷键',
        desc: '按 ⌥` 触发 Shift+Space 坐骑召唤热键',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'backquote',
        srcAlt: true,
        dstKey: 'space',
        dstShift: true,
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'mmo_target_nearest',
        name: 'MMO 网游 · 切换最近敌方目标',
        desc: 'CapsLock 映射为 Tab 键快速切怪，不伤小指',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'caps_lock',
        dstKey: 'tab',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'mmo_target_prev',
        name: 'MMO 网游 · 反向切换上一敌方目标',
        desc: 'Shift+CapsLock 映射为 Shift+Tab',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'caps_lock',
        srcShift: true,
        dstKey: 'tab',
        dstShift: true,
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'mmo_focus_target',
        name: 'MMO 网游 · 设为焦点目标 (Focus)',
        desc: '⌃F 映射为 Alt+F 快速锁定团本 BOSS 焦点读条',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'f',
        srcCtrl: true,
        dstKey: 'f',
        dstAlt: true,
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'mmo_assist_target',
        name: 'MMO 网游 · 协助主坦克目标 (F键协助)',
        desc: '⌃T 映射为 F 键选中坦克当前集火目标',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 't',
        srcCtrl: true,
        dstKey: 'f',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'mmo_hide_ui_photo',
        name: 'MMO 网游 · 隐藏全部界面沉浸截图 (Alt+Z)',
        desc: '⌃⇧Z 映射为魔兽/FF14 隐藏 UI 纯净风景截图键',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'z',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'z',
        dstAlt: true,
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'emu_coin_select',
        name: '模拟器街机 · 投币键 (Select / Coin)',
        desc: '按 ⌃5 触发街机模拟器 5 号投币键',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'all',
        srcKey: 'digit5',
        srcCtrl: true,
        dstKey: 'backspace',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'emu_p1_start',
        name: '模拟器街机 · 1P 开始键 (Start)',
        desc: '按 ⌃1 触发模拟器 Enter 开始键',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'all',
        srcKey: 'digit1',
        srcCtrl: true,
        dstKey: 'enter',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'emu_save_state',
        name: '模拟器街机 · 即时存档 (Save State F1)',
        desc: '按 ⌃S 触发 RetroArch/模拟器 F2 即时存档',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'all',
        srcKey: 'f2',
        srcCtrl: true,
        dstKey: 'f2',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'emu_load_state',
        name: '模拟器街机 · 即时读档 (Load State F4)',
        desc: '按 ⌃F4 触发模拟器即时读档回溯',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'all',
        srcKey: 'f4',
        srcCtrl: true,
        dstKey: 'f4',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'emu_fast_forward',
        name: '模拟器街机 · 倍速快进跳过动画',
        desc: '按 ⌃Space 触发模拟器快进键',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'all',
        srcKey: 'space',
        srcCtrl: true,
        dstKey: 'space',
        presets: {'mmo_numpad'},
      ),
      // GTA / Flight Sim Numpad Pitch/Roll controls without Numpad (12 items)
      BbsKeyMapEntry(
        id: 'gta_fly_pitch_down',
        name: 'GTA/飞行驾驶 · 机头下压 (Numpad 8)',
        desc: '无小键盘笔记本按 ⌃↑ 映射小键盘 8 控制飞机俯冲',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'arrow_up',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'kp_8',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'gta_fly_pitch_up',
        name: 'GTA/飞行驾驶 · 机头拉起 (Numpad 5)',
        desc: '无小键盘笔记本按 ⌃⇧↓ 映射小键盘 5 控制飞机拉升',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'arrow_down',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'kp_5',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'gta_fly_roll_left',
        name: 'GTA/飞行驾驶 · 左横滚侧倾 (Numpad 4)',
        desc: '无小键盘笔记本按 ⌃⇧← 映射小键盘 4 左横滚',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'arrow_left',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'kp_4',
        presets: {'mmo_numpad'},
      ),
      BbsKeyMapEntry(
        id: 'gta_fly_roll_right',
        name: 'GTA/飞行驾驶 · 右横滚侧倾 (Numpad 6)',
        desc: '无小键盘笔记本按 ⌃⇧→ 映射小键盘 6 右横滚',
        category: 'gaming',
        subGroup: 'MMO 网游与街机模拟器',
        srcHost: 'any',
        peer: 'windows',
        srcKey: 'arrow_right',
        srcCtrl: true,
        srcShift: true,
        dstKey: 'kp_6',
        presets: {'mmo_numpad'},
      ),
    ];
    list.addAll(mmoAndArcadeExtra);

    return list;
  }
}
