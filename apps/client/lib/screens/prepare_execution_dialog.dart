import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/preparation_confirmation.dart';
import '../widgets/profile_avatar.dart';
import 'terminal_device_dialog.dart';

class PrepareExecutionDialog extends StatefulWidget {
  const PrepareExecutionDialog({
    super.key,
    required this.terminal,
    required this.plan,
    this.residentAvatar,
  });
  final TerminalController terminal;
  final api.PlanSnapshot plan;
  final String? residentAvatar;
  @override
  State<PrepareExecutionDialog> createState() => _PrepareExecutionDialogState();
}

class _ParameterInput {
  _ParameterInput(this.prescription);
  final api.PrescriptionView prescription;
  api.ParameterView? saved;
  bool learningEnabled = true;
  bool edited = false;
  bool matchesSaved = false;
  final turntable = TextEditingController();
  final gate = TextEditingController();
  void showSelection() {
    final useHistory =
        learningEnabled &&
        matchesSaved &&
        saved!.hasValues &&
        saved!.turntable > 0 &&
        saved!.gate > 0;
    turntable.text = useHistory ? saved!.turntable.toString() : '0.2';
    gate.text = useHistory ? saved!.gate.toString() : '0.7';
    edited = false;
  }

  void dispose() {
    turntable.dispose();
    gate.dispose();
  }
}

