/// Prescription doses are expressed in the original unit, never machine counts.
/// 四个时段的原片/原粒用量；字段 final，创建后不能逐项修改。
/// 例如 morning: .5 表示半片原药，不代表半个机器计数。
class DoseSchedule {
  const DoseSchedule({
    this.morning = 1,
    this.noon = 1,
    this.evening = 1,
    this.night = 0,
  });

  final double morning;
  final double noon;
  final double evening;
  final double night;

  List<double> get values => [morning, noon, evening, night];
  bool get hasDose => values.any((dose) => dose > 0);

  String describe(String unit) {
    const labels = ['早', '午', '晚', '睡前'];
    return [
      for (var index = 0; index < values.length; index++)
        if (values[index] > 0)
          '${labels[index]} ${formatDose(values[index])} $unit',
    ].join(' · ');
  }
}

/// 用于已通过校验的有限数值：1.0 显示为“1”，0.5 保留小数。
String formatDose(double dose) =>
    dose == dose.roundToDouble() ? dose.toInt().toString() : dose.toString();

/// 一条不可变的用药描述。编辑时用新对象替换，执行快照仍引用原对象。
/// copyWith 保留身份 id 和图片，只替换明确传入的字段。
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    required this.strength,
    this.form = '整片',
    this.doses = const DoseSchedule(),
    this.unit = '片',
    this.meal = '饭后',
    this.target = 0,
    this.startDate,
    this.endDate,
    this.stopped = false,
    this.imageAsset,
  });
  final String id;
  final String name;
  final String strength;
  final String form;
  final DoseSchedule doses;
  final String unit;
  final String meal;
  // 处方本身 target 为0（尚未计划）；PreparationPlan 复制条目时填入本次颗粒数。
  final int target;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool stopped;
  final String? imageAsset;

  String get schedule => doses.describe(unit);

  /// 日期范围判断与剂量有效性分开，才能显示范围内处方的输入错误。
  bool isInPeriod(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !stopped &&
        (startDate == null || !day.isBefore(startDate!)) &&
        (endDate == null || !day.isAfter(endDate!));
  }

  bool isEffectiveOn(DateTime date) => isInPeriod(date) && doses.hasDose;

  /// 返回新对象，不修改接收者。clearEndDate 区分“清空结束日”和“不修改”。
  /// 示例：medicine.copyWith(stopped: true) 停用当前条目但保持同一个 id。
  Medicine copyWith({
    String? name,
    String? strength,
    String? form,
    DoseSchedule? doses,
    String? unit,
    String? meal,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? stopped,
    int? target,
  }) => Medicine(
    id: id,
    name: name ?? this.name,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    doses: doses ?? this.doses,
    unit: unit ?? this.unit,
    meal: meal ?? this.meal,
    target: target ?? this.target,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : endDate ?? this.endDate,
    stopped: stopped ?? this.stopped,
    imageAsset: imageAsset,
  );
}

/// 当前会话的长者资料。资料与药物列表可编辑，但不能反向改写任务/历史。
/// 开始任务时 DemoModel 复制姓名、床位和药物列表，形成独立快照。
class Resident {
  Resident({
    required this.id,
    required this.name,
    required this.bed,
    required this.medicines,
    this.avatarAsset,
  });
  final String id;
  String name;
  String bed;
  final List<Medicine> medicines;
  final String? avatarAsset;
}
