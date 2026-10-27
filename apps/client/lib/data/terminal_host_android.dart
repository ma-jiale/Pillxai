import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'terminal_host.dart';

TerminalHost createHost() => AndroidTerminalHost();

/// UI proxy only. The Android service retains its engine when this UI detaches.
class AndroidTerminalHost implements TerminalHost {
  static const channel = MethodChannel('pillxai/terminal');
  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  Future<void>? _initializing;
  bool _closed = false;

  @override
  bool get supported => true;
  @override
  Stream<Map<String, dynamic>> get updates => _updates.stream;

  @override
  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((Object error) {
        _initializing = null;
        throw error;
      });

  Future<void> _initialize() async {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'update' && !_closed) {
        _updates.add(
          jsonDecode(call.arguments as String) as Map<String, dynamic>,
        );
      }
    });
    final raw = await channel
        .invokeMethod<String>('initialize')
        .timeout(const Duration(seconds: 45));
    if (raw != null && !_closed) {
      _updates.add(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  @override
  Future<dynamic> command(
    String command, [
    Map<String, dynamic> data = const {},
  ]) async {
    await initialize();
    final raw = await channel
        .invokeMethod<String>('command', {'operation': command, 'data': data})
        .timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            throw TimeoutException('本机操作结果未确认，请核对状态，勿重复启动。');
          },
        );
    return raw == null ? null : jsonDecode(raw);
  }

  @override
  Future<void> close() async {
    await command('shutdown');
    _closed = true;
    channel.setMethodCallHandler(null);
    await _updates.close();
  }
}
