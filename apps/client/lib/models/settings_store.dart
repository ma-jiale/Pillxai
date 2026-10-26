import 'package:flutter/foundation.dart';

/// Settings UI contract, independent of dispensing and transport implementations.
abstract interface class SettingsStore implements Listenable {
  int get preparationDays;
  bool get splitMeals;
  bool get bedtime;
  bool get startTomorrow;
  bool get canSaveRules;
  void saveSettings({
    required int days,
    required bool split,
    required bool night,
    required bool tomorrow,
  });
}

/// Production rules are read-only until their persistence flow is implemented.
/// Bedtime comes from the server; the other values are the documented defaults.
class ReadOnlySettingsStore extends ChangeNotifier implements SettingsStore {
  ReadOnlySettingsStore({required this.bedtime});
  @override
  final bool bedtime;
  @override
  int get preparationDays => 7;
  @override
  bool get splitMeals => true;
  @override
  bool get startTomorrow => false;
  @override
  bool get canSaveRules => false;
  @override
  void saveSettings({
    required int days,
    required bool split,
    required bool night,
    required bool tomorrow,
  }) => throw StateError('Rule editing is not available.');
}
