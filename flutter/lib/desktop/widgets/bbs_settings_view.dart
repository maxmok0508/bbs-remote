import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class BbsSettingsView extends StatefulWidget {
  const BbsSettingsView({Key? key}) : super(key: key);

  @override
  State<BbsSettingsView> createState() => _BbsSettingsViewState();
}

class _BbsSettingsViewState extends State<BbsSettingsView> {
  String _imageQuality = kRemoteImageQualityBest;
  double _customFps = 120.0;
  double _customQuality = 100.0;
  String _codecPref = 'auto';
  String _viewStyle = kRemoteViewStyleAdaptive;
  bool _hwCodec = true;
  bool _showQualityMonitor = false;
  bool _enableSound = true;
  bool _enableClipboard = true;
  bool _enableFileCopy = true;
  bool _enableTrueColor = false;
  bool _directLan = true;
  String _themeMode = 'system';

  bool _canScreenRecord = true;
  bool _canAccessibility = true;
  bool _daemonInstalled = true;
  bool _repairingPermissions = false;
  Timer? _permPollTimer;

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
    if (isMacOS) {
      _refreshPerms();
      _permPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _refreshPerms();
      });
    }
  }

  @override
  void dispose() {
    _permPollTimer?.cancel();
    super.dispose();
  }

  void _refreshPerms() {
    if (!isMacOS || !mounted) return;
    final sr = bind.mainIsCanScreenRecording(prompt: false);
    final acc = bind.mainIsProcessTrusted(prompt: false);
    final dm = bind.mainIsInstalledDaemon(prompt: false);
    if (sr != _canScreenRecord ||
        acc != _canAccessibility ||
        dm != _daemonInstalled) {
      setState(() {
        _canScreenRecord = sr;
        _canAccessibility = acc;
        _daemonInstalled = dm;
      });
    }
  }

  void _loadAllSettings() {
    final q = bind.mainGetUserDefaultOption(key: kOptionImageQuality);
    _imageQuality = q.isNotEmpty ? q : kRemoteImageQualityBest;

    final fpsRaw =
        double.tryParse(bind.mainGetUserDefaultOption(key: 'custom-fps')) ??
            kDefaultFps;
    _customFps = fpsRaw.clamp(kMinFps, kMaxFps);

    final qualRaw = double.tryParse(
            bind.mainGetUserDefaultOption(key: 'custom_image_quality')) ??
        kDefaultQuality;
    _customQuality = qualRaw.clamp(10.0, 500.0);

    final c = bind.mainGetUserDefaultOption(key: kOptionCodecPreference);
    _codecPref = c.isNotEmpty ? c : 'auto';

    final vs = bind.mainGetUserDefaultOption(key: kOptionViewStyle);
    _viewStyle = vs.isNotEmpty ? vs : kRemoteViewStyleAdaptive;

    _hwCodec = bind.mainGetOptionSync(key: kOptionEnableHwcodec) != 'N';
    _showQualityMonitor =
        bind.mainGetUserDefaultOption(key: kOptionShowQualityMonitor) == 'Y';
    _enableSound =
        bind.mainGetUserDefaultOption(key: kOptionDisableAudio) != 'Y';
    _enableClipboard =
        bind.mainGetUserDefaultOption(key: kOptionDisableClipboard) != 'Y';
    _enableFileCopy =
        bind.mainGetUserDefaultOption(key: kOptionEnableFileCopyPaste) != 'N';
    _enableTrueColor =
        bind.mainGetUserDefaultOption(key: kOptionI444) == 'Y';
    _directLan = bind.mainGetOptionSync(key: kOptionDirectServer) != 'N';
    _themeMode = MyTheme.getThemeModePreference().toShortString();
  }

  Future<void> _setQualityPreset(String mode, {double? targetFps}) async {
    setState(() {
      _imageQuality = mode;
      if (targetFps != null) {
        _customFps = targetFps;
      }
    });
    await bind.mainSetUserDefaultOption(key: kOptionImageQuality, value: mode);
    if (targetFps != null) {
      await bind.mainSetUserDefaultOption(
          key: 'custom-fps', value: targetFps.round().toString());
    }
  }

  Future<void> _repairMacPermissions() async {
    if (!isMacOS || _repairingPermissions) return;
    setState(() => _repairingPermissions = true);
    try {
      await Process.run('/bin/sh', [
        '-c',
        'tccutil reset ScreenCapture com.bbs.remote 2>/dev/null || true; '
            'tccutil reset Accessibility com.bbs.remote 2>/dev/null || true; '
            'tccutil reset ListenEvent com.bbs.remote 2>/dev/null || true'
      ]);
      await bind.mainSetLocalOption(key: 'bbs_hide_perm_tip', value: '');
      bind.mainIsCanScreenRecording(prompt: true);
      bind.mainIsProcessTrusted(prompt: true);
      showToast('已清除旧版权限缓存并重新发起系统授权，请在弹出的系统窗口中重新开启');
      _refreshPerms();
    } catch (e) {
      showToast('操作异常: $e');
    } finally {
      if (mounted) {
        setState(() => _repairingPermissions = false);
      }
    }
  }

  Future<void> _relaunchApp() async {
    if (!isMacOS) return;
    final exe = File(Platform.resolvedExecutable);
    final appPath = exe.parent.parent.parent.path;
    if (appPath.endsWith('.app')) {
      await Process.start('open', ['-n', appPath]);
      await Future.delayed(const Duration(milliseconds: 350));
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF171F30) : Colors.white;
    final cardBorder =
        isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFE2E8F0);

    List<String> supportedHw = ['h265', 'h264'];
    try {
      final Map m = jsonDecode(bind.mainSupportedHwdecodings());
      supportedHw = [
        if (m['h265'] == true) 'h265',
        if (m['h264'] == true) 'h264',
      ];
    } catch (_) {}

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设置中心',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            '调整默认画质、最高 400FPS 高刷帧率、剪贴板同步及本机权限管理',
            style: TextStyle(fontSize: 12.5, color: subColor),
          ),
          const SizedBox(height: 18),

          // ==================== SECTION 1: 画质与 400FPS 高刷 ====================
          _buildSectionCard(
            title: '画面质量与高刷帧率',
            icon: Icons.speed_rounded,
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              const Text('默认画质预设',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChoicePill(
                    label: '超清原画',
                    selected: _imageQuality == kRemoteImageQualityBest,
                    isDark: isDark,
                    onTap: () => _setQualityPreset(kRemoteImageQualityBest),
                  ),
                  _buildChoicePill(
                    label: '均衡流畅',
                    selected: _imageQuality == kRemoteImageQualityBalanced,
                    isDark: isDark,
                    onTap: () => _setQualityPreset(kRemoteImageQualityBalanced),
                  ),
                  _buildChoicePill(
                    label: '极速低延迟',
                    selected: _imageQuality == kRemoteImageQualityLow,
                    isDark: isDark,
                    onTap: () => _setQualityPreset(kRemoteImageQualityLow),
                  ),
                  _buildChoicePill(
                    label: '自定义高刷 / 码率',
                    selected: _imageQuality == kRemoteImageQualityCustom,
                    isDark: isDark,
                    onTap: () => _setQualityPreset(kRemoteImageQualityCustom,
                        targetFps: _customFps),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text('目标帧率上限',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_customFps.round()} FPS',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  for (final preset in [60, 120, 144, 240, 400]) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(7),
                        onTap: () => _setQualityPreset(
                          kRemoteImageQualityCustom,
                          targetFps: preset.toDouble(),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_imageQuality ==
                                        kRemoteImageQualityCustom &&
                                    _customFps.round() == preset)
                                ? const Color(0xFF2563EB)
                                : (isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${preset}Hz',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: (_imageQuality ==
                                          kRemoteImageQualityCustom &&
                                      _customFps.round() == preset)
                                  ? Colors.white
                                  : subColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Slider(
                value: _customFps,
                min: kMinFps,
                max: kMaxFps,
                divisions: ((kMaxFps - kMinFps) / 5).round(),
                onChanged: (v) {
                  setState(() {
                    _customFps = v;
                    _imageQuality = kRemoteImageQualityCustom;
                  });
                },
                onChangeEnd: (v) async {
                  await bind.mainSetUserDefaultOption(
                      key: kOptionImageQuality,
                      value: kRemoteImageQualityCustom);
                  await bind.mainSetUserDefaultOption(
                      key: 'custom-fps', value: v.round().toString());
                },
              ),
              Row(
                children: [
                  const Text('画面码率倍率',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Text(
                    '${_customQuality.round()}% (拉高可提升高动态清晰度)',
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ),
              Slider(
                value: _customQuality,
                min: 10.0,
                max: 500.0,
                divisions: 49,
                onChanged: (v) {
                  setState(() {
                    _customQuality = v;
                    _imageQuality = kRemoteImageQualityCustom;
                  });
                },
                onChangeEnd: (v) async {
                  await bind.mainSetUserDefaultOption(
                      key: kOptionImageQuality,
                      value: kRemoteImageQualityCustom);
                  await bind.mainSetUserDefaultOption(
                      key: 'custom_image_quality', value: v.round().toString());
                },
              ),
              const Divider(height: 22),
              Row(
                children: [
                  const Text('视频编码格式',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChoicePill(
                        label: '智能自动',
                        selected: _codecPref == 'auto',
                        isDark: isDark,
                        onTap: () async {
                          setState(() => _codecPref = 'auto');
                          await bind.mainSetUserDefaultOption(
                              key: kOptionCodecPreference, value: 'auto');
                        },
                      ),
                      if (supportedHw.contains('h265'))
                        _buildChoicePill(
                          label: 'H265 (HEVC 推荐)',
                          selected: _codecPref == 'h265',
                          isDark: isDark,
                          onTap: () async {
                            setState(() => _codecPref = 'h265');
                            await bind.mainSetUserDefaultOption(
                                key: kOptionCodecPreference, value: 'h265');
                          },
                        ),
                      if (supportedHw.contains('h264'))
                        _buildChoicePill(
                          label: 'H264',
                          selected: _codecPref == 'h264',
                          isDark: isDark,
                          onTap: () async {
                            setState(() => _codecPref = 'h264');
                            await bind.mainSetUserDefaultOption(
                                key: kOptionCodecPreference, value: 'h264');
                          },
                        ),
                      _buildChoicePill(
                        label: 'AV1',
                        selected: _codecPref == 'av1',
                        isDark: isDark,
                        onTap: () async {
                          setState(() => _codecPref = 'av1');
                          await bind.mainSetUserDefaultOption(
                              key: kOptionCodecPreference, value: 'av1');
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('远控画面比例',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _buildChoicePill(
                    label: '自适应窗口缩放',
                    selected: _viewStyle == kRemoteViewStyleAdaptive,
                    isDark: isDark,
                    onTap: () async {
                      setState(() => _viewStyle = kRemoteViewStyleAdaptive);
                      await bind.mainSetUserDefaultOption(
                          key: kOptionViewStyle,
                          value: kRemoteViewStyleAdaptive);
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildChoicePill(
                    label: '1:1 原始分辨率',
                    selected: _viewStyle == kRemoteViewStyleOriginal,
                    isDark: isDark,
                    onTap: () async {
                      setState(() => _viewStyle = kRemoteViewStyleOriginal);
                      await bind.mainSetUserDefaultOption(
                          key: kOptionViewStyle,
                          value: kRemoteViewStyleOriginal);
                    },
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildSwitchRow(
                title: '启用 GPU 硬件加速编解码',
                subtitle: '使用 Apple Silicon / 显卡硬件加速，大幅降低延迟与发热',
                value: _hwCodec,
                subColor: subColor,
                onChanged: (v) async {
                  setState(() => _hwCodec = v);
                  await bind.mainSetOption(
                      key: kOptionEnableHwcodec, value: v ? 'Y' : 'N');
                  if (v) bind.mainCheckHwcodec();
                },
              ),
              _buildSwitchRow(
                title: '连接后默认显示实时帧率与 Mbps 监控面板',
                subtitle: '在远控窗口顶部实时查看当前 FPS、延迟 ms 与 Mbps 带宽',
                value: _showQualityMonitor,
                subColor: subColor,
                onChanged: (v) async {
                  setState(() => _showQualityMonitor = v);
                  await bind.mainSetUserDefaultOption(
                      key: kOptionShowQualityMonitor, value: v ? 'Y' : '');
                },
              ),
              _buildSwitchRow(
                title: '4:4:4 真彩无损文字色彩模式',
                subtitle: '适合代码编写与设计修图（对网络带宽要求更高）',
                value: _enableTrueColor,
                subColor: subColor,
                onChanged: (v) async {
                  setState(() => _enableTrueColor = v);
                  await bind.mainSetUserDefaultOption(
                      key: kOptionI444, value: v ? 'Y' : '');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ==================== SECTION 2: 交互与剪贴板同步 ====================
          _buildSectionCard(
            title: '剪贴板、声音与局域网加速',
            icon: Icons.sync_alt_rounded,
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              _buildSwitchRow(
                title: '双向自动同步剪贴板文字',
                subtitle: '本机复制文字可直接粘贴到受控电脑，反之亦然',
                value: _enableClipboard,
                subColor: subColor,
                onChanged: (v) async {
                  setState(() => _enableClipboard = v);
                  await bind.mainSetUserDefaultOption(
                      key: kOptionDisableClipboard, value: v ? '' : 'Y');
                },
              ),
              _buildSwitchRow(
                title: '跨电脑直接复制粘贴文件',
                subtitle: '支持在两台电脑之间通过 Cmd+C / Ctrl+V 直接拷贝文件',
                value: _enableFileCopy,
                subColor: subColor,
                onChanged: (v) async {
                  setState(() => _enableFileCopy = v);
                  await bind.mainSetUserDefaultOption(
                      key: kOptionEnableFileCopyPaste, value: v ? 'Y' : 'N');
                },
              ),
              _buildSwitchRow(
                title: '同步播放远端电脑声音',
                subtitle: '远控时将对方电脑的系统音频实时传输到本机',
                value: _enableSound,
                subColor: subColor,
                onChanged: (v) async {
                  setState(() => _enableSound = v);
                  await bind.mainSetUserDefaultOption(
                      key: kOptionDisableAudio, value: v ? '' : 'Y');
                },
              ),
              _buildSwitchRow(
                title: '同网络 P2P 局域网毫秒级直连',
                subtitle: '两台设备在同一局域网或可直连时自动走内网/P2P 超高速通道',
                value: _directLan,
                subColor: subColor,
                onChanged: (v) async {
                  setState(() => _directLan = v);
                  await bind.mainSetOption(
                      key: kOptionDirectServer, value: v ? 'Y' : 'N');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ==================== SECTION 3: 外观与系统权限管理 ====================
          _buildSectionCard(
            title: '界面外观与本机系统权限',
            icon: Icons.tune_rounded,
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              Row(
                children: [
                  const Text('客户端外观主题',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  _buildChoicePill(
                    label: '跟随系统',
                    selected: _themeMode == 'system',
                    isDark: isDark,
                    onTap: () async {
                      setState(() => _themeMode = 'system');
                      await MyTheme.changeDarkMode(
                          MyTheme.themeModeFromString('system'));
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildChoicePill(
                    label: '深色模式',
                    selected: _themeMode == 'dark',
                    isDark: isDark,
                    onTap: () async {
                      setState(() => _themeMode = 'dark');
                      await MyTheme.changeDarkMode(
                          MyTheme.themeModeFromString('dark'));
                    },
                  ),
                  const SizedBox(width: 8),
                  _buildChoicePill(
                    label: '浅色模式',
                    selected: _themeMode == 'light',
                    isDark: isDark,
                    onTap: () async {
                      setState(() => _themeMode = 'light');
                      await MyTheme.changeDarkMode(
                          MyTheme.themeModeFromString('light'));
                    },
                  ),
                ],
              ),
              if (isMacOS) ...[
                const Divider(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('macOS 本机被控权限状态',
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '屏幕录制: ${_canScreenRecord ? "✓ 已开启" : "未开启"}   ·   '
                            '辅助功能: ${_canAccessibility ? "✓ 已开启" : "未开启"}   ·   '
                            '开机守护服务: ${_daemonInstalled ? "✓ 已安装" : "未安装"}',
                            style: TextStyle(fontSize: 12.5, color: subColor),
                          ),
                        ],
                      ),
                    ),
                    if (!_daemonInstalled)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: () =>
                              bind.mainIsInstalledDaemon(prompt: true),
                          child: const Text('安装开机自启服务',
                              style: TextStyle(fontSize: 12.5)),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed:
                          _repairingPermissions ? null : _repairMacPermissions,
                      icon: const Icon(Icons.build_circle_outlined, size: 16),
                      label: const Text('重置修复权限识别',
                          style: TextStyle(fontSize: 12.5)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _relaunchApp,
                      icon: const Icon(Icons.restart_alt_rounded, size: 16),
                      label: const Text('重启客户端',
                          style: TextStyle(fontSize: 12.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '提示：如果升级安装包后系统设置里开关是开的但仍提示未授权，点击「重置修复权限识别」再勾选一次或点击「重启客户端」即可立即恢复。',
                  style: TextStyle(fontSize: 11.5, color: subColor),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // ==================== SECTION 4: 关于 BBS-Remote ====================
          _buildSectionCard(
            title: '关于软件',
            icon: Icons.info_outline_rounded,
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/bbs_logo.png',
                      width: 46,
                      height: 46,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.bolt_rounded,
                          size: 40,
                          color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BBS-Remote 专属定制极速版',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '版本 v1.5.3 (Apple Silicon 400FPS 高刷引擎 · 专属私有云加密节点)',
                          style: TextStyle(fontSize: 12.5, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  Obx(() {
                    final ready =
                        stateGlobal.svcStatus.value == SvcStatus.ready;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: (ready
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B))
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ready ? '● 专属节点正常' : '● 正在连接节点',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ready
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color cardBg,
    required Color cardBorder,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: const Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                title,
                style:
                    const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildChoicePill({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF2563EB)
              : (isDark
                  ? Colors.white.withOpacity(0.06)
                  : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? Colors.white
                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required Color subColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: subColor)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF2563EB),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
