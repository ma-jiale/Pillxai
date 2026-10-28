// Engineering entrypoint only. It uses simulated hardware and an emulator-local HTTP stub only.
// Build explicitly with -t tool/check_android_runtime.dart on an isolated emulator.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;
import 'package:pillxai_client/data/android_runtime.dart' as runtime;
import 'package:pillxai_client/data/terminal_host_android.dart';

import '../../../packages/device_runtime/test/support/task_fixture.dart';

@pragma('vm:entry-point')
void terminalServiceMain() => runtime.runTerminalService();

final status = ValueNotifier('正在验证 Android 服务');
void report(String value) {
  status.value = value;
  debugPrint(value);
}

void require(bool value, String message) {
  if (!value) throw StateError(message);
}

Map<String, dynamic> json(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

void main() {
  if (!const bool.fromEnvironment('PILLXAI_RUNTIME_CHECK')) {
    throw StateError(
      'Build only with PILLXAI_RUNTIME_CHECK=true (isolated test package).',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: status,
            builder: (_, value, _) => Text(value),
          ),
        ),
      ),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => check());
}

Future<void> check() async {
  final host = AndroidTerminalHost();
  Future<Map> view() async => await host.command('view') as Map;
  Future<Map> waitFor(bool Function(Map) condition) async {
    for (var i = 0; i < 200; i++) {
      final snapshot = await view();
      if (condition(snapshot)) return snapshot;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('Timed out: ${await view()}');
  }

  try {
    await host.initialize();
    final initial = await view();
    require(initial['platform'] == 'android', 'wrong host');
    if (initial['task'] != null) {
      require(
        initial['state']['phase'] == 'recovery',
        'restart must require recovery',
      );
      require(
        initial['state']['connected'] == false,
        'restart must not reconnect',
      );
      final before = initial['state']['sequence'];
      await Future<void>.delayed(const Duration(seconds: 2));
      require(
        (await view())['state']['sequence'] == before,
        'restart must not issue commands',
      );
      await host.command('connect');
      await host.command('stop');
      await waitFor((v) => v['state']['phase'] == 'awaitingSafeConfirmation');
      await host.command('cancel');
      final cancelled = await view();
      await host.command('acknowledge', {
        'sequence': cancelled['state']['sequence'],
      });
      await host.close();
      report(
        'ANDROID_CHECK_PASSED: foreground service, background progress, two trays, SQLite, force-stop recovery, no replay',
      );
      return;
    }
    await host.command('configure', {'mode': 'simulator', 'uid': 'A1B2C3D4'});
    await host.command('connect');
    var task = fixture(initial['terminal_id'] as String);
    task = task.copyWith(
      batches: [
        task.batches.first.copyWith(
          total: 80,
          matrix: [
            [80, 0, 0, 0, 0, 0, 0],
            List.filled(7, 0),
            List.filled(7, 0),
            List.filled(7, 0),
          ],
        ),
        task.batches.last,
      ],
    );
    await host.command('attach', json(task));
    await waitFor((v) => v['state']['phase'] == 'ready');
    await host.command(
      'begin',
      json(task.copyWith(state: api.TaskState.started)),
    );
    await waitFor((v) => v['state']['phase'] == 'running');
    report('ANDROID_CHECK_BACKGROUND_WINDOW');
    await Future<void>.delayed(const Duration(seconds: 20));
    final background = await view();
    require(
      background['state']['batch'] == 1 &&
          background['state']['phase'] == 'ready',
      'service did not finish first tray in background',
    );
    report('ANDROID_CHECK_BACKGROUND_PASSED');
    await host.command('continue_tray');
    await waitFor((v) => v['state']['phase'] == 'collecting');
    await host.command('sim_remove');
    final completed = await waitFor((v) => v['state']['phase'] == 'completed');
    final events = <dynamic>[];
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        require(
          request.headers.value('Authorization') == 'Bearer emulator-only',
          'missing session',
        );
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        final page = body['events'] as List;
        require(
          page.first['sequence'] == events.length + 1,
          'non-contiguous upload',
        );
        events.addAll(page);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            task.copyWith(
              sequence: page.last['sequence'] as int,
              state: api.TaskState.completed,
            ),
          ),
        );
      } catch (error) {
        request.response.statusCode = 409;
        request.response.write(error.toString());
      }
      await request.response.close();
    });
    await host.command('session', {
      'api_url': 'http://127.0.0.1:${server.port}',
      'authorization': 'Bearer emulator-only',
      'owner_id': task.ownerId,
    });
    await waitFor((v) => v['task'] == null);
    await server.close(force: true);
    require(
      events.where((e) => e['kind'] == 'batch_finished').length == 2,
      'batch facts missing across background upload pages',
    );
    require(
      events.length == completed['state']['sequence'],
      'upload lost events',
    );
    require(
      !jsonEncode(await view()).contains('emulator-only'),
      'credential leaked into snapshot',
    );
    report('ANDROID_CHECK_BACKGROUND_UPLOAD_PASSED');
    await host.command('sim_insert', {'uid': 'A1B2C3D4'});
    final interrupted = fixture(initial['terminal_id'] as String, batches: 1);
    await host.command('attach', json(interrupted));
    await waitFor((v) => v['state']['phase'] == 'ready');
    // Leave a durable, claimed task for the force-stop/restart half of this check.
    report('ANDROID_CHECK_KILL_WINDOW');
    await Future<void>.delayed(const Duration(seconds: 60));
    throw StateError('Force-stop/restart was not performed by the test driver');
  } catch (error, trace) {
    report('ANDROID_CHECK_FAILED: $error\n$trace');
  }
}
