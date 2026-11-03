import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/terminal_controller.dart';
import 'device_mapping_dialog.dart';
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
  final simulatorUid = TextEditingController(text: 'A1B2C3D4');
  api.DeviceView? selected;
  api.DeviceMode mode = api.DeviceMode.hardware;
  String _page = 'list';

  void load(api.DeviceView device) {
    port.text = device.id == terminal.connection['device_id']
        ? terminal.connection['port'] as String? ?? ''
        : (terminal.connection['device_ports'] as Map?)?[device.id]
                  as String? ??
              '';
    selected = device;
    final c = device.configuration;
    name.text = c.name;
    identity.text = c.identity;
    mode = c.mode;
    simulatorUid.text = device.id == terminal.connection['device_id']
        ? terminal.connection['uid'] as String? ?? 'A1B2C3D4'
        : 'A1B2C3D4';
  }

  @override
  void dispose() {
    for (final controller in [name, identity, port, simulatorUid]) {
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
      if (mode == api.DeviceMode.hardware &&
          !(terminal.isAndroid
                  ? RegExp(r'^(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$')
                  : RegExp(r'^COM[1-9][0-9]*$'))
              .hasMatch(port.text.trim())) {
        throw FormatException(
          terminal.isAndroid ? '请选择已配对的蓝牙设备。' : '请在连接设置中确认设备端口。',
        );
      }
      if (identity.text.trim().isEmpty) {
        throw const FormatException('请在连接设置中填写设备标识。');
      }
      final existing =
          selected ?? terminal.registeredDevice(identity.text.trim());
      final config =
          existing?.configuration.copyWith(
            name: name.text.trim(),
            terminalId: terminal.terminalId,
          ) ??
          api.DeviceConfiguration(
            name: name.text.trim(),
            identity: identity.text.trim(),
            terminalId: terminal.terminalId,
            mode: api.DeviceMode.hardware,
            barcodeRemovalCloses: true,
            rows: [2, 1, 0, 3],
          );
      await terminal.saveDevice(
        config,
        port: terminal.isAndroid
            ? port.text.trim().toUpperCase()
            : port.text.trim(),
        simulatorUid: simulatorUid.text.trim().toUpperCase(),
        existing: existing,
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
      }
      mode = api.DeviceMode.hardware;
      port.text = address;
      identity.text =
          known?.configuration.identity ?? (terminal.isAndroid ? address : '');
      name.text =
          known?.configuration.name ?? terminal.portNames[address] ?? '摆药机';
      _page = 'configure';
    });
  }

  String? _transportLabel(String? type) => switch (type) {
    'usb' => 'USB连接',
    'bluetooth' => '蓝牙',
    _ => null,
  };

  String _deviceStatus(api.DeviceView device) {
    final current = terminal.device?.id == device.id;
    final status = current && terminal.connected ? '已连接' : '未连接';
    if (device.configuration.mode == api.DeviceMode.simulator) return status;
    final connection = terminal.connection;
    final type = current ? terminal.portTransports[connection['port']] : null;
    final saved = connection['device_transports'] as Map?;
    final label = terminal.isAndroid
        ? '蓝牙'
        : _transportLabel(type ?? saved?[device.id]);
    return label == null ? status : '$status · $label';
  }

  Widget _list() {
    final devices = terminal.localDevices;
    if (terminal.device != null &&
        !devices.any((d) => d.id == terminal.device!.id)) {
      devices.add(terminal.device!);
    }
    return ListView(
      children: [
        if (!terminal.supported) const Text('请使用 Android 或 Windows 客户端连接摆药机。'),
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
            status: _deviceStatus(device),
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
            status: candidate['paired'] == true ? '蓝牙' : '未配对 · 蓝牙',
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
                            terminal.localDevices.any(
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
        for (final (index, address) in terminal.ports.indexed)
          DevicePanelRow(
            name: terminal.portNames[address] ?? '待确认设备 ${index + 1}',
            status: _transportLabel(terminal.portTransports[address]) ?? '待确认',
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
        ExpansionTile(
          initiallyExpanded: true,
          title: const Text('设备信息'),
          children: [
            IgnorePointer(
              ignoring:
                  terminal.active || !terminal.canMaintain || terminal.busy,
              child: Column(
                children: [
                  Text(
                    mode == api.DeviceMode.simulator
                        ? '模拟机'
                        : terminal.isAndroid
                        ? '蓝牙'
                        : '摆药机',
                  ),
                  const SizedBox(height: 16),
                  input('设备名称', name),
                  if (mode == api.DeviceMode.hardware) ...[
                    if (terminal.isAndroid) ...[
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
                                terminal.portNames[address] ?? '蓝牙设备',
                              ),
                          ],
                          onChanged: (address) {
                            if (address.isNotEmpty) _choosePort(address);
                          },
                        ),
                    ],
                    ExpansionTile(
                      title: const Text('连接设置'),
                      children: [
                        if (!terminal.isAndroid && selected == null)
                          input('设备标识', identity, hint: '填写已核对的设备序列标识。'),
                        if (!terminal.isAndroid && selected != null)
                          AppSelect<String>(
                            value: terminal.ports.contains(port.text)
                                ? port.text
                                : '',
                            label: '设备端口',
                            showLabel: true,
                            options: [
                              const AppSelectOption('', '选择已发现的端口'),
                              for (final address in terminal.ports)
                                AppSelectOption(
                                  address,
                                  terminal.portNames[address] ?? address,
                                ),
                            ],
                            onChanged: (address) =>
                                setState(() => port.text = address),
                          ),
                        if (selected != null &&
                            selected?.id == terminal.device?.id)
                          TextButton(
                            onPressed: () async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) =>
                                    DeviceMappingDialog(terminal: terminal),
                              );
                              if (mounted && terminal.device != null) {
                                setState(() => load(terminal.device!));
                              }
                            },
                            child: const Text('校准设备行列'),
                          ),
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
        Text(terminal.device == null ? '未连接' : _deviceStatus(terminal.device!)),

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
