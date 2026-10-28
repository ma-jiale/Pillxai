import 'dart:async';

import 'package:flutter/foundation.dart';

/// Settings UI contract, independent of dispensing and transport implementations.
abstract interface class SettingsStore implements Listenable {
  int get preparationDays;
  bool get splitMeals;
  bool get bedtime;
  bool get startTomorrow;
  bool get canSaveRules;
  bool get persistent;
  FutureOr<void> reloadSettings();
  FutureOr<void> saveSettings({
    required int days,
    required bool split,
    required bool night,
    required bool tomorrow,
  });
}
