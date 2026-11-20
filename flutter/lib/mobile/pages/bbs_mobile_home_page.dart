import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/mobile/pages/scan_page.dart';
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/key_mapping_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';

class BbsMobileHomePage extends StatefulWidget {
  const BbsMobileHomePage({Key? key}) : super(key: key);

  @override
  State<BbsMobileHomePage> createState() => _BbsMobileHomePageState();
}

class _BbsMobileHomePageState extends State<BbsMobileHomePage> {
  int _tabIndex = 0;

  // Login state
  late final TextEditingController _userCtrl;
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loggingIn = false;
  String _loginError = '';

  // Devices & Quick assist
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  final IDTextEditingController _manualIdCtrl = IDTextEditingController();
  final TextEditingController _manualPassCtrl = TextEditingController();
  bool _manualForceRelay = false;

  String _myId = '';
  String _myHostname = '';
  bool _svcReady = false;
  Timer? _pollTimer;
  int _tick = 0;

  // Settings cache
  String _imageQuality = 'custom';
  double _customFps = 120;
  double _customMbps = 150;
  bool _enableTrueColor = false;
  bool _enableHdr = false;
  bool _forceRelayDefault = false;
  bool _enableSound = true;
  bool _enableClipboard = true;
  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    final savedName = UserModel.getLocalUserInfo()?['name']?.toString() ?? '';
    _userCtrl = TextEditingController(text: savedName);
    _initAll();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _onTick());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _searchCtrl.dispose();
    _manualIdCtrl.dispose();
    _manualPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAll() async {
    BbsKeyMappingCenter.instance.ensureInitialized();
    _loadSettings();
    await _refreshLocalInfo();
    if (gFFI.userModel.isLogin) {
      gFFI.userModel.refreshCurrentUser();
      await _refreshDevices(quiet: true);
    } else {
      final token = bind.mainGetLocalOption(key: 'access_token');
      if (token.isNotEmpty) {
        gFFI.userModel.refreshCurrentUser();
      }
    }
  }

  void _loadSettings() {
    final iq = bind.mainGetUserDefaultOption(key: kOptionImageQuality);
    _imageQuality = iq.isEmpty ? 'custom' : iq;

    final fpsStr = bind.mainGetUserDefaultOption(key: 'custom-fps');
    _customFps = (double.tryParse(fpsStr) ?? 120).clamp(30, 240);

    final cqStr = bind.mainGetUserDefaultOption(key: 'custom_image_quality');
    final cqVal = double.tryParse(cqStr);
    if (cqVal != null && cqVal >= 2005) {
      _customMbps = (cqVal - 2000).clamp(5, 500);
    } else {
      _customMbps = 150;
    }

    _enableTrueColor =
        bind.mainGetUserDefaultOption(key: kOptionI444) == 'Y';
    _enableHdr =
        bind.mainGetLocalOption(key: 'bbs_enable_hdr') == 'Y';
    _forceRelayDefault =
        bind.mainGetLocalOption(key: 'bbs_force_relay_default') == 'Y';
    _enableSound =
        bind.mainGetUserDefaultOption(key: kOptionDisableAudio) != 'Y';
    _enableClipboard =
        bind.mainGetUserDefaultOption(key: kOptionDisableClipboard) != 'Y';
    _themeMode = MyTheme.getThemeModePreference().toShortString();
    if (mounted) setState(() {});
  }

  Future<void> _refreshLocalInfo() async {
    try {
      final id = await bind.mainGetMyId();
      String host = Platform.localHostname;
      try {
        final info = jsonDecode(bind.mainGetLoginDeviceInfo());
        if (info is Map && (info['name']?.toString().isNotEmpty ?? false)) {
          host = info['name'].toString();
        }
      } catch (_) {}
      bool ready = _svcReady;
      try {
        final statusStr = await bind.mainGetConnectStatus();
        final statusObj = jsonDecode(statusStr);
        ready = (statusObj['status_num'] ?? 0) == 1;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _myId = id;
          _myHostname = host;
          _svcReady = ready;
        });
      }
    } catch (_) {}
  }

  Future<void> _onTick() async {
    _tick++;
    await _refreshLocalInfo();
    if (gFFI.userModel.isLogin && _tick % 4 == 0) {
      await _refreshDevices(quiet: true);
    }
  }

  Future<void> _refreshDevices({bool quiet = false}) async {
    if (!gFFI.userModel.isLogin) return;
    await gFFI.abModel.pullAb(
      force: gFFI.abModel.listInitialized
          ? ForcePullAb.current
          : ForcePullAb.listAndCurrent,
      quiet: quiet,
    );
    final ids = gFFI.abModel.currentAbPeers
        .map((p) => p.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isNotEmpty) {
      bind.queryOnlines(ids: ids);
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleLogin() async {
    if (_loggingIn) return;
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;
    if (username.isEmpty) {
      setState(() => _loginError = '请输入管理员分配的专属账号');
      return;
    }
    if (password.isEmpty) {
      setState(() => _loginError = '请输入登录密码');
      return;
    }
    setState(() {
      _loggingIn = true;
      _loginError = '';
    });
    try {
      final myId = await bind.mainGetMyId();
      final uuid = await bind.mainGetUuid();
      final resp = await gFFI.userModel.login(LoginRequest(
        username: username,
        password: password,
        id: myId,
        uuid: uuid,
        autoLogin: true,
        type: HttpType.kAuthReqTypeAccount,
      ));
      if (resp.access_token != null && resp.access_token!.isNotEmpty) {
        await bind.mainSetLocalOption(
            key: 'access_token', value: resp.access_token!);
        await bind.mainSetLocalOption(
            key: 'user_info', value: jsonEncode(resp.user ?? {}));
        _passCtrl.clear();
        gFFI.userModel.refreshCurrentUser();
        await UserModel.updateOtherModels();
        await _refreshDevices(quiet: false);
      } else {
        setState(() => _loginError = '登录响应异常，请重试');
      }
    } on RequestException catch (err) {
      setState(() => _loginError = err.cause.isNotEmpty ? err.cause : '账号或密码错误');
    } catch (err) {
      setState(() => _loginError = '无法连接认证服务器，请检查网络 ($err)');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _connectPeer(
    Peer peer, {
    bool isFileTransfer = false,
    bool isTcpTunneling = false,
    bool? forceRelay,
  }) async {
    if (peer.id == _myId) {
      showToast('这是当前正在使用的本机设备');
      return;
    }
    if (peer.alias.isNotEmpty) {
      try {
        await bind.mainSetPeerAlias(id: peer.id, alias: peer.alias);
      } catch (_) {}
    }
    final pwd = peer.password;
    await connect(
      context,
      peer.id,
      password: pwd.isNotEmpty ? pwd : null,
      isSharedPassword: pwd.isNotEmpty,
      isFileTransfer: isFileTransfer,
      isTcpTunneling: isTcpTunneling,
      forceRelay: forceRelay ?? _forceRelayDefault,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
      if (!loggedIn) {
        return _buildLoginScaffold(context);
      }
      return _buildWorkspaceScaffold(context);
    });
  }

  Widget _buildLoginScaffold(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A84FF), Color(0xFF0055D4)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.desktop_mac_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'BBS-Remote',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '登录专属账号，一键免密高速远控',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _userCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '管理员分配的专属账号',
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: '登录密码',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (_loginError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _loginError,
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _loggingIn ? null : _handleLogin,
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                        ),
                        child: _loggingIn
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                '立即登录并同步设备',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _svcReady ? Colors.green : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _svcReady
                              ? '专线与 P2P 通道就绪 · ID ${formatID(_myId)}'
                              : '正在连接节点...',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspaceScaffold(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.devices_outlined),
        selectedIcon: Icon(Icons.devices_rounded),
        label: '我的设备',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bolt_outlined),
        selectedIcon: Icon(Icons.bolt_rounded),
        label: '快捷协助',
      ),
      if (isAndroid)
        const NavigationDestination(
          icon: Icon(Icons.screen_share_outlined),
          selectedIcon: Icon(Icons.screen_share_rounded),
          label: '本机被控',
        ),
      const NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune_rounded),
        label: '设置中心',
      ),
    ];

    final pages = <Widget>[
      _buildDevicesTab(context),
      _buildQuickAssistTab(context),
      if (isAndroid) ServerPage(),
      _buildSettingsTab(context),
    ];

    final safeIdx = _tabIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          safeIdx == 0
              ? 'BBS-Remote'
              : destinations[safeIdx].label,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (safeIdx == 0)
            IconButton(
              tooltip: '刷新在线状态',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                _refreshDevices(quiet: false);
                showToast('已刷新设备列表');
              },
            ),
          if (safeIdx == 1)
            IconButton(
              tooltip: '扫码连接',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ScanPage()),
                );
              },
            ),
        ],
      ),
      body: pages[safeIdx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIdx,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: destinations,
      ),
    );
  }

  Widget _buildDevicesTab(BuildContext context) {
    final theme = Theme.of(context);
    final peers = List<Peer>.from(gFFI.abModel.currentAbPeers);
    final q = _searchQuery.trim().toLowerCase();
    final filtered = peers.where((p) {
      if (q.isEmpty) return true;
      return p.alias.toLowerCase().contains(q) ||
          p.hostname.toLowerCase().contains(q) ||
          p.id.contains(q) ||
          p.platform.toLowerCase().contains(q);
    }).toList();

    filtered.sort((a, b) {
      final aSelf = a.id == _myId;
      final bSelf = b.id == _myId;
      if (aSelf != bSelf) return aSelf ? 1 : -1;
      if (a.online != b.online) return a.online ? -1 : 1;
      final an = a.alias.isNotEmpty ? a.alias : a.hostname;
      final bn = b.alias.isNotEmpty ? b.alias : b.hostname;
      return an.toLowerCase().compareTo(bn.toLowerCase());
    });

    return RefreshIndicator(
      onRefresh: () => _refreshDevices(quiet: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Local host pill
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.35),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  child: Icon(
                    isIOS ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${gFFI.userModel.userName.value} · ${_myHostname.isEmpty ? "当前手机" : _myHostname}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID ${formatID(_myId)} · 4K 144Hz · 500Mbps 专线已解锁',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '复制本机 ID',
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _myId));
                    showToast('已复制本机 ID：${formatID(_myId)}');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Search box
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: '搜索设备名称、系统或 ID...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.devices_other_rounded,
                      size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  const Text('暂无绑定设备',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '在电脑端登录同一账号后，下拉即可一键免密远控',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((peer) => _buildDeviceCard(context, peer)),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, Peer peer) {
    final theme = Theme.of(context);
    final isSelf = peer.id == _myId;
    final name = peer.alias.isNotEmpty
        ? peer.alias
        : (peer.hostname.isNotEmpty ? peer.hostname : formatID(peer.id));
    final plat = peer.platform.toLowerCase();
    final IconData icon = plat.contains('mac') || plat.contains('darwin')
        ? Icons.laptop_mac_rounded
        : plat.contains('win')
            ? Icons.desktop_windows_rounded
            : plat.contains('android') || plat.contains('ios')
                ? Icons.smartphone_rounded
                : Icons.computer_rounded;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.14)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (peer.online
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline)
                        .withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: peer.online
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isSelf) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '本机',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: peer.online ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${peer.online ? "在线" : "离线"} · ${peer.platform.isEmpty ? "Desktop" : peer.platform} · ${formatID(peer.id)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isSelf)
                  PopupMenuButton<String>(
                    onSelected: (action) {
                      if (action == 'relay') {
                        _connectPeer(peer, forceRelay: true);
                      } else if (action == 'file') {
                        _connectPeer(peer, isFileTransfer: true);
                      } else if (action == 'port') {
                        _connectPeer(peer, isTcpTunneling: true);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'relay',
                        child: Text('强制 500Mbps 专线中转连接'),
                      ),
                      PopupMenuItem(
                        value: 'file',
                        child: Text('高速远程文件传输'),
                      ),
                      PopupMenuItem(
                        value: 'port',
                        child: Text('TCP 端口映射隧道'),
                      ),
                    ],
                  ),
              ],
            ),
            if (!isSelf) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _connectPeer(peer),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('一键远程控制'),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _connectPeer(peer, isFileTransfer: true),
                    icon: const Icon(Icons.folder_copy_outlined, size: 17),
                    label: const Text('传文件'),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAssistTab(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.14)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '输入对方设备识别码',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '支持临时协助未绑定到本账号的 Mac / Windows / Android 设备',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _manualIdCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '9 位设备识别码（如 123 456 789）',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _manualPassCtrl,
                  decoration: InputDecoration(
                    labelText: '访问密码（选填，留空则连接时弹出输入）',
                    prefixIcon: const Icon(Icons.key_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('使用 500Mbps 专线中转'),
                  subtitle: const Text('跨网段 / 弱网时强制走高带宽中转节点'),
                  value: _manualForceRelay,
                  onChanged: (v) => setState(() => _manualForceRelay = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          final id = _manualIdCtrl.id.trim();
                          if (id.isEmpty) {
                            showToast('请先输入 9 位设备识别码');
                            return;
                          }
                          final pwd = _manualPassCtrl.text.trim();
                          connect(
                            context,
                            id,
                            password: pwd.isNotEmpty ? pwd : null,
                            isSharedPassword: pwd.isNotEmpty,
                            forceRelay: _manualForceRelay,
                          );
                        },
                        icon: const Icon(Icons.cast_connected_rounded),
                        label: const Text('立即远控'),
                        style: FilledButton.styleFrom(
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () {
                        final id = _manualIdCtrl.id.trim();
                        if (id.isEmpty) {
                          showToast('请先输入设备识别码');
                          return;
                        }
                        final pwd = _manualPassCtrl.text.trim();
                        connect(
                          context,
                          id,
                          password: pwd.isNotEmpty ? pwd : null,
                          isSharedPassword: pwd.isNotEmpty,
                          isFileTransfer: true,
                          forceRelay: _manualForceRelay,
                        );
                      },
                      icon: const Icon(Icons.folder_outlined),
                      label: const Text('文件'),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        minimumSize: const Size(88, 46),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    final km = BbsKeyMappingCenter.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _sectionHeader('画质与极限性能（4K 原画 · 500Mbps 全解锁）'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              ListTile(
                title: const Text('画质模式'),
                trailing: DropdownButton<String>(
                  value: ['best', 'balanced', 'low', 'custom']
                          .contains(_imageQuality)
                      ? _imageQuality
                      : 'custom',
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'custom', child: Text('4K 原画自定义')),
                    DropdownMenuItem(value: 'best', child: Text('画质优先')),
                    DropdownMenuItem(value: 'balanced', child: Text('智能均衡')),
                    DropdownMenuItem(value: 'low', child: Text('流畅优先')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _imageQuality = v);
                    await bind.mainSetUserDefaultOption(
                        key: kOptionImageQuality, value: v);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('目标码率上限'),
                        Text('${_customMbps.round()} Mbps',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Slider(
                      value: _customMbps,
                      min: 5,
                      max: 500,
                      divisions: 99,
                      onChanged: (v) => setState(() => _customMbps = v),
                      onChangeEnd: (v) async {
                        await bind.mainSetUserDefaultOption(
                          key: 'custom_image_quality',
                          value: (2000 + v.round()).toString(),
                        );
                        await bind.mainSetUserDefaultOption(
                          key: kOptionImageQuality,
                          value: 'custom',
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('目标帧率上限'),
                        Text('${_customFps.round()} FPS',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    Slider(
                      value: _customFps,
                      min: 30,
                      max: 240,
                      divisions: 21,
                      onChanged: (v) => setState(() => _customFps = v),
                      onChangeEnd: (v) async {
                        await bind.mainSetUserDefaultOption(
                          key: 'custom-fps',
                          value: v.round().toString(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('真彩无损模式 (YUV 4:4:4)'),
                subtitle: const Text('文字、代码与设计色准零色度压缩'),
                value: _enableTrueColor,
                onChanged: (v) async {
                  setState(() => _enableTrueColor = v);
                  await bind.mainSetUserDefaultOption(
                    key: kOptionI444,
                    value: v ? 'Y' : '',
                  );
                },
              ),
              SwitchListTile(
                title: const Text('HDR 广色域对比度增强'),
                value: _enableHdr,
                onChanged: (v) async {
                  setState(() => _enableHdr = v);
                  await bind.mainSetLocalOption(
                    key: 'bbs_enable_hdr',
                    value: v ? 'Y' : '',
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader('网络通道与 544+ 按键映射'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('默认强制 500Mbps 专线中转'),
                subtitle: const Text('关闭时自动优先 P2P 低延迟直连'),
                value: _forceRelayDefault,
                onChanged: (v) async {
                  setState(() => _forceRelayDefault = v);
                  await bind.mainSetLocalOption(
                    key: 'bbs_force_relay_default',
                    value: v ? 'Y' : '',
                  );
                },
              ),
              SwitchListTile(
                title: Text('按键映射引擎（内置 ${km.allEntries.length} 项）'),
                subtitle: const Text('外接键盘控制 Mac / Windows 实时映射'),
                value: km.masterEnabled,
                onChanged: (v) async {
                  await km.setMasterEnabled(v);
                  setState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('远程音频同步'),
                value: _enableSound,
                onChanged: (v) async {
                  setState(() => _enableSound = v);
                  await bind.mainSetUserDefaultOption(
                    key: kOptionDisableAudio,
                    value: v ? '' : 'Y',
                  );
                },
              ),
              SwitchListTile(
                title: const Text('双向剪贴板同步'),
                value: _enableClipboard,
                onChanged: (v) async {
                  setState(() => _enableClipboard = v);
                  await bind.mainSetUserDefaultOption(
                    key: kOptionDisableClipboard,
                    value: v ? '' : 'Y',
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader('外观与账号'),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              ListTile(
                title: const Text('外观主题'),
                trailing: DropdownButton<String>(
                  value: ['system', 'light', 'dark'].contains(_themeMode)
                      ? _themeMode
                      : 'system',
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'system', child: Text('跟随系统')),
                    DropdownMenuItem(value: 'light', child: Text('浅色')),
                    DropdownMenuItem(value: 'dark', child: Text('深色')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _themeMode = v);
                    await MyTheme.changeDarkMode(
                        MyTheme.themeModeFromString(v));
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('退出当前账号',
                    style: TextStyle(color: Colors.redAccent)),
                subtitle: Text('当前账号：${gFFI.userModel.userName.value}'),
                onTap: () async {
                  await gFFI.userModel.logOut();
                  setState(() => _tabIndex = 0);
                  showToast('已退出登录');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
