import 'prescription.dart';
import 'dose_rules.dart';

/// 一次准备的计算结果：输入处方、起日、天数和睡前布局，输出逐药颗粒数。
///
/// 纯计算：不改变处方、不启动设备、不写入覆盖，仅用于当前内存预览。
/// 例如每天早服 1 片、共 3 天，target 为 3；每天早服半片且人工预切，
/// target 仍为 3 颗。有效期外的日期不计数。
class PreparationPlan {
  PreparationPlan(
    this.resident,
    this.start,
    this.days, {
    required this.bedtime,
  }) {
    if (days < 1 || days > 7) throw RangeError.range(days, 1, 7, 'days');
    for (final medicine in resident.medicines) {
      // 先筛有效日期，再校验。已结束/本周期尚未开始的睡前药不阻塞本次。
      final dates = [
        for (var day = 0; day < days; day++)
          DateTime(start.year, start.month, start.day + day),
      ].where(medicine.isInPeriod).toList();
      if (dates.isEmpty) continue;
      _hasDemand = true;
      String? problem;
      for (var slot = 0; slot < 4; slot++) {
        problem ??= validateDose(
          medicine.doses.values[slot],
          slot: slot,
          half: medicine.form == '预切半片',
          bedtimeEnabled: bedtime,
        );
      }
      problem ??= validateDailyDose(medicine.doses.values);
      if (problem != null) {
        // 保留第一个错误；用户解决后重新生成计划即可看到下一项。
        _issue ??= '${medicine.name}：$problem';
        continue;
      }
      var count = 0;
      for (final date in dates) {
        for (var slot = 0; slot < (bedtime ? 4 : 3); slot++) {
          count += particles(medicine, slot, date);
        }
      }
      _medicines.add(medicine.copyWith(target: count));
    }
  }
  final Resident resident;
  final DateTime start;
  final int days;
  final bool bedtime;
  final List<Medicine> _medicines = [];
  bool _hasDemand = false;
  String? _issue;
  List<Medicine> get medicines => List.unmodifiable(_medicines);
  String? get issue => _issue;

  /// 有需求但校验失败，也必须出现在待摆清单，不能显示为“无需准备”。
  bool get hasDemand => _hasDemand;
  bool get canStart => issue == null && medicines.isNotEmpty;
  DateTime get end => DateTime(start.year, start.month, start.day + days - 1);
  static String date(DateTime value) => '${value.month}/${value.day}';
  String get dates => '${date(start)} — ${date(end)}';

  /// 返回一个有效日期、一个时段的计划颗粒数；调用者须先通过剂量校验。
  static int particles(Medicine medicine, int slot, DateTime date) {
    if (!medicine.isEffectiveOn(date)) return 0;
    return (medicine.doses.values[slot] * (medicine.form == '预切半片' ? 2 : 1))
        .round();
  }
}
