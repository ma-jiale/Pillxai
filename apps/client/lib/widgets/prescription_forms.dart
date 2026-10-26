import 'package:flutter/material.dart';

import 'app_menu.dart';

import '../models/demo_model.dart';
import '../models/dose_rules.dart';

String formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// 严格解析 YYYY-MM-DD；DateTime 会归一化2月30日，所以还需格式化回比对。
DateTime? parseDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value.trim())) return null;
  final date = DateTime.tryParse(value.trim());
  return date != null && formatDate(date) == value.trim() ? date : null;
}

String medicinePeriod(Medicine medicine) {
  if (medicine.endDate == null) return '长期用药';
  final start = medicine.startDate;
  final end = medicine.endDate!;
  return '${start == null ? '' : '${start.month}/${start.day} — '}${end.month}/${end.day}';
}

/// 未修改时直接允许离开；有修改时询问。返回 true 才能丢弃草稿。
Future<bool> _confirmDiscard(BuildContext context, bool dirty) async {
  if (!dirty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃未保存的修改？'),
          content: const Text('本次输入还没有保存。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃修改'),
            ),
          ],
        ),
      ) ??
      false;
}

/// 长者编辑草稿。TextEditingController 保存文字，Form 统一触发校验。
/// 保存通过 Navigator.pop 返回新对象；调用页决定是否写入模型。
class ResidentForm extends StatefulWidget {
  const ResidentForm({super.key, required this.model, this.resident});
  final DemoModel model;
  final Resident? resident;

  @override
  State<ResidentForm> createState() => _ResidentFormState();
}

class _ResidentFormState extends State<ResidentForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.resident?.name);
  late final _bed = TextEditingController(text: widget.resident?.bed);
  bool _dirty = false;

  @override
  void dispose() {
    _name.dispose();
    _bed.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (await _confirmDiscard(context, _dirty) && mounted) {
      Navigator.pop(context);
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      Resident(
        id: widget.resident?.id ?? 'r${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        bed: _bed.text.trim(),
        medicines: widget.resident?.medicines ?? [],
        avatarAsset: widget.resident?.avatarAsset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _FormDialog(
    title: widget.resident == null ? '添加长者' : '编辑长者资料',
    subtitle: '姓名与床位，清楚对应每一份处方。',
    width: 480,
    onCancel: _cancel,
    onSave: _save,
    child: Form(
      key: _form,
      onChanged: () => _dirty = true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(labelText: '姓名', counterText: ''),
            validator: (value) =>
                value == null || value.trim().isEmpty ? '请输入长者姓名' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _bed,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '床位（选填）',
              hintText: '例如：3 楼 301-1 床',
              counterText: '',
            ),
            validator: (value) {
              final duplicate = widget.model.bedConflict(
                value ?? '',
                excludingId: widget.resident?.id,
              );
              return duplicate == null ? null : '该床位已属于${duplicate.name}';
            },
          ),
        ],
      ),
    ),
  );
}

/// 药物草稿与原处方分离。字段级错误和整日剂量错误分别显示，输入失败不清空。
class MedicineForm extends StatefulWidget {
  const MedicineForm({
    super.key,
    required this.resident,
    required this.bedtimeEnabled,
    this.medicine,
  });
  final Resident resident;
  final Medicine? medicine;
  final bool bedtimeEnabled;

  @override
  State<MedicineForm> createState() => _MedicineFormState();
}

