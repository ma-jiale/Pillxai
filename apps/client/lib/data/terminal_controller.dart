import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../models/prescription_store.dart' show newRecordId, SaveFailure;
import 'backend_connection.dart';
import 'terminal_host.dart';

/// Owns the terminal host and network synchronization for the whole login session.
class TerminalController extends ChangeNotifier {
  TerminalController(this.backend, this.host);
  final BackendConnection backend;
  final TerminalHost host;
  late final api.ExecutionApi execution = api.ExecutionApi(backend.client);
  Map<String, dynamic> view = {};
  List<api.DeviceView> devices = [];
  List<String> ports = [];
  Map<String, String> portNames = {};
  List<Map<String, dynamic>> nearbyDevices = [];
  String? deviceSetupStatus;
  api.TaskView? task;
  String? error;
  String? syncError;
  bool busy = false;
  bool initialized = false;
  bool _disposed = false;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _timer;
  Future<void>? _syncing;

  bool get supported => host.supported;
  bool get isAndroid => view['platform'] == 'android';
  Map<String, dynamic> get state =>
      Map<String, dynamic>.from(view['state'] as Map? ?? {});
  String get phase => state['phase'] as String? ?? 'idle';
  bool get active => task != null || view['claim_intent'] != null;
  bool get connected => state['connected'] == true;
  bool get recognized => view['recognized'] == true;
  int get count => state['count'] as int? ?? 0;
  int get pending => view['pending_count'] as int? ?? 0;
  String get terminalId => view['terminal_id'] as String? ?? '';
  String? get observedUid {
    return connected ? view['observed_uid'] as String? : null;
  }

  api.BatchPlan? get batch =>
      task == null ? null : task!.batches[state['batch'] as int];
  Map<String, dynamic> get connection =>
      Map<String, dynamic>.from(view['configuration'] as Map? ?? {});
  api.DeviceView? get device {
    for (final item in devices) {
      if (item.id == connection['device_id']) return item;
    }
    return task?.device;
  }

  bool get ownTask => task == null || task!.ownerId == backend.account?.id;
  bool get canMaintain =>
      backend.account?.role == api.Role.admin ||
      backend.account?.canMaintain == true;

