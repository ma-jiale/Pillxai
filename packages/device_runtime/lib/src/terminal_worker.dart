import 'dart:isolate';

import 'execution_journal.dart';
import 'terminal_session.dart';
import 'windows_serial_transport.dart';

/// Both platform hosts use the same serialized session and execution engine.
void terminalWorker(Map<String, dynamic> arguments) {
  final output = arguments['output'] as SendPort;
  final input = ReceivePort();
  final session = TerminalSession(
    journal: ExecutionJournal(arguments['database'] as String),
    platform: 'windows',
    hardwareTransport: (config) =>
        WindowsSerialTransport(config['port'] as String),
    ports: WindowsSerialTransport.availablePorts,
    publish: (view) =>
        output.send(view.containsKey('worker_error') ? view : {'view': view}),
  );
  input.listen((message) async {
    final request = message as Map;
    try {
      final result = await session.command(
        request['command'] as String,
        Map<String, dynamic>.from(request['data'] as Map? ?? {}),
      );
      output.send({'id': request['id'], 'result': result});
      if (request['command'] == 'shutdown') input.close();
    } catch (error) {
      output.send({'id': request['id'], 'error': error.toString()});
    }
  });
  output.send({'port': input.sendPort});
  session.start();
}
