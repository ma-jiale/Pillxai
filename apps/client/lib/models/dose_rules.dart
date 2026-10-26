/// 剂量输入的共享规则。只处理数值和投料形态，不依赖 Widget 或设备。
///
/// 这里的上限是预览程序的数值保护，不是临床剂量建议或机器容量。
/// 最大值乘四时段、七天后仍能在 Dart VM 和 Web 中精确表示为整数。
const double maxPreviewDose = 1000000000;

/// 将输入变成原片/原粒用量。空白表示该时段不用药，格式错误返回 null。
///
/// 示例：parseDoseInput(' 0.5 ') == 0.5，parseDoseInput('') == 0。
/// 此函数只解析；NaN、负数等由 validateDose 拒绝。
double? parseDoseInput(String input) =>
    input.trim().isEmpty ? 0 : double.tryParse(input.trim());

/// 检查单个时段，成功返回 null，失败返回可直接显示的原因。
/// slot 按早、午、晚、睡前排列（0–3）；half 表示人工预切半片。
/// 不修改输入，也不自动把 0.5 四舍五入成 1。
String? validateDose(
  double? dose, {
  required int slot,
  required bool half,
  required bool bedtimeEnabled,
}) {
  if (dose == null || !dose.isFinite || dose < 0) return '请输入非负用量';
  if (dose > maxPreviewDose) return '数值过大，请核对用量';
  if (slot == 3 && !bedtimeEnabled && dose > 0) return '请先启用睡前格';
  if (half && dose != 0 && dose != .5) return '半片每次填 0.5';
  if (!half && dose != dose.roundToDouble()) return '整片 / 整粒填整数';
  return null;
}

/// 检查整个处方是否至少有一个正用量。各时段是否合法另由 validateDose 检查。
String? validateDailyDose(Iterable<double?> doses) =>
    doses.any((dose) => dose != null && dose.isFinite && dose > 0)
    ? null
    : '至少填写一个时段的正用量。';
