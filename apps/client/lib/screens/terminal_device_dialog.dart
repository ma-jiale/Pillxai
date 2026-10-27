import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';

class TerminalDeviceDialog extends StatefulWidget {
  const TerminalDeviceDialog({super.key, required this.terminal});
  final TerminalController terminal;
  @override
  State<TerminalDeviceDialog> createState() => _TerminalDeviceDialogState();
}

class _TerminalDeviceDialogState extends State<TerminalDeviceDialog> {
  late final terminal = widget.terminal;
  final name = TextEditingController();
  final identity = TextEditingController();
  final port = TextEditingController();
  final rows = TextEditingController(text: '2,1,0,3');
  final present = TextEditingController();
  final absent = TextEditingController();
  final ready = TextEditingController();
  final simulatorUid = TextEditingController(text: 'A1B2C3D4');
  api.DeviceView? selected;
  api.DeviceMode mode = api.DeviceMode.simulator;
  bool positions = false;
  bool feedback = false;
  bool reverse = false;

  @override
  void initState() {
    super.initState();
    if (terminal.device != null) {
      load(terminal.device!);
    } else {
      name.text = '模拟机';
      identity.text = 'simulator-${terminal.terminalId}';
    }
    port.text = terminal.connection['port'] as String? ?? '';
    simulatorUid.text = terminal.connection['uid'] as String? ?? 'A1B2C3D4';
  }

