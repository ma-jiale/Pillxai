import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';

const _runtime = MethodChannel('pillxai/runtime');
const _bluetooth = MethodChannel('pillxai/bluetooth');

class AndroidBluetoothTransport implements DeviceTransport {
  AndroidBluetoothTransport(this.address);
  final String address;
  @override
  Future<void> open() =>
      _bluetooth.invokeMethod<void>('open', {'address': address});
  @override
  Future<Uint8List> read() async =>
      await _bluetooth.invokeMethod<Uint8List>('read') ?? Uint8List(0);
  @override
  Future<void> write(Uint8List bytes) =>
      _bluetooth.invokeMethod<void>('write', bytes);
  @override
  Future<void> close() => _bluetooth.invokeMethod<void>('close');
}

/// Runs in a service-owned FlutterEngine, never in the Activity's engine.
Future<void> runTerminalService() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await _runtime.invokeMethod<String>('directory');
    if (directory == null) throw StateError('缺少本机存储目录。');
    Directory(directory).createSync(recursive: true);
    final lock = File('$directory/owner.lock').openSync(mode: FileMode.append);
    lock.lockSync(FileLock.exclusive);
    final journal = ExecutionJournal('$directory/execution.sqlite');
    late final TerminalSession session;
    api.ApiClient? client;
    String? owner;
    String? syncError;
    Future<void>? syncing;
    bool closed = false;
    var authGeneration = 0;
    void publish(Map<String, dynamic> view) {
      unawaited(
        _runtime.invokeMethod<void>(
          'update',
          jsonEncode({...view, 'sync_error': syncError}),
        ),
      );
    }

    session = TerminalSession(
      journal: journal,
      platform: 'android',
      hardwareTransport: (config) =>
          AndroidBluetoothTransport(config['port'] as String),
      ports: () async =>
          await _bluetooth.invokeListMethod<Object?>('ports') ?? [],
      publish: publish,
    );
    Future<void> upload() async {
      final currentClient = client;
      final generation = authGeneration;
      final task = session.engine.task;
      if (currentClient == null ||
          task == null ||
          task.ownerId != owner ||
          closed) {
        return;
      }
      try {
        final execution = api.ExecutionApi(currentClient);
        if (session.engine.state.phase == ExecutionPhase.deleting) {
          final receipt = await execution
              .discardTask(
                task.id,
                api.DiscardTask(
                  terminalId: journal.terminalId,
                  physicalSceneSafe: true,
                ),
              )
              .timeout(const Duration(seconds: 15));
          if (receipt?.deleted != true || receipt?.taskId != task.id) {
            throw StateError('中央删除结果未确认。');
          }
          if (!closed &&
              generation == authGeneration &&
              session.engine.task?.id == task.id) {
            await session.command('discarded');
          }
        } else {
          final raw = await session.command('pending') as List;
          if (raw.isNotEmpty) {
            final receipt = await execution
                .syncEvents(
                  task.id,
                  api.SyncEvents(
                    terminalId: journal.terminalId,
                    events: raw
                        .map((v) => api.ExecutionEvent.fromJson(v)!)
                        .toList(),
                  ),
                )
                .timeout(const Duration(seconds: 15));
            if (receipt == null) throw StateError('同步结果未确认。');
            if (!closed &&
                generation == authGeneration &&
                session.engine.task?.id == task.id &&
                session.engine.state.phase != ExecutionPhase.deleting) {
              await session.command('acknowledge', {
                'sequence': receipt.sequence,
                'task_state': receipt.state.toJson(),
                'learning_results': receipt.learningResults
                    .map((r) => r.toJson())
                    .toList(),
              });
            }
          }
        }
        syncError = null;
      } catch (_) {
        // Do not expose response bodies, credentials or URLs in native notifications.
        syncError = '结果尚未同步，请检查网络或重新登录；本机记录已保留。';
      }
      if (!closed) publish(session.view());
    }

    Future<void> synchronize() =>
        syncing ??= upload().whenComplete(() => syncing = null);
    final timer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_runtime.invokeMethod<void>('heartbeat'));
      synchronize();
    });
    _runtime.setMethodCallHandler((call) async {
      if (call.method != 'command') throw UnsupportedError(call.method);
      final request = Map<String, dynamic>.from(call.arguments as Map);
      final operation = request['operation'] as String;
      final data = Map<String, dynamic>.from(request['data'] as Map? ?? {});
      if (operation == 'session') {
        // Session credentials are memory-only and are never part of view/journal.
        authGeneration++;
        client?.client.close();
        client = api.ApiClient(basePath: data['api_url'] as String)
          ..addDefaultHeader('Authorization', data['authorization'] as String);
        owner = data['owner_id'] as String;
        return 'null';
      }
      if (operation == 'sync') {
        await synchronize();
        return jsonEncode(syncError);
      }
      final result = await session.command(operation, data);
      if (operation == 'shutdown') {
        closed = true;
        timer.cancel();
        client?.client.close();
        lock.closeSync();
      }
      return jsonEncode(result);
    });
    session.start();
    await _runtime.invokeMethod<void>('ready');
  } catch (_) {
    await _runtime.invokeMethod<void>('failed', '本机执行服务初始化失败，请保留数据并检查设备存储。');
  }
}
