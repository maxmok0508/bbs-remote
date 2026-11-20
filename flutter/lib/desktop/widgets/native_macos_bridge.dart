import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/models/ab_model.dart';
import 'package:flutter_hbb/models/key_mapping_model.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:flutter_hbb/models/user_model.dart';

class BbsNativeMacOSBridge {
  static final BbsNativeMacOSBridge instance = BbsNativeMacOSBridge._();
  static const MethodChannel _channel =
      MethodChannel('com.bbs.remote/native_ui');

  BbsNativeMacOSBridge._();

  bool _attached = false;
  BuildContext? _hostContext;
  Timer? _syncTimer;
  int _tick = 0;

  void attach(BuildContext context) {
    _hostContext = context;
    if (!isMacOS || _attached) return;
    _attached = true;

    BbsKeyMappingCenter.instance.ensureInitialized();
    BbsKeyMappingCenter.instance.addListener(_pushKeyCatalogAndState);

    _channel.setMethodCallHandler(_handleNativeCall);
    _bootstrapAndPush();
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      _tick++;
      await _updateConnStatus();
      if (gFFI.userModel.isLogin && _tick % 5 == 0) {
        await _refreshDevicesAndOnlines(quiet: true);
      }
      await pushCoreState();
    });
  }

  void updateContext(BuildContext context) {
    _hostContext = context;
  }

  Future<void> _bootstrapAndPush() async {
    await _updateConnStatus();
    if (gFFI.userModel.isLogin) {
      gFFI.userModel.refreshCurrentUser();
      await _refreshDevicesAndOnlines(quiet: true);
    } else {
      final token = bind.mainGetLocalOption(key: 'access_token');
      if (token.isNotEmpty) {
        gFFI.userModel.refreshCurrentUser();
      }
    }
    await pushCoreState();
    await pushKeyCatalog();
  }

  void _pushKeyCatalogAndState() {
    pushCoreState();
    pushKeyCatalog();
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

  Map<String, dynamic> _collectSettingsMap() {
    final q = bind.mainGetUserDefaultOption(key: kOptionImageQuality);
    final fpsRaw =
        double.tryParse(bind.mainGetUserDefaultOption(key: 'custom-fps')) ??
            120.0;
    final qualRaw = double.tryParse(
            bind.mainGetUserDefaultOption(key: 'custom_image_quality')) ??
        100.0;
    final codec = bind.mainGetUserDefaultOption(key: kOptionCodecPreference);
    final vs = bind.mainGetUserDefaultOption(key: kOptionViewStyle);

    return {
      'imageQuality': q.isNotEmpty ? q : kRemoteImageQualityBest,
      'customFps': fpsRaw.clamp(30.0, 400.0),
      'customQuality': qualRaw.clamp(10.0, 500.0),
      'codecPref': codec.isNotEmpty ? codec : 'auto',
      'viewStyle': vs.isNotEmpty ? vs : kRemoteViewStyleAdaptive,
      'hwCodec': bind.mainGetOptionSync(key: kOptionEnableHwcodec) != 'N',
      'showQualityMonitor':
          bind.mainGetUserDefaultOption(key: kOptionShowQualityMonitor) == 'Y',
      'enableSound':
          bind.mainGetUserDefaultOption(key: kOptionDisableAudio) != 'Y',
      'enableClipboard':
          bind.mainGetUserDefaultOption(key: kOptionDisableClipboard) != 'Y',
      'enableFileCopy':
          bind.mainGetUserDefaultOption(key: kOptionEnableFileCopyPaste) != 'N',
      'enableTrueColor':
          bind.mainGetUserDefaultOption(key: kOptionI444) == 'Y',
      'directLan': bind.mainGetLocalOption(key: kOptionEnableUdpPunch) != 'N',
      'themeMode': MyTheme.getThemeModePreference().toShortString(),
    };
  }

  Future<void> pushCoreState() async {
    if (!isMacOS) return;
    try {
      final myId = await bind.mainGetMyId();
      String host = Platform.localHostname;
      try {
        final info = jsonDecode(bind.mainGetLoginDeviceInfo());
        if (info is Map && (info['name']?.toString().isNotEmpty ?? false)) {
          host = info['name'].toString();
        }
      } catch (_) {}

      final tempPass = await bind.mainGetTemporaryPassword();
      final savedName =
          UserModel.getLocalUserInfo()?['name']?.toString() ?? '';
      final uname = gFFI.userModel.userName.value;
      final dname = gFFI.userModel.displayName.value.trim();

      final peers = gFFI.abModel.currentAbPeers.map((Peer p) {
        final isSelf = p.id == myId;
        return {
          'id': p.id,
          'formattedId': formatID(p.id),
          'hostname': p.hostname,
          'alias': p.alias,
          'displayName': p.alias.isNotEmpty
              ? p.alias
              : (p.hostname.isNotEmpty ? p.hostname : p.id),
          'platform': p.platform,
          'username': p.username,
          'online': isSelf ? true : p.online,
          'isSelf': isSelf,
          'hasPassword': p.password.isNotEmpty,
        };
      }).toList(growable: false);

      final km = BbsKeyMappingCenter.instance;
      final payload = {
        'isLogin': uname.isNotEmpty,
        'userName': uname,
        'displayName': dname.isNotEmpty ? dname : uname,
        'savedUsername': savedName,
        'myId': myId,
        'formattedMyId': formatID(myId),
        'myHostname': host,
        'tempPass': tempPass,
        'svcReady': stateGlobal.svcStatus.value == SvcStatus.ready,
        'videoConnCount': stateGlobal.videoConnCount.value,
        'isDmgVolume': Platform.resolvedExecutable.startsWith('/Volumes/'),
        'permDismissed':
            bind.mainGetLocalOption(key: 'bbs_hide_perm_tip') == 'Y',
        'canScreenRecord': bind.mainIsCanScreenRecording(prompt: false),
        'canAccessibility': bind.mainIsProcessTrusted(prompt: false),
        'canInputMonitor': bind.mainIsCanInputMonitoring(prompt: false),
        'daemonInstalled': bind.mainIsInstalledDaemon(prompt: false),
        'devices': peers,
        'settings': _collectSettingsMap(),
        'keyMapMeta': {
          'masterEnabled': km.masterEnabled,
          'activePreset': km.activePreset,
          'totalCount': km.totalCount,
          'enabledCount': km.enabledCount,
        },
      };
      await _channel.invokeMethod('syncState', jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> pushKeyCatalog() async {
    if (!isMacOS) return;
    try {
      final km = BbsKeyMappingCenter.instance;
      km.ensureInitialized();
      final payload = {
        'masterEnabled': km.masterEnabled,
        'activePreset': km.activePreset,
        'totalCount': km.totalCount,
        'enabledCount': km.enabledCount,
        'presets': kBbsKeyPresets
            .map((p) => {
                  'id': p.id,
                  'name': p.name,
                  'subtitle': p.subtitle,
                })
            .toList(growable: false),
        'keyOptions': kBbsAllKeys
            .map((k) => {
                  'code': k.code,
                  'label': k.label,
                })
            .toList(growable: false),
        'rules': km.allEntries
            .map((e) => e.toUiSummaryJson(km.isRuleEnabled(e.id)))
            .toList(growable: false),
      };
      await _channel.invokeMethod('syncKeyCatalog', jsonEncode(payload));
    } catch (_) {}
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    final Map<String, dynamic> args = call.arguments is String
        ? Map<String, dynamic>.from(jsonDecode(call.arguments as String) as Map)
        : (call.arguments is Map
            ? Map<String, dynamic>.from(call.arguments as Map)
            : <String, dynamic>{});

    switch (call.method) {
      case 'requestInitialSync':
        await pushCoreState();
        await pushKeyCatalog();
        return {'ok': true};

      case 'login':
        final username = (args['username'] ?? '').toString().trim();
        final password = (args['password'] ?? '').toString();
        if (username.isEmpty || password.isEmpty) {
          return {'ok': false, 'error': '请输入管理员分配的专属账号与密码'};
        }
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
            gFFI.userModel.refreshCurrentUser();
            await UserModel.updateOtherModels();
            await _refreshDevicesAndOnlines(quiet: false);
            await pushCoreState();
            return {'ok': true};
          }
          return {'ok': false, 'error': '登录响应异常，请重试'};
        } on RequestException catch (err) {
          return {
            'ok': false,
            'error': err.cause.isNotEmpty ? err.cause : '账号或密码错误'
          };
        } catch (err) {
          return {'ok': false, 'error': '无法连接认证服务器 ($err)'};
        }

      case 'logout':
        await gFFI.userModel.logOut();
        await pushCoreState();
        return {'ok': true};

      case 'refreshDevices':
        await _refreshDevicesAndOnlines(quiet: false);
        await pushCoreState();
        return {'ok': true};

      case 'connectPeer':
        final id = (args['id'] ?? '').toString().replaceAll(' ', '');
        final isFileTransfer = args['isFileTransfer'] == true;
        if (id.isEmpty || _hostContext == null) {
          return {'ok': false, 'error': '无效设备 ID'};
        }
        final myId = await bind.mainGetMyId();
        Peer? matched;
        for (final p in gFFI.abModel.currentAbPeers) {
          if (p.id == id) {
            matched = p;
            break;
          }
        }
        String pwd = matched?.password ?? (args['password'] ?? '').toString();
        if (pwd.isEmpty && id == myId) {
          return {'ok': false, 'error': '这是当前正在使用的本机设备'};
        }
        if (matched != null && matched.alias.isNotEmpty) {
          try {
            await bind.mainSetPeerAlias(id: matched.id, alias: matched.alias);
          } catch (_) {}
        }
        await connect(
          _hostContext!,
          id,
          password: pwd.isNotEmpty ? pwd : null,
          isSharedPassword: pwd.isNotEmpty,
          isFileTransfer: isFileTransfer,
        );
        return {'ok': true};

      case 'manualConnect':
        final id = (args['id'] ?? '').toString().replaceAll(' ', '');
        final pwd = (args['password'] ?? '').toString();
        final isFileTransfer = args['isFileTransfer'] == true;
        if (id.isEmpty || _hostContext == null) {
          return {'ok': false, 'error': '请输入对方 9 位伙伴识别码'};
        }
        await connect(
          _hostContext!,
          id,
          password: pwd.isNotEmpty ? pwd : null,
          isFileTransfer: isFileTransfer,
        );
        return {'ok': true};

      case 'renamePeer':
        final id = (args['id'] ?? '').toString();
        final alias = (args['alias'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          await gFFI.abModel.changeAlias(id: id, alias: alias);
          if (alias.isNotEmpty) {
            await bind.mainSetPeerAlias(id: id, alias: alias);
          }
          await pushCoreState();
        }
        return {'ok': true};

      case 'deletePeer':
        final id = (args['id'] ?? '').toString();
        if (id.isNotEmpty) {
          await gFFI.abModel.deletePeers([id]);
          await pushCoreState();
        }
        return {'ok': true};

      case 'dismissPermBanner':
        await bind.mainSetLocalOption(key: 'bbs_hide_perm_tip', value: 'Y');
        await pushCoreState();
        return {'ok': true};

      case 'openPerm':
        final kind = (args['kind'] ?? '').toString();
        if (kind == 'screen') {
          bind.mainIsCanScreenRecording(prompt: true);
          await Process.run('open', [
            'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'
          ]);
        } else if (kind == 'accessibility') {
          bind.mainIsProcessTrusted(prompt: true);
          await Process.run('open', [
            'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility'
          ]);
        } else if (kind == 'input') {
          bind.mainIsCanInputMonitoring(prompt: true);
          await Process.run('open', [
            'x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent'
          ]);
        } else if (kind == 'daemon') {
          bind.mainIsInstalledDaemon(prompt: true);
        }
        await pushCoreState();
        return {'ok': true};

      case 'repairPerms':
        await Process.run('/bin/sh', [
          '-c',
          'tccutil reset ScreenCapture com.bbs.remote 2>/dev/null || true; '
              'tccutil reset Accessibility com.bbs.remote 2>/dev/null || true; '
              'tccutil reset ListenEvent com.bbs.remote 2>/dev/null || true'
        ]);
        await bind.mainSetLocalOption(key: 'bbs_hide_perm_tip', value: '');
        bind.mainIsCanScreenRecording(prompt: true);
        bind.mainIsProcessTrusted(prompt: true);
        await pushCoreState();
        return {'ok': true};

      case 'installToApps':
        final exeFile = File(Platform.resolvedExecutable);
        final appBundleDir = exeFile.parent.parent.parent.path;
        const targetApp = '/Applications/BBS-Remote.app';
        final script =
            'rm -rf "$targetApp" && cp -R "$appBundleDir" "$targetApp" && xattr -cr "$targetApp"';
        var res = await Process.run('/bin/sh', ['-c', script]);
        if (res.exitCode != 0) {
          final osa =
              'do shell script "rm -rf /Applications/BBS-Remote.app && cp -R \\"$appBundleDir\\" /Applications/BBS-Remote.app && xattr -cr /Applications/BBS-Remote.app" with administrator privileges';
          res = await Process.run('osascript', ['-e', osa]);
        }
        if (res.exitCode == 0) {
          await Process.start('open', ['-n', targetApp]);
          await Future.delayed(const Duration(milliseconds: 400));
          exit(0);
        }
        return {'ok': false, 'error': '自动安装未完成，请拖入 Applications 文件夹'};

      case 'relaunchApp':
        final exe = File(Platform.resolvedExecutable);
        final appPath = exe.parent.parent.parent.path;
        if (appPath.endsWith('.app')) {
          await Process.start('open', ['-n', appPath]);
          await Future.delayed(const Duration(milliseconds: 350));
          exit(0);
        }
        return {'ok': false};

      case 'setQualityPreset':
        final mode = (args['mode'] ?? kRemoteImageQualityBest).toString();
        final fps = (args['fps'] as num?)?.toDouble();
        await bind.mainSetUserDefaultOption(
            key: kOptionImageQuality, value: mode);
        if (fps != null) {
          await bind.mainSetUserDefaultOption(
              key: 'custom-fps', value: fps.round().toString());
        }
        await pushCoreState();
        return {'ok': true};

      case 'updateSetting':
        final key = (args['key'] ?? '').toString();
        final val = args['value'];
        switch (key) {
          case 'customFps':
            final fps = ((val as num?)?.toDouble() ?? 120.0).round();
            await bind.mainSetUserDefaultOption(
                key: kOptionImageQuality, value: kRemoteImageQualityCustom);
            await bind.mainSetUserDefaultOption(
                key: 'custom-fps', value: fps.toString());
            break;
          case 'customQuality':
            final q = ((val as num?)?.toDouble() ?? 100.0).round();
            await bind.mainSetUserDefaultOption(
                key: kOptionImageQuality, value: kRemoteImageQualityCustom);
            await bind.mainSetUserDefaultOption(
                key: 'custom_image_quality', value: q.toString());
            break;
          case 'codecPref':
            await bind.mainSetUserDefaultOption(
                key: kOptionCodecPreference, value: val.toString());
            break;
          case 'viewStyle':
            await bind.mainSetUserDefaultOption(
                key: kOptionViewStyle, value: val.toString());
            break;
          case 'hwCodec':
            await bind.mainSetOption(
                key: kOptionEnableHwcodec, value: val == true ? 'Y' : 'N');
            break;
          case 'showQualityMonitor':
            await bind.mainSetUserDefaultOption(
                key: kOptionShowQualityMonitor, value: val == true ? 'Y' : 'N');
            break;
          case 'enableSound':
            await bind.mainSetUserDefaultOption(
                key: kOptionDisableAudio, value: val == true ? 'N' : 'Y');
            break;
          case 'enableClipboard':
            await bind.mainSetUserDefaultOption(
                key: kOptionDisableClipboard, value: val == true ? 'N' : 'Y');
            break;
          case 'enableFileCopy':
            await bind.mainSetUserDefaultOption(
                key: kOptionEnableFileCopyPaste,
                value: val == true ? 'Y' : 'N');
            break;
          case 'enableTrueColor':
            await bind.mainSetUserDefaultOption(
                key: kOptionI444, value: val == true ? 'Y' : 'N');
            break;
          case 'directLan':
            final flag = val == true ? 'Y' : 'N';
            await bind.mainSetLocalOption(
                key: kOptionEnableUdpPunch, value: flag);
            await bind.mainSetLocalOption(
                key: kOptionEnableIpv6Punch, value: flag);
            break;
          case 'themeMode':
            final m = val.toString();
            ThemeMode tm = ThemeMode.system;
            if (m == 'light') tm = ThemeMode.light;
            if (m == 'dark') tm = ThemeMode.dark;
            await MyTheme.changeDarkMode(tm);
            break;
        }
        await pushCoreState();
        return {'ok': true};

      case 'setKeyMasterEnabled':
        await BbsKeyMappingCenter.instance
            .setMasterEnabled(args['enabled'] == true);
        return {'ok': true};

      case 'applyKeyPreset':
        final presetId = (args['presetId'] ?? 'smart_office').toString();
        await BbsKeyMappingCenter.instance.applyPreset(presetId);
        return {'ok': true};

      case 'toggleKeyRule':
        final id = (args['id'] ?? '').toString();
        final enabled = args['enabled'] == true;
        await BbsKeyMappingCenter.instance.toggleRule(id, enabled);
        return {'ok': true};

      case 'addCustomKeyRule':
        await BbsKeyMappingCenter.instance.addCustomRule(
          name: (args['name'] ?? '').toString(),
          peer: (args['peer'] ?? 'all').toString(),
          srcKey: (args['srcKey'] ?? 'c').toString(),
          srcCtrl: args['srcCtrl'] == true,
          srcAlt: args['srcAlt'] == true,
          srcShift: args['srcShift'] == true,
          srcMeta: args['srcMeta'] == true,
          dstKey: (args['dstKey'] ?? 'c').toString(),
          dstCtrl: args['dstCtrl'] == true,
          dstAlt: args['dstAlt'] == true,
          dstShift: args['dstShift'] == true,
          dstMeta: args['dstMeta'] == true,
        );
        return {'ok': true};

      case 'deleteCustomKeyRule':
        final id = (args['id'] ?? '').toString();
        await BbsKeyMappingCenter.instance.deleteCustomRule(id);
        return {'ok': true};

      case 'refreshTempPass':
        await bind.mainUpdateTemporaryPassword();
        await pushCoreState();
        return {'ok': true};
    }
    return {'ok': false};
  }
}