  void _accept(Map<String, dynamic> value) {
    if (_disposed) return;
    if (value['worker_error'] != null) {
      error = value['worker_error'] as String;
    } else {
      view = value;
      task = api.TaskView.fromJson(value['task']);
      if (isAndroid) syncError = value['sync_error'] as String?;
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_subscription != null) {
      await run(() async {
        await _setBackgroundSession();
        await refreshDevices();
      });
      await synchronize();
      return;
    }
    if (!supported) {
      initialized = true;
      notifyListeners();
      return;
    }
    _subscription = host.updates.listen(_accept);
    await run(() async {
      await host.initialize();
      _accept(Map<String, dynamic>.from(await host.command('view') as Map));
      await _setBackgroundSession();
      await refreshDevices();
      initialized = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => synchronize());
    await synchronize();
  }

  Future<void> _setBackgroundSession() async {
    if (!isAndroid || backend.account == null) return;
    await host.command('session', {
      'api_url': backend.client.basePath,
      'authorization': backend.client.defaultHeaderMap['Authorization'] ?? '',
      'owner_id': backend.account!.id,
    });
  }

  Future<void> refreshAfterResume() async {
    if (!supported || !initialized) return;
    await run(() async {
      _accept(Map<String, dynamic>.from(await host.command('view') as Map));
    });
    await synchronize();
  }

  Future<void> requestBluetoothAccess() => run(() async {
    await host.command('request_access');
    await refreshDevices();
  });

  Future<void> discoverDevices() => run(() async {
    if (active || !canMaintain) return;
    deviceSetupStatus = '正在搜索摆药机…';
    nearbyDevices = [];
    final found = await host.command('discover_devices') as List;
    nearbyDevices = found
        .map((value) => Map<String, dynamic>.from(value as Map))
        .where(
          (value) => !devices.any(
            (d) => d.configuration.identity.toUpperCase() == value['address'],
          ),
        )
        .toList();
  });

  Future<void> addBluetoothDevice(String address, String name) => run(() async {
    if (active || !canMaintain) return;
    deviceSetupStatus = '正在添加 $name… 如有系统提示，请确认配对（默认码 1234）。';
    notifyListeners();
    await host.command('pair_device', {'address': address});
    if (active) throw const SaveFailure('请先完成当前摆药，再添加设备。');
    final existing = devices
        .where(
          (d) =>
              d.configuration.identity.toUpperCase() == address.toUpperCase(),
        )
        .firstOrNull;
    await saveDevice(
      existing?.configuration.copyWith(terminalId: terminalId) ??
          api.DeviceConfiguration(
            name: name,
            identity: address,
            terminalId: terminalId,
            mode: api.DeviceMode.hardware,
            rows: [2, 1, 0, 3],
            reverseColumns: false,
            positionsVerified: false,
            trayPresentLine: '',
            trayAbsentLine: '',
            readyLine: '',
            feedbackVerified: false,
            barcodeRemovalCloses: false,
          ),
      port: address,
      existing: existing,
    );
    await host.command('connect');
    _accept(Map<String, dynamic>.from(await host.command('view') as Map));
  });

  Future<void> run(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (failure) {
      error = failure.toString();
    } finally {
      busy = false;
      deviceSetupStatus = null;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> refreshDevices() async {
    devices = await backend.request(execution.listDevices()) ?? [];
    if (supported) {
      final candidates = await host.command('ports') as List;
      portNames = {};
      ports = candidates.map((value) {
        if (value is Map) {
          final address = value['address'] as String;
          portNames[address] = value['name'] as String;
          return address;
        }
        return value as String;
      }).toList();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> saveDevice(
    api.DeviceConfiguration configuration, {
    required String port,
    String simulatorUid = 'A1B2C3D4',
    api.DeviceView? existing,
  }) async {
    final result = await backend.request(
      execution.saveDevice(
        existing?.id ?? newRecordId(),
        api.SaveDevice(
          expectedRevision: existing?.revision ?? 0,
          configuration: configuration,
        ),
      ),
    );
    if (result == null) throw const SaveFailure('设备保存未确认。');
    await host.command('configure', {
      'device_id': result.id,
      'port': port,
      'mode': configuration.mode.toJson(),
      'uid': simulatorUid,
    });
    await refreshDevices();
  }

  Future<void> savePositionMapping(
    api.DeviceView original, {
    required List<int> rows,
    required bool reverseColumns,
    required bool verified,
  }) async {
    if (!canMaintain || active || device?.id != original.id) {
      throw const SaveFailure('当前设备或任务状态已变化，请关闭后重新核对。');
    }
    if (rows.length != 4 ||
        rows.toSet().length != 4 ||
        rows.any((row) => row < 0 || row > 3)) {
      throw const SaveFailure('四个时段须分别对应不同的机器行。');
    }
    final result = await backend.request(
      execution.saveDevice(
        original.id,
        api.SaveDevice(
          expectedRevision: original.revision,
          configuration: original.configuration.copyWith(
            rows: List<int>.of(rows),
            reverseColumns: reverseColumns,
            positionsVerified: verified,
          ),
        ),
      ),
    );
    if (result == null) throw const SaveFailure('映射保存未确认，请重新加载核对。');
    devices = [
      for (final item in devices)
        if (item.id == result.id) result else item,
    ];
    if (!_disposed) notifyListeners();
  }

  Future<void> action(
    String operation, [
    Map<String, dynamic> data = const {},
  ]) => run(() async {
    if (!ownTask) throw const SaveFailure('请使用领取任务的原账号处理本机任务。');
    await host.command(operation, data);
    if (operation == 'connect' && view['claim_intent'] != null) {
      await recoverClaim();
    }
    await synchronize();
  });

  Map<String, dynamic> jsonMap(Object value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  Future<void> claim(api.PlanSnapshot plan) => run(() async {
    if (!connected || device == null || active) {
      throw const SaveFailure('请先连接本机设备并结束原任务。');
    }
    final id = newRecordId();
    final data = api.ClaimTask(
      planId: plan.id,
      deviceId: device!.id,
      terminalId: terminalId,
    );
    await host.command('claim_intent', {'id': id, ...data.toJson()});
    final result = await backend.request(execution.claimTask(id, data));
    if (result == null) throw const SaveFailure('领取结果未确认，请恢复领取结果。');
    await host.command('attach', jsonMap(result));
  });

  Future<void> recoverClaim() async {
    final intent = Map<String, dynamic>.from(
      view['claim_intent'] as Map? ?? {},
    );
    if (intent.isEmpty) return;
    final request = api.ClaimTask.fromJson(intent)!;
    // Same ID and payload: retries the business claim only, never a physical command.
    final result = await backend.request(
      execution.claimTask(intent['id'] as String, request),
    );
    if (result == null) throw const SaveFailure('领取结果仍未确认。');
    await host.command('attach', jsonMap(result));
  }

  Future<void> forgetRejectedClaim() => run(() async {
    final intent = Map<String, dynamic>.from(
      view['claim_intent'] as Map? ?? {},
    );
    if (intent.isEmpty) return;
    try {
      final existing = await execution.getTask(intent['id'] as String);
      if (existing != null) throw const SaveFailure('中央已领取，须连接原设备恢复处理。');
    } on api.ApiException catch (failure) {
      if (failure.code != 404) rethrow;
    }
    await host.command('claim_intent');
  });

  Future<void> start() => run(() async {
    if (!ownTask || task == null || !recognized) {
      throw const SaveFailure('请重新识别当前长者的药盒。');
    }
    if (state['permitted'] == true) {
      await host.command('continue_tray');
      return;
    }
    await synchronize();
    final latest = await backend.request(execution.getTask(task!.id));
    if (latest == null) throw const SaveFailure('任务读取失败。');
    if (!recognized) throw const SaveFailure('药盒识别已变化，请重新核对。');
    final source = view['recognition_source'] as String? ?? 'rfid';
    final value =
        view['recognition_value'] as String? ?? state['uid'] as String;
    final observed = DateTime.parse(
      view['recognition_at'] as String? ?? state['uid_at'] as String,
    );
    final allowed = await backend.request(
      execution.startTask(
        latest.id,
        api.StartTask(
          terminalId: terminalId,
          expectedRevision: latest.revision,
          uid: source == 'rfid' ? value : null,
          barcode: source == 'barcode' ? value : null,
          observedAt: observed,
          checkedAt: DateTime.now().toUtc(),
        ),
      ),
    );
    if (allowed == null) throw const SaveFailure('启动许可未确认，请重新核对，未发送矩阵。');
    await host.command('begin', jsonMap(allowed));
  });

  Future<void> synchronize() {
    if (_disposed || !supported || task == null || !ownTask) {
      return Future.value();
    }
    return _syncing ??= _upload().whenComplete(() => _syncing = null);
  }

  Future<void> _upload() async {
    try {
      if (isAndroid) {
        syncError = await host.command('sync') as String?;
        return;
      }
      final current = task!;
      if (phase == 'deleting') {
        final receipt = await backend.request(
          execution.discardTask(
            current.id,
            api.DiscardTask(terminalId: terminalId, physicalSceneSafe: true),
          ),
        );
        if (receipt?.deleted != true || receipt?.taskId != current.id) {
          throw const SaveFailure('中央删除结果未确认，本机保留删除意图。');
        }
        await host.command('discarded');
      } else {
        final raw = await host.command('pending') as List;
        if (raw.isNotEmpty) {
          final result = await backend.request(
            execution.syncEvents(
              current.id,
              api.SyncEvents(
                terminalId: terminalId,
                events: raw
                    .map((row) => api.ExecutionEvent.fromJson(row)!)
                    .toList(),
              ),
            ),
          );
          if (result == null) throw const SaveFailure('同步结果未确认。');
          await host.command('acknowledge', {
            'sequence': result.sequence,
            'task_state': result.state.toJson(),
            'learning_results': result.learningResults
                .map((r) => r.toJson())
                .toList(),
          });
        }
      }
      syncError = null;
    } catch (failure) {
      syncError = failure.toString();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> shutdown() async {
    if (active) throw const SaveFailure('请先结束本机任务并完成同步。');
    _timer?.cancel();
    await _subscription?.cancel();
    await host.close();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