  void load(api.DeviceView device) {
    port.text = device.id == terminal.connection['device_id']
        ? terminal.connection['port'] as String? ?? ''
        : '';
    selected = device;
    final c = device.configuration;
    name.text = c.name;
    identity.text = c.identity;
    mode = c.mode;
    rows.text = c.rows.join(',');
    positions = c.positionsVerified;
    feedback = c.feedbackVerified;
    reverse = c.reverseColumns;
    present.text = c.trayPresentLine;
    absent.text = c.trayAbsentLine;
    ready.text = c.readyLine;
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      identity,
      port,
      rows,
      present,
      absent,
      ready,
      simulatorUid,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget input(
    String label,
    TextEditingController controller, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: hint,
        helperMaxLines: 3,
      ),
    ),
  );

  Future<void> save() async {
    await terminal.run(() async {
      final mapping = rows.text
          .split(',')
          .map((v) => int.parse(v.trim()))
          .toList();
      if (mapping.length != 4 ||
          mapping.toSet().length != 4 ||
          mapping.any((v) => v < 0 || v > 3)) {
        throw const FormatException('时段映射须为 0、1、2、3 的不重复排列。');
      }
      if (mode == api.DeviceMode.hardware &&
          !(terminal.isAndroid
                  ? RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')
                  : RegExp(r'^COM[1-9][0-9]*$'))
              .hasMatch(port.text.trim())) {
        throw FormatException(
          terminal.isAndroid ? '请选择已配对 HC-06 的蓝牙地址。' : '请选择已确认的出站 COM。',
        );
      }
      await terminal.saveDevice(
        api.DeviceConfiguration(
          name: name.text.trim(),
          identity: identity.text.trim(),
          terminalId: terminal.terminalId,
          mode: mode,
          rows: mapping,
          reverseColumns: reverse,
          positionsVerified: mode == api.DeviceMode.simulator || positions,
          feedbackVerified: mode == api.DeviceMode.simulator || feedback,
          trayPresentLine: mode == api.DeviceMode.simulator
              ? 'SIM:TRAY_PRESENT'
              : present.text.trim(),
          trayAbsentLine: mode == api.DeviceMode.simulator
              ? 'SIM:TRAY_ABSENT'
              : absent.text.trim(),
          readyLine: mode == api.DeviceMode.simulator
              ? 'SIM:READY'
              : ready.text.trim(),
        ),
        port: terminal.isAndroid
            ? port.text.trim().toUpperCase()
            : port.text.trim(),
        simulatorUid: simulatorUid.text.trim().toUpperCase(),
        existing: selected,
      );
      selected = terminal.device;
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: terminal,
    builder: (context, _) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('我的设备', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 16),
              if (!terminal.supported)
                const Text('请使用 Android 或 Windows 本机版连接 HC-06；网页可维护资料和预览计划。')
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (terminal.devices.isNotEmpty)
                          DropdownButtonFormField<String>(
                            key: ValueKey(selected?.id),
                            initialValue: selected?.id,
                            decoration: const InputDecoration(
                              labelText: '已登记设备',
                            ),
                            isExpanded: true,
                            items: terminal.devices
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d.id,
                                    child: Text(d.configuration.name),
                                  ),
                                )
                                .toList(),
                            onChanged: terminal.active
                                ? null
                                : (id) => setState(
                                    () => load(
                                      terminal.devices.firstWhere(
                                        (d) => d.id == id,
                                      ),
                                    ),
                                  ),
                          ),
                        const SizedBox(height: 16),
                        IgnorePointer(
                          ignoring:
                              terminal.active ||
                              !terminal.canMaintain ||
                              terminal.busy,
                          child: Column(
                            children: [
                              DropdownButtonFormField<api.DeviceMode>(
                                key: ValueKey(mode),
                                initialValue: mode,
                                decoration: const InputDecoration(
                                  labelText: '连接方式',
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: api.DeviceMode.simulator,
                                    child: Text('模拟机'),
                                  ),
                                  DropdownMenuItem(
                                    value: api.DeviceMode.hardware,
                                    child: Text(
                                      terminal.isAndroid
                                          ? 'Android 蓝牙 HC-06'
                                          : 'Windows 蓝牙／USB 串口',
                                    ),
                                  ),
                                ],
                                onChanged: (value) => setState(() {
                                  mode = value!;
                                  selected = null;
                                  positions = false;
                                  feedback = false;
                                  identity.text =
                                      mode == api.DeviceMode.simulator
                                      ? 'simulator-${terminal.terminalId}'
                                      : '';
                                  name.text = mode == api.DeviceMode.simulator
                                      ? '模拟机'
                                      : 'dispenser01';
                                }),
                              ),
                              const SizedBox(height: 16),
                              input('设备名称', name),
                              input(
                                '稳定设备身份',
                                identity,
                                hint: '实机填写已核对的蓝牙地址或设备序列标识。',
                              ),
                              if (mode == api.DeviceMode.hardware) ...[
                                if (terminal.isAndroid) ...[
                                  const Text('请先在系统蓝牙设置中配对 HC-06，再读取已配对设备。'),
                                  TextButton.icon(
                                    onPressed: terminal.busy
                                        ? null
                                        : terminal.requestBluetoothAccess,
                                    icon: const Icon(Icons.bluetooth_rounded),
                                    label: const Text('读取已配对设备'),
                                  ),
                                  if (terminal.ports.isNotEmpty)
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(terminal.ports.join(',')),
                                      decoration: const InputDecoration(
                                        labelText: '已配对设备',
                                      ),
                                      isExpanded: true,
                                      items: terminal.ports
                                          .map(
                                            (address) => DropdownMenuItem(
                                              value: address,
                                              child: Text(
                                                '${terminal.portNames[address] ?? '蓝牙设备'} · $address',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (address) {
                                        if (address == null) return;
                                        setState(() {
                                          port.text = address;
                                          identity.text = address;
                                          name.text =
                                              terminal.portNames[address] ??
                                              'dispenser01';
                                        });
                                      },
                                    ),
                                ],
                                input(
                                  terminal.isAndroid
                                      ? '已配对设备的蓝牙地址'
                                      : '已确认的出站 COM',
                                  port,
                                  hint:
                                      '当前候选：${terminal.ports.join('、')}。候选列表不代表身份已核实。',
                                ),
                                ExpansionTile(
                                  title: const Text('位置与反馈配置'),
                                  children: [
                                    input(
                                      '早、午、晚、睡前对应的协议行',
                                      rows,
                                      hint: '0–3，逗号分隔；须逐位置核对。',
                                    ),
                                    SwitchListTile(
                                      title: const Text('日期列反向'),
                                      value: reverse,
                                      onChanged: (v) =>
                                          setState(() => reverse = v),
                                    ),
                                    CheckboxListTile(
                                      title: const Text('已在现场核对上述位置映射'),
                                      value: positions,
                                      onChanged: (v) =>
                                          setState(() => positions = v!),
                                    ),
                                    input('在轨完整报文', present),
                                    input('离轨完整报文', absent),
                                    input('收仓就绪完整报文', ready),
                                    CheckboxListTile(
                                      title: const Text('以上三种反馈已实机确认'),
                                      value: feedback,
                                      onChanged: (v) =>
                                          setState(() => feedback = v!),
                                    ),
                                    const Text('未确认取盒反馈时，完成分药后会保留设备占用并等待现场核对。'),
                                  ],
                                ),
                              ] else
                                input('模拟标签 UID', simulatorUid),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton(
                              onPressed:
                                  terminal.active ||
                                      terminal.busy ||
                                      !terminal.canMaintain
                                  ? null
                                  : save,
                              child: const Text('保存连接'),
                            ),
                            FilledButton(
                              onPressed:
                                  terminal.busy ||
                                      terminal.connected ||
                                      terminal.connection.isEmpty
                                  ? null
                                  : () => terminal.action('connect'),
                              child: Text(terminal.active ? '尝试重连' : '连接'),
                            ),
                            OutlinedButton(
                              onPressed: terminal.busy || !terminal.connected
                                  ? null
                                  : () => terminal.action('disconnect'),
                              child: const Text('断开'),
                            ),
                            OutlinedButton(
                              onPressed:
                                  terminal.busy ||
                                      !terminal.connected ||
                                      terminal.active
                                  ? null
                                  : () => terminal.action('open_binding'),
                              child: const Text('开仓读取标签'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          terminal.connected
                              ? (terminal.isAndroid
                                    ? '已连接 · 蓝牙'
                                    : '已连接 · 115200 / 8N1')
                              : '未连接',
                        ),
                        Text('最近标签：${terminal.observedUid ?? '尚未收到'}'),
                        if (terminal.active) const Text('本机任务未结束，连接配置保持锁定。'),
                        ExpansionTile(
                          title: const Text('查看原始反馈'),
                          children: [
                            SelectableText(
                              (terminal.view['raw_lines'] as List? ?? []).join(
                                '\n',
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
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