class _MedicineFormState extends State<MedicineForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.medicine?.name);
  late final _strength = TextEditingController(text: widget.medicine?.strength);
  late final _start = TextEditingController(
    text: formatDate(widget.medicine?.startDate ?? DateTime.now()),
  );
  late final _end = TextEditingController(
    text: widget.medicine?.endDate == null
        ? ''
        : formatDate(widget.medicine!.endDate!),
  );
  // 一个时段一个控制器，顺序固定为早、午、晚、睡前；dispose 时逐一释放。
  late final _doses = (widget.medicine?.doses.values ?? [0.0, 0.0, 0.0, 0.0])
      .map((value) => TextEditingController(text: formatDose(value)))
      .toList();
  late String _unit = widget.medicine?.unit ?? '片';
  late String _meal = widget.medicine?.meal ?? '饭后';
  late bool _half = widget.medicine?.form == '预切半片';
  late bool _longTerm = widget.medicine?.endDate == null;
  bool _dirty = false;
  String? _doseError;

  @override
  void dispose() {
    for (final controller in [_name, _strength, _start, _end, ..._doses]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _cancel() async {
    if (await _confirmDiscard(context, _dirty) && mounted) {
      Navigator.pop(context);
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '请填写此项' : null;

  // FormField 负责显示错误；规则由纯函数提供，与准备计划保持同一含义。
  String? _validateDose(String? input, int index) => validateDose(
    parseDoseInput(input ?? ''),
    slot: index,
    half: _half,
    bedtimeEnabled: widget.bedtimeEnabled,
  );

  void _save() {
    final valid = _form.currentState!.validate();
    final values = _doses
        .map((controller) => parseDoseInput(controller.text))
        .toList();
    setState(() => _doseError = validateDailyDose(values));
    if (!valid || _doseError != null) return;
    Navigator.pop(
      context,
      Medicine(
        id: widget.medicine?.id ?? 'm${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        strength: _strength.text.trim(),
        unit: _unit,
        form: _half
            ? '预切半片'
            : _unit == '粒'
            ? '整粒'
            : '整片',
        doses: DoseSchedule(
          morning: values[0]!,
          noon: values[1]!,
          evening: values[2]!,
          night: values[3]!,
        ),
        meal: _meal,
        startDate: parseDate(_start.text),
        endDate: _longTerm ? null : parseDate(_end.text),
        stopped: widget.medicine?.stopped ?? false,
        imageAsset: widget.medicine?.imageAsset,
      ),
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final enteredDate = parseDate(controller.text);
    final current =
        enteredDate != null &&
            enteredDate.year >= 1900 &&
            enteredDate.year <= 2200
        ? enteredDate
        : DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (!mounted || date == null) return;
    setState(() {
      controller.text = formatDate(date);
      _dirty = true;
    });
  }

  Widget _dateField(
    String label,
    TextEditingController controller, {
    bool end = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.datetime,
    maxLength: 10,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'YYYY-MM-DD',
      counterText: '',
      suffixIcon: IconButton(
        tooltip: '选择$label',
        onPressed: () => _pickDate(controller),
        icon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
    ),
    validator: (value) {
      final date = parseDate(value ?? '');
      if (date == null) return '请填写有效日期，如 2026-10-18';
      if (date.year < 1900 || date.year > 2200) return '日期年份需在 1900—2200 之间';
      final start = parseDate(_start.text);
      if (end && start != null && date.isBefore(start)) return '结束日期不能早于开始日期';
      return null;
    },
  );

  Widget _section(String title, Widget content) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 16),
      content,
    ],
  );

  Widget _pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 430) {
        return Column(children: [first, const SizedBox(height: 16), second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) => _FormDialog(
    title: widget.medicine == null ? '添加药物' : '编辑药物',
    subtitle: '${widget.resident.name} · 按已确定的处方填写',
    width: 700,
    onCancel: _cancel,
    onSave: _save,
    child: Form(
      key: _form,
      onChanged: () => _dirty = true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section(
            '药物信息',
            Column(
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: '药物名称',
                    counterText: '',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _strength,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: '规格',
                    hintText: '例如：10 mg / 片',
                    counterText: '',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 18),
                _pair(
                  AppSelect<String>(
                    value: _unit,
                    label: '计量单位',
                    showLabel: true,
                    options: const [
                      AppSelectOption('片', '片'),
                      AppSelectOption('粒', '粒'),
                    ],
                    onChanged: (value) => setState(() {
                      _unit = value;
                      _dirty = true;
                    }),
                  ),
                  AppSelect<bool>(
                    value: _half,
                    label: '投料形态',
                    showLabel: true,
                    options: [
                      AppSelectOption(false, _unit == '片' ? '整片' : '整粒'),
                      const AppSelectOption(true, '预切半片'),
                    ],
                    onChanged: (value) => setState(() {
                      _half = value;
                      _dirty = true;
                    }),
                    validator: (_) => _half && _unit != '片' ? '半片仅适用于片剂' : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _section(
            '每次用量',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth < 430
                        ? (constraints.maxWidth - 12) / 2
                        : (constraints.maxWidth - 36) / 4;
                    const labels = ['早', '午', '晚', '睡前'];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: [
                        for (var index = 0; index < 4; index++)
                          SizedBox(
                            width: width,
                            child: TextFormField(
                              key: ValueKey('dose-$index'),
                              controller: _doses[index],
                              enabled:
                                  index != 3 ||
                                  widget.bedtimeEnabled ||
                                  (widget.medicine?.doses.night ?? 0) > 0,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: '${labels[index]}用量',
                                suffixText: _unit,
                              ),
                              validator: (value) => _validateDose(value, index),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  _half ? '填写原片用量；0.5 片对应 1 颗预切半片。' : '不服用的时段填写 0。',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff858585),
                  ),
                ),
                if (!widget.bedtimeEnabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '睡前格尚未启用，可在设置中开启。',
                      style: TextStyle(fontSize: 12, color: Color(0xff858585)),
                    ),
                  ),
                if (_doseError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _doseError!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                AppSelect<String>(
                  value: _meal,
                  label: '餐食关系',
                  showLabel: true,
                  options: const [
                    '饭前',
                    '饭后',
                    '随餐',
                    '无餐食限制',
                  ].map((value) => AppSelectOption(value, value)).toList(),
                  onChanged: (value) => setState(() {
                    _meal = value;
                    _dirty = true;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          _section(
            '用药期间',
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dateField('开始日期', _start),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('长期用药', style: TextStyle(fontSize: 14)),
                  subtitle: const Text(
                    '没有预定的结束日期',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _longTerm,
                  onChanged: (value) => setState(() {
                    _longTerm = value;
                    _dirty = true;
                  }),
                ),
                if (!_longTerm) ...[
                  const SizedBox(height: 12),
                  _dateField('结束日期', _end, end: true),
                  const SizedBox(height: 8),
                  const Text(
                    '疗程包含开始与结束当天。',
                    style: TextStyle(fontSize: 12, color: Color(0xff858585)),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// 表单共同外壳：头部和底部操作固定，中部随键盘高度缩小并允许触摸滚动。
/// 系统返回交给 onCancel，因此与屏幕按钮使用相同的未保存保护。
class _FormDialog extends StatelessWidget {
  const _FormDialog({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onCancel,
    required this.onSave,
    required this.width,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final double width;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.sizeOf(context).width < 600 ? 20.0 : 28.0;
    return PopScope(
      canPop: false,
      // Android 返回手势与屏幕“取消”遵循相同的未保存保护。
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onCancel();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.all(20),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: width,
            maxHeight: MediaQuery.sizeOf(context).height - 48,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(inset, inset, inset, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff858585),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.all(inset),
                  child: child,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 16, inset, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: onCancel, child: const Text('取消')),
                    const SizedBox(width: 12),
                    FilledButton(onPressed: onSave, child: const Text('保存')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
