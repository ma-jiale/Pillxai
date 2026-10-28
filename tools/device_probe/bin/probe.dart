import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:pillxai_device_protocol/device_protocol.dart';
import 'package:pillxai_device_runtime/device_runtime.dart';
import 'package:pillxai_execution_core/execution_core.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'port',
      help: 'Explicit HC-06 outgoing COM, verified on this computer',
    )
    ..addOption('seconds', defaultsTo: '10')
    ..addOption(
      'command',
      allowed: [
        'stop',
        'resume',
        'exit',
        'open',
        'close',
        'gate',
        'turntable',
        'matrix',
      ],
    )
    ..addOption('value', help: 'Explicit device value, no production default')
    ..addOption(
      'matrix',
      help: 'JSON file containing exactly 4 x 7 integer cells',
    )
    ..addOption('database', help: 'Engineering SQLite journal path')
    ..addFlag('confirm-physical-command', negatable: false)
    ..addFlag('help', negatable: false);
  try {
    final args = parser.parse(arguments);
    if (args['help'] as bool || args.rest.isEmpty) {
      stdout.writeln(
        'Actions: list | simulate | listen | encode | send | history',
      );
      stdout.writeln(parser.usage);
      stdout.writeln(
        'send is an engineering operation. It sends exactly one command, without retry.',
      );
      return;
    }
    if (args.rest.length != 1) {
      throw FormatException('Supply exactly one action');
    }
    final action = args.rest.single;
    if (action == 'list') {
      final ports = WindowsSerialTransport.availablePorts();
      stdout.writeln(
        jsonEncode({'candidate_ports': ports, 'identity_verified': false}),
      );
      return;
    }
    Uint8List? command;
    if (action == 'encode' || action == 'send') command = encodeCommand(args);
    if (action == 'encode') {
      stdout.writeln(hex(command!));
      return;
    }
    if (!['simulate', 'listen', 'send', 'history'].contains(action)) {
      throw FormatException('Unknown action: $action');
    }
    if (action == 'send' && !(args['confirm-physical-command'] as bool)) {
      throw FormatException(
        'Sending requires --confirm-physical-command after checking the scene and parameters',
      );
    }
    final port = args['port'] as String?;
    if (['send', 'listen'].contains(action) && port == null) {
      throw FormatException('Select the verified outgoing COM with --port');
    }
    final seconds = int.parse(args['seconds'] as String);
    if (seconds < 1 || seconds > 3600) {
      throw FormatException('seconds must be 1..3600');
    }
    final root = File.fromUri(Platform.script).parent.parent.parent.parent.path;
    final journal = DiagnosticJournal(
      args['database'] as String? ??
          '$root/.var/device-probe/diagnostics.sqlite',
    );
    try {
      if (action == 'history') {
        for (final session in journal.sessions()) {
          stdout.writeln(jsonEncode(session));
        }
        return;
      }
      final simulator = action == 'simulate';
      final DeviceTransport transport = simulator
          ? SimulatedTransport(
              [
                'A',
                'CK\r\nUID:aabb\n',
                'number:1,width:20\n',
                'machine_state:FINISH\nNO CARD\n',
              ].map(utf8.encode).toList(),
            )
          : WindowsSerialTransport(port!);
      var interrupted = false;
      final interrupt = ProcessSignal.sigint.watch().listen(
        (_) => interrupted = true,
      );
      try {
        final id = await ProbeSession(transport, journal).run(
          mode: simulator ? 'simulator' : 'hardware',
          device: simulator ? 'scripted-fixture' : port!,
          duration: Duration(seconds: seconds),
          command: command,
          shouldStop: () => interrupted,
          onEvent: (event) => stdout.writeln(jsonEncode(event.toJson())),
        );
        stdout.writeln(
          jsonEncode({
            'session_id': id,
            'observation_ended': true,
            'machine_stopped': 'not_inferred',
          }),
        );
      } finally {
        await interrupt.cancel();
      }
    } finally {
      journal.close();
    }
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}

Uint8List encodeCommand(ArgResults args) {
  double value() {
    final input = args['value'] as String?;
    if (input == null) throw FormatException('This command requires --value');
    return double.parse(input);
  }

  switch (args['command']) {
    case 'stop':
      return Stm32Commands.stop();
    case 'resume':
      return Stm32Commands.resume();
    case 'exit':
      return Stm32Commands.exitMedicine();
    case 'open':
      return Stm32Commands.openTray();
    case 'close':
      return Stm32Commands.closeTray();
    case 'gate':
      return Stm32Commands.setGate(value());
    case 'turntable':
      return Stm32Commands.setTurntable(value());
    case 'matrix':
      final path = args['matrix'] as String?;
      if (path == null) throw FormatException('matrix requires --matrix FILE');
      final rows = (jsonDecode(File(path).readAsStringSync()) as List)
          .map((row) => (row as List).cast<int>())
          .toList();
      return Stm32Commands.matrix(rows);
    default:
      throw FormatException('Select --command');
  }
}

String hex(List<int> bytes) => bytes
    .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
    .join(' ');