class _PrepareExecutionDialogState extends State<PrepareExecutionDialog> {
  late final terminal = widget.terminal;
  late final medicines = [
    for (final tray in widget.plan.trays)
      for (final medicine in tray.medicines)
        _ParameterInput(medicine.prescription),
  ];
  final uid = TextEditingController();
  List<api.LabelView> labels = [];
  String? barcode;
  bool loading = true;
  String? loadError;
  bool get simulator =>
      terminal.device?.configuration.mode == api.DeviceMode.simulator;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final resident = await terminal.backend.request(
        terminal.backend.residents.getResident(widget.plan.residentId),
      );
      barcode = resident?.data.barcode;
      labels =
          await terminal.backend.request(
            terminal.execution.listLabels(widget.plan.residentId),
          ) ??
          [];
      for (final item in medicines) {
        final saved = await terminal.backend.request(
          terminal.execution.getParameters(
            widget.plan.residentId,
            item.prescription.id,
          ),
        );
        item.saved = saved;
        item.learningEnabled = saved?.learningEnabled ?? true;
        item.matchesSaved =
            saved?.medicineId == item.prescription.medicineId &&
            saved?.feedForm == item.prescription.data.feedForm.toJson() &&
            saved?.simulationOnly == simulator;
        item.showSelection();
      }
    } catch (error) {
      loadError = error.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    uid.dispose();
    for (final item in medicines) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> bind() async {
    await terminal.run(() async {
      final value = uid.text.trim().toUpperCase();
      if (!RegExp(r'^[0-9A-F]{1,64}$').hasMatch(value)) {
        throw const FormatException('请输入读取到的十六进制 UID。');
      }
      await terminal.backend.request(
        terminal.execution.bindLabel(
          widget.plan.residentId,
          api.BindLabel(uid: value),
        ),
      );
      labels =
          await terminal.backend.request(
            terminal.execution.listLabels(widget.plan.residentId),
          ) ??
          [];
    });
    if (mounted) setState(() {});
  }

  Future<void> claim() async {
    await terminal.run(() async {
      if (labels.isEmpty && (barcode == null || barcode!.isEmpty)) {
        throw StateError('请先为这位长者设置条码或绑定 RFID 标签。');
      }
      if (terminal.canMaintain) {
        for (final item in medicines) {
          final previous = item.saved;
          if (!item.edited &&
              item.learningEnabled == (previous?.learningEnabled ?? true)) {
            continue; // Starting from defaults must not create fake positive history.
          }
          final speed = double.tryParse(item.turntable.text);
          final gate = double.tryParse(item.gate.text);
          if (speed == null ||
              !speed.isFinite ||
              speed < 0 ||
              gate == null ||
              !gate.isFinite ||
              gate < 0 ||
              gate > 1) {
            throw StateError('请填写有效初速度与 0–1 舵机刻度。');
          }
          final preserve = !item.edited && item.matchesSaved;
          item.saved = await terminal.backend.request(
            terminal.execution.saveParameters(
              widget.plan.residentId,
              item.prescription.id,
              api.MedicationParameters(
                expectedRevision: previous?.revision ?? 0,
                medicineId: item.prescription.medicineId,
                turntable: preserve ? previous!.turntable : speed,
                gate: preserve ? previous!.gate : gate,
                simulationOnly: simulator,
                learningEnabled: item.learningEnabled,
                hasValues: item.edited || (preserve && previous!.hasValues),
              ),
            ),
          );
        }
      }
    });
    if (terminal.error != null || !mounted) return;
    await terminal.claim(widget.plan);
    if (mounted && terminal.task != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: terminal,
    builder: (context, _) => PreparationConfirmation(
      children: [
        const Text(
          '准备药盒',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        ResidentIdentity(
          asset: widget.residentAvatar,
          name: widget.plan.residentName,
          bed: widget.plan.bed,
          size: 44,
          nameSize: 16,
        ),
        const SizedBox(height: 10),
        Text(
          terminal.device?.configuration.name ?? '尚未选定设备',
          style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
        ),
        if (simulator) const Text('模拟演练：参数和结果不会用于真实摆药覆盖。'),
        if (!terminal.connected)
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => TerminalDeviceDialog(terminal: terminal),
            ),
            child: const Text('先连接设备'),
          ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (loadError != null) Text(loadError!),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('请核对长者信息，开仓后放入对应药盒。识别成功后再确认开始摆药。'),
                const SizedBox(height: 16),
                Text(
                  (barcode?.isNotEmpty == true || labels.isNotEmpty)
                      ? '已设置药盒识别'
                      : '尚未设置药盒识别，请先绑定标签。',
                ),
                const SizedBox(height: 16),
                ExpansionTile(
                  title: const Text('药盒与出药设置'),
                  children: [
                    if (barcode?.isNotEmpty == true) Text('长者条码：$barcode'),
                    if (terminal.canMaintain) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: uid,
                        decoration: const InputDecoration(
                          labelText: '核对后绑定的新标签 UID',
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: terminal.observedUid == null
                                ? null
                                : () => setState(
                                    () => uid.text = terminal.observedUid!,
                                  ),
                            child: const Text('填入最近读取的标签'),
                          ),
                          OutlinedButton(
                            onPressed: terminal.busy ? null : bind,
                            child: const Text('绑定到当前长者'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Text(
                      '每种药的独立参数',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Text('无有效历史时使用初速度 0.2、舵机 0.7。学习仅在正常批次结束后更新。'),
                    for (final item in medicines)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                '${item.prescription.data.medicineName} · ${item.prescription.data.strength}',
                              ),
                              const SizedBox(height: 12),
                              Material(
                                type: MaterialType.transparency,
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('自动学习'),
                                  subtitle: const Text('关闭后使用默认组；已有参数历史保留。'),
                                  value: item.learningEnabled,
                                  onChanged:
                                      terminal.canMaintain && !terminal.busy
                                      ? (value) => setState(() {
                                          item.learningEnabled = value;
                                          item.showSelection();
                                        })
                                      : null,
                                ),
                              ),
                              TextField(
                                controller: item.turntable,
                                enabled:
                                    terminal.canMaintain &&
                                    !terminal.busy &&
                                    item.learningEnabled,
                                onChanged: (_) => item.edited = true,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '转盘初速度',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: item.gate,
                                enabled:
                                    terminal.canMaintain &&
                                    !terminal.busy &&
                                    item.learningEnabled,
                                onChanged: (_) => item.edited = true,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: '舵机刻度（0–1，数值越小开口越大）',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (terminal.error != null)
          Text(
            terminal.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          alignment: WrapAlignment.end,
          children: [
            TextButton(
              onPressed: terminal.busy ? null : () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed:
                  loading ||
                      loadError != null ||
                      terminal.busy ||
                      !terminal.connected ||
                      terminal.active
                  ? null
                  : claim,
              child: Text(terminal.busy ? '正在准备…' : '开仓放入药盒'),
            ),
          ],
        ),
      ],
    ),
  );
}
