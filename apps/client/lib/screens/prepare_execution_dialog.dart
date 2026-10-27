import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../theme/app_theme.dart';
import 'terminal_device_dialog.dart';

class PrepareExecutionDialog extends StatefulWidget {
  const PrepareExecutionDialog({
    super.key,
    required this.terminal,
    required this.plan,
  });
  final TerminalController terminal;
  final api.PlanSnapshot plan;
  @override
  State<PrepareExecutionDialog> createState() => _PrepareExecutionDialogState();
}

class _ParameterInput {
  _ParameterInput(this.prescription);
  final api.PrescriptionView prescription;
  api.ParameterView? saved;
  final turntable = TextEditingController();
  final gate = TextEditingController();
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
        if (saved?.medicineId == item.prescription.medicineId &&
            (simulator || saved?.simulationOnly == false)) {
          item.turntable.text = saved!.turntable.toString();
          item.gate.text = saved.gate.toString();
        }
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
      if (labels.isEmpty) throw StateError('请先核对并绑定这位长者的药盒标签。');
      if (terminal.canMaintain) {
        for (final item in medicines) {
          final speed = double.tryParse(item.turntable.text);
          final gate = double.tryParse(item.gate.text);
          if (speed == null ||
              !speed.isFinite ||
              speed < 0 ||
              gate == null ||
              !gate.isFinite ||
              gate < 0 ||
              gate > 1) {
            throw StateError('请填写每种药现场确认的转盘参数与 0–1 舵机刻度。');
          }
          final previous = item.saved;
          if (previous?.medicineId == item.prescription.medicineId &&
              previous?.turntable == speed &&
              previous?.gate == gate &&
              previous?.simulationOnly == simulator) {
            continue;
          }
          item.saved = await terminal.backend.request(
            terminal.execution.saveParameters(
              widget.plan.residentId,
              item.prescription.id,
              api.MedicationParameters(
                expectedRevision: previous?.revision ?? 0,
                medicineId: item.prescription.medicineId,
                turntable: speed,
                gate: gate,
                simulationOnly: simulator,
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
    builder: (context, _) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('上机准备', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 10),
              Text(
                '${widget.plan.residentName} · ${terminal.device?.configuration.name ?? '尚未选定设备'}',
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
                      const Text(
                        '药盒标签',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        labels.isEmpty
                            ? '尚未绑定标签'
                            : '已绑定：${labels.map((v) => v.uid).join('、')}',
                      ),
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
                      if (simulator && terminal.canMaintain)
                        TextButton(
                          onPressed: () => setState(() {
                            for (final item in medicines) {
                              item.turntable.text = '1';
                              item.gate.text = '0.5';
                            }
                          }),
                          child: const Text('填写模拟参数'),
                        ),
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
                                TextField(
                                  controller: item.turntable,
                                  enabled:
                                      terminal.canMaintain && !terminal.busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: '转盘参数（现场确认值）',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: item.gate,
                                  enabled:
                                      terminal.canMaintain && !terminal.busy,
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
                    onPressed: terminal.busy
                        ? null
                        : () => Navigator.pop(context),
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
                    child: Text(terminal.busy ? '正在准备…' : '领取并开仓'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
