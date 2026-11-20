import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/models/user_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class BbsUuHomeView extends StatefulWidget {
  const BbsUuHomeView({Key? key}) : super(key: key);

  @override
  State<BbsUuHomeView> createState() => _BbsUuHomeViewState();
}

class _BbsUuHomeViewState extends State<BbsUuHomeView> {
  int _navIndex = 0; // 0: 我的设备, 1: 本机被控权限, 2: 临时协助他人

  // Login controllers
  late final TextEditingController _userCtrl;
  final TextEditingController _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loggingIn = false;
  String _loginError = '';

  // Device search & local info
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _myId = '';
  String _myHostname = '';
  bool _installingToApps = false;

  // Quick manual assist controllers
  final IDTextEditingController _manualIdCtrl = IDTextEditingController();
  final TextEditingController _manualPassCtrl = TextEditingController();
  bool _showLocalTempCode = false;

  // macOS permission states
  bool _canScreenRecord = true;
  bool _canAccessibility = true;
  bool _canInputMonitor = true;
  bool _daemonInstalled = true;

  Timer? _pollTimer;
  int _tick = 0;

  bool get _isRunningFromDmgVolume =>
      isMacOS && Platform.resolvedExecutable.startsWith('/Volumes/');

  bool get _needsMacCorePermissions =>
      isMacOS && (!_canScreenRecord || !_canAccessibility);

