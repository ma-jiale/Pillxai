import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import '../widgets/dispenser_icon.dart';
import '../widgets/device_panel.dart';
import '../widgets/app_menu.dart';

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
  api.DeviceMode mode = api.DeviceMode.hardware;
  bool positions = false;
  bool feedback = false;
  bool reverse = false;
  String _page = 'list';

  @override
  void initState() {
    super.initState();
    if (terminal.device != null) {
      load(terminal.device!);
    } else {
      name.text = '摆药机';
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

  Future<bool> save() async {
    if (terminal.active || terminal.busy || !terminal.canMaintain) return false;
    var saved = false;
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
          barcodeRemovalCloses:
              selected?.configuration.identity == identity.text.trim() &&
              selected?.configuration.barcodeRemovalCloses == true,
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
        existing: selected?.configuration.identity == identity.text.trim()
            ? selected
            : null,
      );
      selected = terminal.device;
      saved = true;
    });
    return saved;
  }

  Future<void> connect() async {
    if (selected?.id != terminal.device?.id &&
        (terminal.active || !terminal.canMaintain)) {
      return;
    }
    if (!terminal.active && terminal.canMaintain && !await save()) return;
    await terminal.action('connect');
  }

  void _configure(api.DeviceView device) {
    setState(() {
      load(device);
      if (terminal.isAndroid && port.text.isEmpty) {
        port.text = device.configuration.identity;
      }
      _page = 'configure';
    });
  }

  Future<void> _search() async {
    setState(() => _page = 'search');
    if (terminal.isAndroid) {
      await terminal.discoverDevices();
    } else {
      await terminal.run(terminal.refreshDevices);
    }
  }

  void _choosePort(String address) {
    if (terminal.active || !terminal.canMaintain || terminal.busy) return;
    setState(() {
      final known = terminal.devices
          .where((d) => d.configuration.identity == address)
          .firstOrNull;
      if (known != null) {
        load(known);
      } else {
        selected = null;
        positions = false;
        feedback = false;
        reverse = false;
        rows.text = '2,1,0,3';
        present.clear();
        absent.clear();
        ready.clear();
      }
      mode = api.DeviceMode.hardware;
      port.text = address;
      identity.text = address;
      name.text =
          known?.configuration.name ?? terminal.portNames[address] ?? '摆药机';
      _page = 'configure';
    });
  }

  Widget _list() {
    final devices = [...terminal.devices];
    if (terminal.device != null &&
        !devices.any((d) => d.id == terminal.device!.id)) {
      devices.add(terminal.device!);
    }
    return ListView(
      children: [
        if (!terminal.supported)
          const Text('请使用 Android 或 Windows 本机版连接 HC-06；网页可维护资料和预览计划。'),
        if (devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Column(
              children: [
                DispenserIcon(size: 64, color: Color(0xffaaaaaa)),
                SizedBox(height: 20),
                Text(
                  '还没有添加设备',
                  style: TextStyle(color: Color(0xff777777), fontSize: 14),
                ),
              ],
            ),
          ),
        for (final device in devices)
          DevicePanelRow(
            name: device.configuration.name,
            status: terminal.device?.id == device.id && terminal.connected
                ? '已连接'
                : '未连接',
            actions: [
              TextButton(
                key: ValueKey('device-connect-${device.id}'),
                onPressed:
                    terminal.busy ||
                        !terminal.supported ||
                        (!terminal.canMaintain &&
                            terminal.device?.id != device.id) ||
                        (terminal.active &&
                            (terminal.device?.id != device.id ||
                                terminal.connected))
                    ? null
                    : () async {
                        if (terminal.device?.id == device.id) {
                          await terminal.action(
                            terminal.connected ? 'disconnect' : 'connect',
                          );
                        } else if (terminal.isAndroid &&
                            device.configuration.mode ==
                                api.DeviceMode.hardware) {
                          await terminal.addBluetoothDevice(
                            device.configuration.identity,
                            device.configuration.name,
                          );
                        } else {
                          _configure(device);
                        }
                      },
                child: Text(
                  terminal.device?.id == device.id
                      ? (terminal.connected
                            ? '断开'
                            : terminal.active
                            ? '尝试重连'
                            : '连接')
                      : '选用',
                ),
              ),
              IconButton(
                tooltip: '配置设备',
                onPressed: () => _configure(device),
                icon: const Icon(Icons.tune_rounded, size: 18),
              ),
            ],
          ),
        if (terminal.active)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('本机任务未结束，连接配置保持锁定。'),
          ),
      ],
    );
  }

  Widget _searchBody() => ListView(
    children: [
      DeviceSearchHeading(
        instructions: terminal.isAndroid
            ? '请打开摆药机电源并靠近平板，选择设备即可添加。'
            : '蓝牙设备请靠近终端；USB 设备请插入数据线。',
        status: terminal.busy
            ? terminal.deviceSetupStatus ?? '正在搜索摆药机…'
            : (terminal.isAndroid
                  ? terminal.nearbyDevices.isEmpty
                  : terminal.ports.isEmpty)
            ? '未找到可用设备'
            : '选择要添加的摆药机',
      ),
      if (terminal.busy) const LinearProgressIndicator(minHeight: 2),
      if (terminal.isAndroid)
        for (final candidate in terminal.nearbyDevices)
          DevicePanelRow(
            name: candidate['name'] as String,
            status: candidate['paired'] == true ? '可添加' : '未配对',
            actions: [
              TextButton(
                onPressed:
                    terminal.busy || terminal.active || !terminal.canMaintain
                    ? null
                    : () async {
                        await terminal.addBluetoothDevice(
                          candidate['address'] as String,
                          candidate['name'] as String,
                        );
                        if (mounted &&
                            terminal.devices.any(
                              (d) =>
                                  d.configuration.identity ==
                                  candidate['address'],
                            )) {
                          setState(() => _page = 'list');
                        }
                      },
                child: const Text('添加'),
              ),
            ],
          ),
      if (!terminal.isAndroid)
        for (final address in terminal.ports)
          DevicePanelRow(
            name: terminal.portNames[address] ?? address,
            status: address,
            actions: [
              TextButton(
                onPressed:
                    terminal.busy || terminal.active || !terminal.canMaintain
                    ? null
                    : () => _choosePort(address),
                child: const Text('添加'),
              ),
            ],
          ),
      if (terminal.canMaintain)
        TextButton(
          onPressed: terminal.active || terminal.busy
              ? null
              : () => setState(() => _page = 'configure'),
          child: const Text('手动配置'),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: terminal,
    builder: (context, _) => DevicePanel(
      title: _page == 'list'
          ? '我的设备'
          : _page == 'configure'
          ? '设备配置'
          : null,
      subtitle: null,
      onBack: _page == 'list' || terminal.busy
          ? null
          : () => setState(() => _page = 'list'),
      body: _page == 'list'
          ? _list()
          : _page == 'search'
          ? _searchBody()
          : _configuration(),
      notice: terminal.error == null
          ? null
          : Text(
              terminal.error!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
      footer: _page == 'list'
          ? OutlinedButton.icon(
              key: const ValueKey('add-device'),
              onPressed:
                  terminal.active ||
                      terminal.busy ||
                      !terminal.canMaintain ||
                      !terminal.supported
                  ? null
                  : _search,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('添加新设备'),
            )
          : _page == 'search'
          ? TextButton.icon(
              onPressed: terminal.busy ? null : _search,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新搜索'),
            )
          : TextButton(
              onPressed: () => setState(() => _page = 'list'),
              child: const Text('完成'),
            ),
    ),
  );

  Widget _configuration() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (terminal.devices.isNotEmpty)
          AppSelect<String>(
            value: selected?.id ?? '',
            label: '已登记设备',
            showLabel: true,
            enabled: !terminal.active && !terminal.busy && terminal.canMaintain,
            options: [
              const AppSelectOption('', '新设备'),
              for (final d in terminal.devices)
                AppSelectOption(d.id, d.configuration.name),
            ],
            onChanged: (id) {
              if (id.isNotEmpty) {
                _configure(terminal.devices.firstWhere((d) => d.id == id));
              }
            },
          ),
        const SizedBox(height: 16),
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('添加或配置设备'),
          children: [
            IgnorePointer(
              ignoring:
                  terminal.active || !terminal.canMaintain || terminal.busy,
              child: Column(
                children: [
                  AppSelect<api.DeviceMode>(
                    value: mode,
                    label: '连接方式',
                    showLabel: true,
                    enabled:
                        !terminal.active &&
                        !terminal.busy &&
                        terminal.canMaintain,
                    options: [
                      const AppSelectOption(api.DeviceMode.simulator, '模拟机'),
                      AppSelectOption(
                        api.DeviceMode.hardware,
                        terminal.isAndroid
                            ? 'Android 蓝牙 HC-06'
                            : 'Windows 蓝牙／USB 串口',
                      ),
                    ],
                    onChanged: (value) => setState(() {
                      mode = value;
                      selected = null;
                      positions = false;
                      feedback = false;
                      present.clear();
                      absent.clear();
                      ready.clear();
                      identity.text = value == api.DeviceMode.simulator
                          ? 'simulator-${terminal.terminalId}'
                          : '';
                      name.text = value == api.DeviceMode.simulator
                          ? '模拟机'
                          : '摆药机';
                    }),
                  ),
                  const SizedBox(height: 16),
                  input('设备名称', name),
                  input('稳定设备身份', identity, hint: '实机填写已核对的蓝牙地址或设备序列标识。'),
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
                        AppSelect<String>(
                          key: const ValueKey('paired-devices'),
                          value: terminal.ports.contains(port.text)
                              ? port.text
                              : '',
                          label: '已配对设备',
                          showLabel: true,
                          enabled:
                              !terminal.active &&
                              !terminal.busy &&
                              terminal.canMaintain,
                          options: [
                            const AppSelectOption('', '选择已配对设备'),
                            for (final address in terminal.ports)
                              AppSelectOption(
                                address,
                                '${terminal.portNames[address] ?? '蓝牙设备'} · $address',
                              ),
                          ],
                          onChanged: (address) {
                            if (address.isNotEmpty) _choosePort(address);
                          },
                        ),
                    ],
                    input(
                      terminal.isAndroid ? '已配对设备的蓝牙地址' : '已确认的出站 COM',
                      port,
                      hint: '当前候选：${terminal.ports.join('、')}。候选列表不代表身份已核实。',
                    ),
                    ExpansionTile(
                      title: const Text('取盒反馈配置'),
                      children: [
                        const Text('实体位置映射请在“设置 → 药盒布局”中调整。'),
                        input('在轨完整报文', present),
                        input('离轨完整报文', absent),
                        input('收仓就绪完整报文', ready),
                        CheckboxListTile(
                          title: const Text('以上三种反馈已实机确认'),
                          value: feedback,
                          onChanged: (v) => setState(() => feedback = v!),
                        ),
                        const Text('未确认取盒反馈时，完成分药后会保留设备占用并等待现场核对。'),
                      ],
                    ),
                  ] else
                    input('模拟标签 UID', simulatorUid),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed:
                  terminal.active || terminal.busy || !terminal.canMaintain
                  ? null
                  : save,
              child: const Text('保存连接'),
            ),
            FilledButton(
              onPressed:
                  terminal.busy ||
                      terminal.connected ||
                      (terminal.connection.isEmpty && !terminal.canMaintain)
                  ? null
                  : connect,
              child: Text(
                terminal.active
                    ? '尝试重连'
                    : terminal.canMaintain
                    ? '保存并连接'
                    : '连接',
              ),
            ),
            OutlinedButton(
              onPressed: terminal.busy || terminal.active || !terminal.connected
                  ? null
                  : () => terminal.action('disconnect'),
              child: const Text('断开'),
            ),
            OutlinedButton(
              onPressed: terminal.busy || !terminal.connected || terminal.active
                  ? null
                  : () => terminal.action('open_binding'),
              child: const Text('开仓读取标签'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          terminal.connected
              ? (terminal.isAndroid ? '已连接 · 蓝牙' : '已连接 · 115200 / 8N1')
              : '未连接',
        ),

        if (terminal.active) const Text('本机任务未结束，连接配置保持锁定。'),
        ExpansionTile(
          title: const Text('设备诊断'),
          children: [
            Text('最近标签：${terminal.observedUid ?? '尚未收到'}'),
            SelectableText(
              (terminal.view['raw_lines'] as List? ?? []).join('\n'),
            ),
          ],
        ),
      ],
    ),
  );
}
