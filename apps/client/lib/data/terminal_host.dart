import 'terminal_host_stub.dart'
    if (dart.library.io) 'terminal_host_native.dart'
    as platform;

abstract interface class TerminalHost {
  bool get supported;
  Stream<Map<String, dynamic>> get updates;
  Future<void> initialize();
  Future<dynamic> command(
    String command, [
    Map<String, dynamic> data = const {},
  ]);
  Future<void> close();
}

TerminalHost createTerminalHost() => platform.createHost();
