import 'package:flutter/foundation.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../models/settings_store.dart';
import '../models/prescription_store.dart';
import 'backend_connection.dart';

class SettingsController extends ChangeNotifier implements SettingsStore {
  SettingsController(this.backend, {required this.onSaved})
    : _saved = backend.settings!,
      _draft = backend.settings!;
  final BackendConnection backend;
  final VoidCallback onSaved;
  api.AppSettings _saved;
  api.AppSettings _draft;
  bool _saving = false;
  bool _disposed = false;
  @override
  bool get persistent => true;
  @override
  bool get canSaveRules => backend.account?.role == api.Role.admin && !_saving;
  @override
  int get preparationDays => _draft.preparationDays;
  @override
  bool get splitMeals => _draft.splitMeals;
  @override
  bool get bedtime => _draft.bedtimeEnabled;
  @override
  bool get startTomorrow => _draft.startTomorrow;

  @override
  Future<void> saveSettings({
    required int days,
    required bool split,
    required bool night,
    required bool tomorrow,
  }) async {
    if (!canSaveRules) throw const SaveFailure('当前无法修改设置。');
    _draft = _draft.copyWith(
      preparationDays: days,
      splitMeals: split,
      bedtimeEnabled: night,
      startTomorrow: tomorrow,
    );
    _saving = true;
    notifyListeners();
    try {
      final result = await backend.request(
        backend.settingsApi.saveSettings(
          api.SaveSettings(
            expectedRevision: _saved.revision,
            preparationDays: days,
            splitMeals: split,
            bedtimeEnabled: night,
            startTomorrow: tomorrow,
          ),
        ),
      );
      if (result == null) throw const SaveFailure('保存结果尚未确认，请重新加载核对。');
      if (_disposed) return;
      _accept(result);
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  Future<void> reloadSettings() async {
    final result = await backend.request(backend.settingsApi.getSettings());
    if (result == null) throw const SaveFailure('设置读取失败，请重试。');
    if (_disposed) return;
    _accept(result);
    notifyListeners();
  }

  void _accept(api.AppSettings value) {
    _saved = _draft = value;
    backend.settings = value;
    onSaved();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
