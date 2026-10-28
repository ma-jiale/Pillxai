import 'dart:async';
import 'dart:io';

import 'package:pillxai_client/data/terminal_host_native.dart';

Future<void> main() async {
  final root = Directory('../../.var/terminal-host-check').absolute.path;
  final host = NativeTerminalHost(dataDirectory: root);
  final second = NativeTerminalHost(dataDirectory: root);
  final views = <Map<String, dynamic>>[];
  final subscription = host.updates.listen(views.add);
  try {
    await host.initialize();
    var rejected = false;
    try {
      await second.initialize();
    } on StateError {
      rejected = true;
    }
    if (!rejected) throw StateError('Second owner was not blocked');
    await host.command('configure', {
      'mode': 'simulator',
      'uid': 'AABBCCDD',
      'device_id': 'host-check',
    });
    await host.command('connect');
    await host.command('open_binding');
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    Map value = {};
    while (DateTime.now().isBefore(deadline)) {
      value = await host.command('view') as Map;
      if (value['observed_uid'] == 'AABBCCDD' &&
          (value['state'] as Map)['phase'] == 'idle') {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (value['observed_uid'] != 'AABBCCDD' || views.isEmpty) {
      throw StateError('Worker feedback did not reach host');
    }
    final ports = await host.command('ports') as List;
    await host.command('disconnect');
    stdout.writeln(
      'PASSED: Windows worker isolate, SQLite, simulation feedback, exclusive owner, COM enumeration (${ports.length} ports; none opened).',
    );
  } finally {
    await second.close();
    await host.close();
    await subscription.cancel();
  }
}
