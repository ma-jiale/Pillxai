import 'package:pillxai_api_client/api.dart' as api;

const pillboxSlots = ['早', '午', '晚', '睡前'];

extension PillboxLayout on api.AppSettings {
  List<int> get fullBoxOrder =>
      boxSlotOrder.length == 4 ? boxSlotOrder : const [0, 1, 2, 3];

  List<int> get visibleBoxOrder =>
      fullBoxOrder.where((slot) => bedtimeEnabled || slot != 3).toList();
}
