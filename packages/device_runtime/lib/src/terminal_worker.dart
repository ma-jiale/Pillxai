import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_execution_core/execution_core.dart';

import 'execution_engine.dart';
import 'execution_journal.dart';
import 'machine_simulator.dart';
import 'windows_serial_transport.dart';

/// A serialized worker owns COM and SQLite. Messages contain public snapshots only.
void terminalWorker(Map<String, dynamic> arguments) {
  final output = arguments['output'] as SendPort;
  final input = ReceivePort();
  final journal = ExecutionJournal(arguments['database'] as String);
  final engine = ExecutionEngine(journal);
  Future<void> queue = Future.value();
  String previous = '';
  bool polling = false;
  void publish() {
    final value = jsonEncode(engine.view());
    if (value != previous) {
      previous = value;
      output.send({'view': jsonDecode(value)});
    }
  }

  final timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
    if (polling) return;
    polling = true;
    queue = queue.then((_) async {
      try {
        await engine.tick();
        publish();
      } catch (error) {
        output.send({'worker_error': error.toString()});
      } finally {
        polling = false;
      }
    });
  });
  input.listen((message) {
    final request = message as Map;
    queue = queue.then((_) async {
      try {
        final data = Map<String, dynamic>.from(request['data'] as Map? ?? {});
        Object? result;
        switch (request['command']) {
          case 'view':
            result = engine.view();
          case 'ports':
            result = WindowsSerialTransport.availablePorts();
          case 'configure':
            if (engine.active) throw StateError('任务未结束，不能更换连接配置。');
            if (engine.state.connected) await engine.disconnect();
            journal.setSetting('connection', data);
          case 'connect':
            final config = Map<String, dynamic>.from(
              journal.setting('connection') as Map? ?? {},
            );
            if (config.isEmpty) throw StateError('请先保存设备连接。');
            final DeviceTransport transport = config['mode'] == 'simulator'
                ? MachineSimulator(uid: config['uid'] as String? ?? 'A1B2C3D4')
                : WindowsSerialTransport(config['port'] as String);
            await engine.connect(transport);
          case 'disconnect':
            await engine.disconnect();
          case 'open_binding':
            await engine.openForBinding();
          case 'claim_intent':
            journal.setSetting('claim_intent', data.isEmpty ? null : data);
          case 'attach':
            await engine.attach(api.TaskView.fromJson(data)!);
          case 'begin':
            await engine.begin(api.TaskView.fromJson(data)!);
          case 'continue_tray':
            await engine.continueTray();
          case 'pause':
            await engine.pause();
          case 'resume':
            await engine.resume(
              physicalProgressRetained: data['confirmed'] == true,
            );
          case 'gate':
            await engine.setGate((data['value'] as num).toDouble());
          case 'stop':
            await engine.stopForCancel();
          case 'cancel':
            await engine.confirmCancelled();
          case 'discard':
            await engine.requestDiscard();
          case 'discarded':
            engine.finishDiscard();
          case 'pending':
            result = engine.task == null
                ? []
                : journal.pending(engine.task!.id);
          case 'acknowledge':
            engine.acknowledge(data['sequence'] as int);
          case 'sim_remove':
            if (engine.transport is! MachineSimulator) {
              throw StateError('仅模拟机可注入操作。');
            }
            (engine.transport as MachineSimulator).removeTray();
          case 'sim_insert':
            if (engine.transport is! MachineSimulator) {
              throw StateError('仅模拟机可注入操作。');
            }
            (engine.transport as MachineSimulator).insertTray(
              data['uid'] as String,
            );
          case 'shutdown':
            if (engine.active) throw StateError('任务尚未结束。');
            timer.cancel();
            await engine.disconnect();
            journal.close();
            input.close();
            output.send({'id': request['id'], 'result': true});
            return;
          default:
            throw ArgumentError('Unknown terminal operation');
        }
        publish();
        output.send({'id': request['id'], 'result': result});
      } catch (error) {
        publish();
        output.send({'id': request['id'], 'error': error.toString()});
      }
    });
  });
  output.send({'port': input.sendPort});
  publish();
}
