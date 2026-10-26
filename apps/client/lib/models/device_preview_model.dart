import 'dart:async';

import 'package:flutter/foundation.dart';

/// UI-only device state. Never grants permission to operate a physical machine.
class DevicePreviewModel extends ChangeNotifier {
  DevicePreviewModel({this.canConnect});
  final bool Function()? canConnect;
  final List<String> _devices = [];
  String? _connectedDevice;
  String? _connectingDevice;
  String? _failedDevice;
  Timer? _connectionTimer;

  List<String> get devices => List.unmodifiable(_devices);
  String? get connectedDevice => _connectedDevice;
  String? get connectingDevice => _connectingDevice;
  String? get failedDevice => _failedDevice;

  void add(String name) {
    if (_devices.contains(name) || canConnect?.call() == false) return;
    _devices.add(name);
    connect(name);
  }

  void connect(String name) {
    if (!_devices.contains(name) || canConnect?.call() == false) return;
    _connectionTimer?.cancel();
    _connectingDevice = name;
    _failedDevice = null;
    notifyListeners();
    _connectionTimer = Timer(
      const Duration(milliseconds: 900),
      completeConnectionPreview,
    );
  }

  /// Completes a simulated attempt; it does not open Bluetooth or a serial port.
  void completeConnectionPreview({bool success = true}) {
    final name = _connectingDevice;
    if (name == null) return;
    _connectionTimer?.cancel();
    if (success && canConnect?.call() != false) {
      _connectedDevice = name;
    } else {
      _failedDevice = name;
    }
    _connectingDevice = null;
    notifyListeners();
  }

  void disconnect() {
    _connectionTimer?.cancel();
    _connectingDevice = null;
    _connectedDevice = null;
    _failedDevice = null;
    notifyListeners();
  }

  void remove(String name) {
    _devices.remove(name);
    if (_connectingDevice == name) {
      _connectionTimer?.cancel();
      _connectingDevice = null;
    }
    if (_connectedDevice == name) _connectedDevice = null;
    if (_failedDevice == name) _failedDevice = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }
}
