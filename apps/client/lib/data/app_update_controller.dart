import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pillxai_api_client/api.dart' as api;

import 'backend_connection.dart';
import 'terminal_controller.dart';

/// Workspace-owned state; leaving Settings never cancels a download or releases an install lock.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController(
    this.backend,
    this.terminal, {
    MethodChannel? channel,
    bool? supported,
  }) : channel = channel ?? const MethodChannel('pillxai/updates'),
       supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final BackendConnection backend;
  final TerminalController terminal;
  final MethodChannel channel;
  final bool supported;
  Map<String, dynamic> device = {};
  api.AndroidRelease? release;
  String message = '正在读取应用版本…';
  String? error;
  bool busy = false;
  bool _disposed = false;
  bool _polling = false;
  Timer? _poll;
  Timer? _checkTimer;
  DateTime? _lastCheck;
  bool get autoDownload => device['auto_download'] == true;
  bool get downloading => device['downloading'] == true;
  bool get installing => device['installing'] == true;
  bool get ready =>
      release != null && device['ready_sha256'] == release!.sha256;
  bool get canInstall => device['can_install'] == true;
  String get version => !supported
      ? '当前平台暂不支持应用内更新'
      : device.isEmpty
      ? '读取中'
      : '${device['version_name']} (${device['version_code']})';
  double? get progress => release == null
      ? null
      : ((device['downloaded_bytes'] as num? ?? 0) / release!.sizeBytes).clamp(
          0,
          1,
        );
  bool get idle =>
      terminal.initialized &&
      !terminal.active &&
      !terminal.busy &&
      terminal.phase == 'idle' &&
      terminal.pending == 0 &&
      terminal.error == null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    if (!supported) {
      message = '应用内更新目前仅支持 Android。';
      _notify();
      return;
    }
    terminal.addListener(_onTerminal);
    await _run(() async {
      await _readDevice();
      await channel.invokeMethod<void>('reconcile');
      await _readDevice();
    });
    if (_disposed) return;
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => refresh());
    _checkTimer = Timer.periodic(const Duration(hours: 6), (_) => check());
    await check();
  }

  Future<void> _readDevice() async {
    final raw = await channel.invokeMapMethod<String, dynamic>('info');
    if (raw == null) throw StateError('无法读取更新状态。');
    device = raw;
    if (device['error'] != null) error = device['error'] as String;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_disposed || busy || !supported) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } catch (failure) {
      error = failure is PlatformException
          ? failure.message
          : failure is api.ApiException
          ? '更新服务暂不可用，请稍后重试。'
          : failure.toString();
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> refresh() async {
    if (_disposed || !supported || busy || _polling) return;
    _polling = true;
    try {
      await _readDevice();
      if (installing &&
          device['confirmation_ready'] != true &&
          ['success', 'failed'].contains(device['install_status'])) {
        await channel.invokeMethod<void>('reconcile');
        await _readDevice();
      }
      if (device['install_status'] == 'failed') {
        message = '安装未完成，原版本和数据保留，可重新安装。';
      } else if (installing) {
        message = '正在更新，已暂停领取新任务。请完成系统确认，或取消安装。';
      } else if (ready) {
        message = idle ? '更新已下载，安装时需要系统确认。' : '更新已下载，等待任务结束、收仓和同步完成。';
      } else if (downloading) {
        message = '正在下载更新…';
      }
      _notify();
    } catch (_) {
      /* Manual check presents errors; polling never claims success. */
    } finally {
      _polling = false;
    }
  }

  Future<api.AndroidUpdateInfo> _fetch() async {
    final base = Uri.parse(backend.client.basePath);
    if (base.scheme != 'https' ||
        base.userInfo.isNotEmpty ||
        base.hasFragment ||
        base.hasQuery) {
      throw StateError('应用更新需要 HTTPS 服务地址。');
    }
    final info = await api.ReleasesApi(backend.client)
        .getAndroidUpdate()
        .timeout(const Duration(seconds: 20));
    if (info == null) throw StateError('更新响应不完整。');
    return info;
  }

  void _validate(api.AndroidRelease value, int apiCompatibility) {
    final abis = (device['abis'] as List? ?? []).cast<String>();
    if (value.packageName != device['package_name'] ||
        value.minAndroidSdk > (device['sdk'] as int) ||
        !value.abis.any(abis.contains)) {
      throw StateError('已发布版本不适用于此平板，请联系维护人员。');
    }
    if (apiCompatibility < value.minApi || apiCompatibility > value.maxApi) {
      throw StateError('新版应用与当前服务器不兼容，请联系维护人员。');
    }
  }

  Future<void> check() async {
    await _run(() async {
      if (installing || downloading) return;
      release = null; // A failed check must not leave a previously withdrawn release installable.
      await _readDevice();
      final info = await _fetch();
      _lastCheck = DateTime.now();
      final value = info.release;
      if (value == null) {
        message = '当前没有已发布的应用更新。';
        return;
      }
      if (value.versionCode <= (device['version_code'] as int)) {
        message = '当前已是最新可用版本。';
        return;
      }
      _validate(value, info.apiCompatibility);
      release = value;
      message = ready ? '更新已下载，空闲时可安装。' : '发现新版本 ${value.versionName}。';
    });
    if (error == null &&
        autoDownload &&
        idle &&
        release != null &&
        !ready &&
        !downloading &&
        !installing) {
      await download();
    }
  }

  Future<void> download() => _run(() async {
    final value = release;
    if (value == null || downloading || installing) return;
    final base = backend.client.basePath.replaceFirst(RegExp(r'/+$'), '');
    await channel.invokeMethod<void>('download', {
      ...value.toJson(),
      'url': '$base/releases/android/packages/${value.sha256}',
    });
    await _readDevice();
    message = '正在下载更新…';
  });

  Future<void> setAutoDownload(bool value) async {
    await _run(() async {
      await channel.invokeMethod<void>('autoDownload', value);
      await _readDevice();
    });
    if (value && error == null) await check();
  }

  Future<void> permission() =>
      _run(() => channel.invokeMethod<void>('permission'));

  Future<void> install() => _run(() async {
    if (!idle || !ready) throw StateError('请先完成任务、取盒收仓和结果同步。');
    // Recheck the deployment's compatibility and withdrawal immediately before installing.
    final info = await _fetch();
    final current = info.release;
    if (current == null ||
        current.sha256 != release?.sha256 ||
        current.versionCode != release?.versionCode) {
      release = null;
      throw StateError('发布信息已变化，请重新检查更新。');
    }
    _validate(current, info.apiCompatibility);
    await channel.invokeMethod<void>('install');
    await _readDevice();
    message = '安装准备完成，请继续系统确认。';
  });

  Future<void> confirm() => _run(() => channel.invokeMethod<void>('confirm'));
  Future<void> cancelInstall() => _run(() async {
    await channel.invokeMethod<void>('cancelInstall');
    await _readDevice();
    message = '已取消更新安装，可重新连接设备。';
  });

  void _onTerminal() {
    _notify();
    // Re-evaluate only once on an idle transition; errors require an explicit retry.
    if (!busy &&
        idle &&
        error == null &&
        autoDownload &&
        release != null &&
        !ready &&
        !downloading &&
        !installing) {
      unawaited(download());
    }
  }

  Future<void> resumed() async {
    await refresh();
    if (_lastCheck == null ||
        DateTime.now().difference(_lastCheck!) > const Duration(hours: 6)) {
      await check();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    _checkTimer?.cancel();
    terminal.removeListener(_onTerminal);
    super.dispose();
  }
}
