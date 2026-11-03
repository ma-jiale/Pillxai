import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pillxai_execution_core/execution_core.dart';
import 'package:win32/win32.dart';

/// Windows-only, synchronous bounded I/O for the engineering CLI worker.
/// UI integration must host this transport outside the rendering isolate.
final class WindowsSerialTransport implements DeviceTransport {
  WindowsSerialTransport(this.portName) {
    if (!RegExp(r'^COM[1-9][0-9]*$').hasMatch(portName)) {
      throw ArgumentError('Use an explicitly selected COM name, e.g. COM7');
    }
  }

  final String portName;
  int _handle = INVALID_HANDLE_VALUE;

  /// Use Windows device metadata for display. Enumerating never opens a port.
  static List<Map<String, String>> deviceCandidates() => using((arena) {
    final candidates = <Map<String, String>>[];
    final devices = SetupDiGetClassDevs(
      GUIDFromString(GUID_DEVCLASS_PORTS, allocator: arena),
      nullptr,
      0,
      DIGCF_PRESENT,
    );
    if (devices == INVALID_HANDLE_VALUE) {
      throw OSError('读取设备列表失败', GetLastError());
    }
    try {
      final info = arena<SP_DEVINFO_DATA>()
        ..ref.cbSize = sizeOf<SP_DEVINFO_DATA>();
      final buffer = arena<Uint16>(1024);
      final value = buffer.cast<Utf16>();
      final length = arena<Uint32>();
      final portName = 'PortName'.toNativeUtf16(allocator: arena);
      for (
        var index = 0;
        SetupDiEnumDeviceInfo(devices, index, info) != 0;
        index++
      ) {
        if (SetupDiGetDeviceInstanceId(devices, info, value, 1024, nullptr) ==
            0)
          continue;
        final instance = value.toDartString().toUpperCase();
        final bus = instance.split('\\').first;
        final transport = switch (bus) {
          'BTHENUM' => 'bluetooth',
          'USB' || 'FTDIBUS' => 'usb',
          _ => null,
        };
        if (transport == null) continue;
        final key = SetupDiOpenDevRegKey(
          devices,
          info,
          DICS_FLAG_GLOBAL,
          0,
          DIREG_DEV,
          KEY_QUERY_VALUE,
        );
        if (key == INVALID_HANDLE_VALUE) continue;
        try {
          length.value = 2048;
          if (RegGetValue(
                key,
                nullptr,
                portName,
                RRF_RT_REG_SZ,
                nullptr,
                buffer,
                length,
              ) !=
              ERROR_SUCCESS)
            continue;
          final port = value.toDartString();
          if (!RegExp(r'^COM[1-9][0-9]*$').hasMatch(port)) continue;
          candidates.add({'address': port, 'transport': transport});
        } finally {
          RegCloseKey(key);
        }
      }
    } finally {
      SetupDiDestroyDeviceInfoList(devices);
    }
    candidates.sort(
      (a, b) =>
          int.parse(a['address']!.substring(3))
              .compareTo(int.parse(b['address']!.substring(3))),
    );
    return candidates;
  });

  static List<String> availablePorts() {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows COM transport only');
    }
    return using((arena) {
      final buffer = arena<Uint16>(65536);
      final length = QueryDosDevice(nullptr, buffer.cast(), 65536);
      if (length == 0) throw OSError('QueryDosDevice failed', GetLastError());
      final names = String.fromCharCodes(buffer.asTypedList(length))
          .split('\u0000');
      return names
          .where((name) => RegExp(r'^COM[1-9][0-9]*$').hasMatch(name))
          .toList()
        ..sort(
          (a, b) =>
              int.parse(a.substring(3)).compareTo(int.parse(b.substring(3))),
        );
    });
  }

  @override
  Future<void> open() async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows COM transport only');
    }
    if (_handle != INVALID_HANDLE_VALUE) throw StateError('Already connected');
    using((arena) {
      final name = '\\\\.\\$portName'.toNativeUtf16(allocator: arena);
      _handle = CreateFile(
        name,
        GENERIC_READ | GENERIC_WRITE,
        0,
        nullptr,
        OPEN_EXISTING,
        0,
        NULL,
      );
      if (_handle == INVALID_HANDLE_VALUE) {
        throw OSError('Cannot open $portName', GetLastError());
      }
      try {
        final config = arena<DCB>();
        config.ref.DCBlength = sizeOf<DCB>();
        _check(GetCommState(_handle, config), 'GetCommState');
        config.ref
          ..BaudRate = 115200
          ..ByteSize = 8
          ..Parity = NOPARITY
          ..StopBits = ONESTOPBIT
          ..bitfield =
              1; // fBinary only: no parity, software or hardware flow control.
        _check(SetCommState(_handle, config), 'SetCommState');
        final timeouts = arena<COMMTIMEOUTS>();
        timeouts.ref
          ..ReadIntervalTimeout =
              0xffffffff // MAXDWORD: return available bytes immediately.
          ..ReadTotalTimeoutMultiplier = 0
          ..ReadTotalTimeoutConstant = 0
          ..WriteTotalTimeoutMultiplier = 0
          ..WriteTotalTimeoutConstant = 1000;
        _check(SetCommTimeouts(_handle, timeouts), 'SetCommTimeouts');
      } catch (_) {
        CloseHandle(_handle);
        _handle = INVALID_HANDLE_VALUE;
        rethrow;
      }
    });
  }

  @override
  Future<Uint8List> read() async {
    _requireOpen();
    return using((arena) {
      final buffer = arena<Uint8>(4096);
      final count = arena<Uint32>();
      _check(ReadFile(_handle, buffer, 4096, count, nullptr), 'ReadFile');
      return Uint8List.fromList(buffer.asTypedList(count.value));
    });
  }

  @override
  Future<void> write(Uint8List bytes) async {
    _requireOpen();
    using((arena) {
      final buffer = arena<Uint8>(bytes.length);
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final count = arena<Uint32>();
      _check(
        WriteFile(_handle, buffer, bytes.length, count, nullptr),
        'WriteFile',
      );
      if (count.value != bytes.length) {
        throw StateError(
          'Partial write (${count.value}/${bytes.length}); outcome unknown, do not retry automatically',
        );
      }
    });
  }

  @override
  Future<void> close() async {
    if (_handle != INVALID_HANDLE_VALUE) {
      final handle = _handle;
      _handle = INVALID_HANDLE_VALUE;
      _check(CloseHandle(handle), 'CloseHandle');
    }
  }

  void _requireOpen() {
    if (_handle == INVALID_HANDLE_VALUE) {
      throw StateError('Transport is disconnected');
    }
  }

  static void _check(int result, String action) {
    if (result == 0) throw OSError('$action failed', GetLastError());
  }
}
