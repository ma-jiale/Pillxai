import 'terminal_host.dart';

TerminalHost createHost() => UnavailableTerminalHost();

class UnavailableTerminalHost implements TerminalHost {
  @override
  bool get supported => false;
  @override
  Stream<Map<String, dynamic>> get updates => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<dynamic> command(
    String command, [
    Map<String, dynamic> data = const {},
  ]) async => throw UnsupportedError('请使用 Android 或 Windows 本机版连接 HC-06；网页保留资料和计划预览。');
  @override
  Future<void> close() async {}
}