  @override
  void initState() {
    super.initState();
    final savedName = UserModel.getLocalUserInfo()?['name']?.toString() ?? '';
    _userCtrl = TextEditingController(text: savedName);
    _initLocalInfoAndSync();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _onPeriodicTick();
    });
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

  Future<void> _initLocalInfoAndSync() async {
    await _refreshLocalInfo();
    _refreshPermissions();
    if (gFFI.userModel.isLogin) {
      gFFI.userModel.refreshCurrentUser();
      await _refreshDevicesAndOnlines(quiet: true);
    } else {
      final token = bind.mainGetLocalOption(key: 'access_token');
      if (token.isNotEmpty) {
        gFFI.userModel.refreshCurrentUser();
      }
    }
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
      if (mounted && (id != _myId || host != _myHostname)) {
        setState(() {
          _myId = id;
          _myHostname = host;
        });
      }
    } catch (_) {}
  }

  void _refreshPermissions() {
    if (!isMacOS) return;
    final sr = bind.mainIsCanScreenRecording(prompt: false);
    final acc = bind.mainIsProcessTrusted(prompt: false);
    final inp = bind.mainIsCanInputMonitoring(prompt: false);
    final dm = bind.mainIsInstalledDaemon(prompt: false);
    if (mounted &&
        (sr != _canScreenRecord ||
            acc != _canAccessibility ||
            inp != _canInputMonitor ||
            dm != _daemonInstalled)) {
      setState(() {
        _canScreenRecord = sr;
        _canAccessibility = acc;
        _canInputMonitor = inp;
        _daemonInstalled = dm;
      });
    }
  }

  Future<void> _updateConnStatus() async {
    try {
      final status =
          jsonDecode(await bind.mainGetConnectStatus()) as Map<String, dynamic>;
      final statusNum = status['status_num'] as int? ?? 0;
      if (statusNum == 0) {
        stateGlobal.svcStatus.value = SvcStatus.connecting;
      } else if (statusNum == 1) {
        stateGlobal.svcStatus.value = SvcStatus.ready;
      } else {
        stateGlobal.svcStatus.value = SvcStatus.notReady;
      }
      if (status['video_conn_count'] is int) {
        stateGlobal.videoConnCount.value = status['video_conn_count'] as int;
      }
    } catch (_) {}
  }

  Future<void> _onPeriodicTick() async {
    _tick++;
    await _updateConnStatus();
    _refreshPermissions();
    if (_myId.isEmpty) {
      await _refreshLocalInfo();
    }
    if (gFFI.userModel.isLogin && _tick % 3 == 0) {
      await _refreshDevicesAndOnlines(quiet: true);
    }
  }

  Future<void> _refreshDevicesAndOnlines({bool quiet = false}) async {
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
        setState(() {
          _navIndex = 0;
        });
        gFFI.userModel.refreshCurrentUser();
        await UserModel.updateOtherModels();
        await _refreshDevicesAndOnlines(quiet: false);
      } else {
        setState(() => _loginError = '登录响应异常，请重试');
      }
    } on RequestException catch (err) {
      setState(() => _loginError = err.cause.isNotEmpty ? err.cause : '账号或密码错误');
    } catch (err) {
      setState(() => _loginError = '无法连接认证服务器，请检查网络 ($err)');
    } finally {
      if (mounted) {
        setState(() => _loggingIn = false);
      }
    }
  }

  Future<void> _installFromDmgToApplications() async {
    if (_installingToApps || !isMacOS) return;
    setState(() => _installingToApps = true);
    try {
      // Executable path: /Volumes/.../BBS-Remote.app/Contents/MacOS/BBS-Remote
      final exeFile = File(Platform.resolvedExecutable);
      final appBundleDir = exeFile.parent.parent.parent.path;
      const targetApp = '/Applications/BBS-Remote.app';
      final script = '''
rm -rf "$targetApp" && cp -R "$appBundleDir" "$targetApp" && xattr -cr "$targetApp"
''';
      var res = await Process.run('/bin/sh', ['-c', script]);
      if (res.exitCode != 0) {
        final osa =
            'do shell script "rm -rf /Applications/BBS-Remote.app && cp -R \\"$appBundleDir\\" /Applications/BBS-Remote.app && xattr -cr /Applications/BBS-Remote.app" with administrator privileges';
        res = await Process.run('osascript', ['-e', osa]);
      }
      if (res.exitCode == 0) {
        showToast('已成功安装到「应用程序」，正在重新启动...');
        await Process.start('open', ['-n', targetApp]);
        await Future.delayed(const Duration(milliseconds: 400));
        exit(0);
      } else {
        showToast('自动安装未完成，请将安装包内的 BBS-Remote 拖入 Applications 文件夹');
      }
    } catch (e) {
      showToast('安装失败: $e');
    } finally {
      if (mounted) {
        setState(() => _installingToApps = false);
      }
    }
  }

  void _connectOneClick(Peer peer, {bool isFileTransfer = false}) async {
    String pwd = peer.password;
    if (pwd.isEmpty && peer.id == _myId) {
      showToast('这是当前正在使用的本机设备');
      return;
    }
    if (peer.alias.isNotEmpty) {
      try {
        await bind.mainSetPeerAlias(id: peer.id, alias: peer.alias);
      } catch (_) {}
    }
    await connect(
      context,
      peer.id,
      password: pwd.isNotEmpty ? pwd : null,
      isSharedPassword: pwd.isNotEmpty,
      isFileTransfer: isFileTransfer,
    );
  }

  void _showRenameDialog(Peer peer) {
    final ctrl = TextEditingController(
        text: peer.alias.isNotEmpty ? peer.alias : peer.hostname);
    gFFI.dialogManager.show((setDialogState, close, ctx) {
      submit() async {
        final newName = ctrl.text.trim();
        await gFFI.abModel.changeAlias(id: peer.id, alias: newName);
        if (newName.isNotEmpty) {
          await bind.mainSetPeerAlias(id: peer.id, alias: newName);
        }
        showToast('设备备注已更新');
        close();
      }

      return CustomAlertDialog(
        title: const Text('修改设备名称备注'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 340),
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '设备显示名称（如：公司 MacBook / 家里主机）',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => submit(),
          ),
        ),
        actions: [
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('OK', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  void _confirmRemoveDevice(Peer peer) {
    final name = peer.alias.isNotEmpty ? peer.alias : peer.hostname;
    gFFI.dialogManager.show((setDialogState, close, ctx) {
      submit() async {
        await gFFI.abModel.deletePeers([peer.id]);
        showToast('已移除设备');
        close();
      }

      return CustomAlertDialog(
        title: const Text('移除绑定设备'),
        content: Text('确定从当前账号的设备列表中移除「$name」吗？\n（若该设备仍登录此账号，下次在线时会自动重新绑定）'),
        actions: [
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('Remove', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  void _confirmLogout() {
    gFFI.dialogManager.show((setDialogState, close, ctx) {
      submit() async {
        close();
        await gFFI.userModel.logOut();
      }

      return CustomAlertDialog(
        title: const Text('退出账号'),
        content: const Text('确定退出当前登录的专属账号吗？退出后将无法一键免密连接设备。'),
        actions: [
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('OK', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final loggedIn = gFFI.userModel.userName.value.isNotEmpty;
      if (!loggedIn) {
        return _buildFullWindowLogin(context);
      }
      return _buildUuWorkspace(context);
    });
  }

  // ==================== STATE 1: CLEAN FULL-WINDOW LOGIN ====================
  Widget _buildFullWindowLogin(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1420) : const Color(0xFFF3F6FC);
    final cardColor = isDark ? const Color(0xFF182032) : Colors.white;
    final subTextColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      child: Column(
        children: [
          if (_isRunningFromDmgVolume) _buildDmgInstallBanner(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  width: 410,
                  padding: const EdgeInsets.fromLTRB(34, 34, 34, 28),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.35 : 0.07),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/bbs_logo.png',
                          width: 68,
                          height: 68,
                          errorBuilder: (_, __, ___) => Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.bolt_rounded,
                                color: Colors.white, size: 38),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'BBS-Remote',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '登录专属账号 · 自动绑定设备 · 一键免密远控',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: subTextColor),
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _userCtrl,
                        autofocus: _userCtrl.text.isEmpty,
                        onChanged: (_) {
                          if (_loginError.isNotEmpty) {
                            setState(() => _loginError = '');
                          }
                        },
                        onSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: '专属账号',
                          hintText: '请输入管理员开通的账号',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.04)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        autofocus: _userCtrl.text.isNotEmpty,
                        onChanged: (_) {
                          if (_loginError.isNotEmpty) {
                            setState(() => _loginError = '');
                          }
                        },
                        onSubmitted: (_) => _handleLogin(),
                        decoration: InputDecoration(
                          labelText: '登录密码',
                          hintText: '请输入密码',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.04)
                              : const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_loginError.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.redAccent, size: 17),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _loginError,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _loggingIn ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
                                  '立即登录并绑定本机',
                                  style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Obx(() {
                        final ready =
                            stateGlobal.svcStatus.value == SvcStatus.ready;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ready
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              ready
                                  ? '专属高速节点已就绪 · 仅限管理员后台开号'
                                  : '正在连接专属高速节点...',
                              style:
                                  TextStyle(fontSize: 12, color: subTextColor),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATE 2: UU-REMOTE WORKSPACE ====================
  Widget _buildUuWorkspace(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg =
        isDark ? const Color(0xFF131926) : const Color(0xFFF1F5FB);
    final contentBg =
        isDark ? const Color(0xFF0E131F) : const Color(0xFFF8FAFC);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFE2E8F0);

    return Row(
      children: [
        Container(
          width: 236,
          decoration: BoxDecoration(
            color: sidebarBg,
            border: Border(right: BorderSide(color: borderColor, width: 1)),
          ),
          child: _buildSidebar(context, isDark),
        ),
        Expanded(
          child: Container(
            color: contentBg,
            child: Column(
              children: [
                if (_isRunningFromDmgVolume) _buildDmgInstallBanner(),
                if (_navIndex == 0 && _needsMacCorePermissions)
                  _buildPermissionWarningBanner(),
                Expanded(
                  child: _navIndex == 0
                      ? _buildMyDevicesPage(context, isDark)
                      : (_navIndex == 1
                          ? _buildPermissionsPage(context, isDark)
                          : _buildManualAssistPage(context, isDark)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDmgInstallBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF0891B2)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.install_desktop_rounded,
              color: Colors.white, size: 19),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '检测到您正在安装包镜像内直接运行，建议一键安装到系统「应用程序」以获得完整权限与稳定性',
              style: TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed:
                _installingToApps ? null : _installFromDmgToApplications,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1D4ED8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              _installingToApps ? '正在安装...' : '一键安装到应用程序',
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionWarningBanner() {
    final missing = <String>[
      if (!_canScreenRecord) '屏幕录制',
      if (!_canAccessibility) '辅助功能(鼠标键盘控制)',
    ].join('、');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_rounded,
              color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本机尚未开启「$missing」权限，其他设备远控本机时将无法看到画面或操作鼠标',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => setState(() => _navIndex = 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('一键去开启',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isDark) {
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg =
        isDark ? Colors.white.withOpacity(0.05) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/bbs_logo.png',
                    width: 34,
                    height: 34,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.bolt_rounded,
                        color: Color(0xFF2563EB),
                        size: 30),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BBS-Remote',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '400FPS 专线版',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Account Card
          Obx(() {
            final uname = gFFI.userModel.userName.value;
            final dname = gFFI.userModel.displayName.value.trim();
            final title = dname.isNotEmpty ? dname : uname;
            final initial = title.isNotEmpty ? title.characters.first.toUpperCase() : 'U';
            return Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '@$uname · 已登录',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.5, color: subColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),

          // Navigation Items
          Obx(() {
            final count = gFFI.abModel.currentAbPeers.length;
            return _buildNavItem(
              index: 0,
              icon: Icons.devices_rounded,
              label: '我的设备',
              isDark: isDark,
              trailing: count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _navIndex == 0
                            ? Colors.white.withOpacity(0.22)
                            : const Color(0xFF2563EB).withOpacity(0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _navIndex == 0
                              ? Colors.white
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    )
                  : null,
            );
          }),
          const SizedBox(height: 6),
          if (isMacOS) ...[
            _buildNavItem(
              index: 1,
              icon: Icons.verified_user_outlined,
              label: '本机被控权限',
              isDark: isDark,
              trailing: _needsMacCorePermissions
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded,
                      size: 16, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 6),
          ],
          _buildNavItem(
            index: 2,
            icon: Icons.cast_connected_rounded,
            label: '临时协助他人',
            isDark: isDark,
          ),

          const Spacer(),

          // Local Machine Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Obx(() {
                      final ready =
                          stateGlobal.svcStatus.value == SvcStatus.ready;
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ready
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _myHostname.isNotEmpty ? _myHostname : '当前设备',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '本机已绑定 · 同账号免密远控',
                  style: TextStyle(fontSize: 11, color: subColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Actions: Display Settings + Logout
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      DesktopSettingPage.switch2page(SettingsTabKey.display),
                  icon: const Icon(Icons.tune_rounded, size: 15),
                  label: const Text('偏好设置', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: '退出当前账号',
                child: OutlinedButton(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    foregroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Icon(Icons.logout_rounded, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
    required bool isDark,
    Widget? trailing,
  }) {
    final selected = _navIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => setState(() => _navIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10.5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected
                  ? Colors.white
                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF1E293B)),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  // ==================== PAGE 0: MY DEVICES ("我的设备") ====================
  Widget _buildMyDevicesPage(BuildContext context, bool isDark) {
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF171F30) : Colors.white;
    final cardBorder =
        isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFE2E8F0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                '我的设备',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Text(
                '登录同一账号的电脑会自动出现在这里，点击「一键远控」直接连接',
                style: TextStyle(fontSize: 12.5, color: subColor),
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                height: 35,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '搜索设备名称...',
                    hintStyle: TextStyle(fontSize: 12.5, color: subColor),
                    prefixIcon: const Icon(Icons.search_rounded, size: 17),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: cardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  gFFI.userModel.refreshCurrentUser();
                  await _refreshDevicesAndOnlines(quiet: false);
                  showToast('设备列表已刷新');
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('刷新', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Device List
          Expanded(
            child: ChangeNotifierProvider.value(
              value: gFFI.abModel.peersModel,
              child: Consumer<Peers>(
                builder: (context, _, __) {
                  return Obx(() {
                    final loading = gFFI.abModel.currentAbLoading.value;
                    final rawPeers = gFFI.abModel.currentAbPeers.toList();
                    final q = _searchQuery.toLowerCase();
                    final filtered = rawPeers.where((p) {
                      if (q.isEmpty) return true;
                      return p.alias.toLowerCase().contains(q) ||
                          p.hostname.toLowerCase().contains(q) ||
                          p.username.toLowerCase().contains(q) ||
                          p.id.toLowerCase().contains(q);
                    }).toList();

                    // Sort: remote online -> remote offline -> this machine
                    filtered.sort((a, b) {
                      final aSelf = a.id == _myId;
                      final bSelf = b.id == _myId;
                      if (aSelf != bSelf) return aSelf ? 1 : -1;
                      if (a.online != b.online) return a.online ? -1 : 1;
                      final aName =
                          (a.alias.isNotEmpty ? a.alias : a.hostname)
                              .toLowerCase();
                      final bName =
                          (b.alias.isNotEmpty ? b.alias : b.hostname)
                              .toLowerCase();
                      return aName.compareTo(bName);
                    });

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (loading)
                              const CircularProgressIndicator()
                            else
                              Icon(Icons.devices_other_rounded,
                                  size: 52, color: subColor.withOpacity(0.5)),
                            const SizedBox(height: 14),
                            Text(
                              loading
                                  ? '正在同步账号下的设备列表...'
                                  : '当前暂无匹配的设备，在其他电脑安装并登录同一账号即可自动显示',
                              style: TextStyle(fontSize: 13.5, color: subColor),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final peer = filtered[idx];
                        return _buildDeviceCard(
                          context: context,
                          peer: peer,
                          isSelf: peer.id == _myId,
                          isDark: isDark,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          subColor: subColor,
                        );
                      },
                    );
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _platformIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('mac') || p.contains('darwin') || p.contains('ios')) {
      return Icons.laptop_mac_rounded;
    }
    if (p.contains('win')) {
      return Icons.desktop_windows_rounded;
    }
    if (p.contains('android')) {
      return Icons.phone_android_rounded;
    }
    return Icons.computer_rounded;
  }

  String _platformLabel(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('mac') || p.contains('darwin')) return 'macOS';
    if (p.contains('win')) return 'Windows';
    if (p.contains('linux')) return 'Linux';
    if (p.contains('android')) return 'Android';
    if (p.contains('ios')) return 'iOS';
    return platform.isEmpty ? '电脑设备' : platform;
  }

  Widget _buildDeviceCard({
    required BuildContext context,
    required Peer peer,
    required bool isSelf,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required Color subColor,
  }) {
    final displayName = peer.alias.trim().isNotEmpty
        ? peer.alias.trim()
        : (peer.hostname.trim().isNotEmpty ? peer.hostname.trim() : peer.id);
    final isOnline = isSelf || peer.online;
    final osText = _platformLabel(peer.platform);
    final subInfo = [
      osText,
      if (peer.username.isNotEmpty) '用户: ${peer.username}',
      if (isSelf) '当前正在使用的电脑' else (peer.password.isNotEmpty ? '已开启免密直连' : ''),
    ].where((s) => s.isNotEmpty).join('  ·  ');

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onDoubleTap: isSelf ? null : () => _connectOneClick(peer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelf
                ? const Color(0xFF2563EB).withOpacity(0.4)
                : cardBorder,
            width: isSelf ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // OS Icon Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF2563EB).withOpacity(0.12)
                    : Colors.grey.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                _platformIcon(peer.platform),
                size: 27,
                color: isOnline ? const Color(0xFF2563EB) : subColor,
              ),
            ),
            const SizedBox(width: 16),

            // Device Name + Online Pill + Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _showRenameDialog(peer),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Tooltip(
                            message: '修改设备名称备注',
                            child: Icon(Icons.edit_outlined,
                                size: 15, color: subColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelf
                              ? const Color(0xFF2563EB).withOpacity(0.14)
                              : (isOnline
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : Colors.grey.withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSelf ? '本机' : (isOnline ? '● 在线' : '○ 离线'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isSelf
                                ? const Color(0xFF3B82F6)
                                : (isOnline
                                    ? const Color(0xFF10B981)
                                    : subColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subInfo,
                    style: TextStyle(fontSize: 12.5, color: subColor),
                  ),
                ],
              ),
            ),

            // Action Buttons
            if (isSelf) ...[
              OutlinedButton.icon(
                onPressed: () => _showRenameDialog(peer),
                icon: const Icon(Icons.edit_note_rounded, size: 17),
                label: const Text('修改本机名称', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: () => _connectOneClick(peer, isFileTransfer: true),
                icon: const Icon(Icons.folder_open_rounded, size: 17),
                label: const Text('传文件', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _connectOneClick(peer),
                icon: const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  '一键远控',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: '移除该设备',
                child: IconButton(
                  onPressed: () => _confirmRemoveDevice(peer),
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 19, color: subColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==================== PAGE 1: MACOS PERMISSIONS WIZARD ====================
  Widget _buildPermissionsPage(BuildContext context, bool isDark) {
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF171F30) : Colors.white;
    final cardBorder =
        isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本机被控权限检查',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'macOS 系统安全要求开启以下权限后，其他电脑远控本机时才能正常看到画面并控制鼠标键盘（只需开启一次）',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 20),
          _buildPermItem(
            title: '1. 屏幕录制权限（必选）',
            desc: '允许其他设备远程查看这台 Mac 的屏幕画面（开启后若提示重启软件，重新打开即可）',
            granted: _canScreenRecord,
            cardBg: cardBg,
            cardBorder: cardBorder,
            subColor: subColor,
            onConfigure: () {
              bind.mainIsCanScreenRecording(prompt: true);
              launchUrl(Uri.parse(
                  'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'));
            },
          ),
          const SizedBox(height: 12),
          _buildPermItem(
            title: '2. 辅助功能权限（必选）',
            desc: '允许远端控制这台 Mac 的鼠标移动、点击和键盘输入',
            granted: _canAccessibility,
            cardBg: cardBg,
            cardBorder: cardBorder,
            subColor: subColor,
            onConfigure: () {
              bind.mainIsProcessTrusted(prompt: true);
              launchUrl(Uri.parse(
                  'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'));
            },
          ),
          const SizedBox(height: 12),
          _buildPermItem(
            title: '3. 输入监控权限（推荐）',
            desc: '提升远程快捷键与游戏/办公组合键响应能力',
            granted: _canInputMonitor,
            cardBg: cardBg,
            cardBorder: cardBorder,
            subColor: subColor,
            onConfigure: () {
              bind.mainIsCanInputMonitoring(prompt: true);
              launchUrl(Uri.parse(
                  'x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent'));
            },
          ),
          const SizedBox(height: 12),
          _buildPermItem(
            title: '4. 开机自启后台守护服务（可选 · 无人值守推荐）',
            desc: '安装系统守护进程后，即使重启电脑、停留在锁屏界面也能随时一键远控本机',
            granted: _daemonInstalled,
            cardBg: cardBg,
            cardBorder: cardBorder,
            subColor: subColor,
            actionText: '一键安装守护服务',
            onConfigure: () {
              if (_isRunningFromDmgVolume) {
                _installFromDmgToApplications();
              } else {
                bind.mainIsInstalledDaemon(prompt: true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermItem({
    required String title,
    required String desc,
    required bool granted,
    required Color cardBg,
    required Color cardBorder,
    required Color subColor,
    required VoidCallback onConfigure,
    String actionText = '一键去开启',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Icon(
            granted
                ? Icons.check_circle_rounded
                : Icons.warning_amber_rounded,
            size: 28,
            color:
                granted ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(desc, style: TextStyle(fontSize: 12.5, color: subColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          granted
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '已开启',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: onConfigure,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(actionText,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
        ],
      ),
    );
  }

  // ==================== PAGE 2: MANUAL TEMPORARY ASSIST ====================
  Widget _buildManualAssistPage(BuildContext context, bool isDark) {
    final subColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF171F30) : Colors.white;
    final cardBorder =
        isDark ? Colors.white.withOpacity(0.07) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '临时协助他人',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '日常使用直接在「我的设备」点击一键远控即可；如需临时连接未登录同账号的外部设备，可在此输入识别码连接',
            style: TextStyle(fontSize: 13, color: subColor),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('连接其他设备',
                    style:
                        TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _manualIdCtrl,
                        inputFormatters: [IDTextInputFormatter()],
                        decoration: InputDecoration(
                          labelText: '对方设备识别码',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _manualPassCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: '验证码（选填）',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final targetId = _manualIdCtrl.id.trim();
                          if (targetId.isEmpty) {
                            showToast('请输入对方设备识别码');
                            return;
                          }
                          final pwd = _manualPassCtrl.text.trim();
                          connect(
                            context,
                            targetId,
                            password: pwd.isNotEmpty ? pwd : null,
                          );
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('立即远控'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('让未登录同账号的人临时协助本机',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text('默认隐藏识别码与临时密码，保障屏幕隐私安全',
                              style:
                                  TextStyle(fontSize: 12.5, color: subColor)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(
                          () => _showLocalTempCode = !_showLocalTempCode),
                      child: Text(_showLocalTempCode ? '隐藏识别码' : '展开查看本机识别码'),
                    ),
                  ],
                ),
                if (_showLocalTempCode) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      Text('本机识别码: $_myId',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          final pass = gFFI.serverModel.serverPasswd.text;
                          Clipboard.setData(ClipboardData(
                              text: '识别码: $_myId  临时验证码: $pass'));
                          showToast('已复制本机识别码与临时验证码');
                        },
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        label: const Text('一键复制协助信息',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
