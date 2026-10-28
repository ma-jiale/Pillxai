import 'dart:async';

import 'package:flutter/material.dart';

import '../models/demo_model.dart';
import '../models/device_preview_model.dart';
import '../widgets/dispenser_icon.dart';
import '../widgets/device_panel.dart';
import '../widgets/device_connection_button.dart';

const _muted = Color(0xff777777);
const _previewNote = '界面预览 · 示例设备，未连接真实硬件';

/// 顶栏连接状态的监听入口，点击只打开设备面板，不授予摆药启动许可。
class DeviceStatusButton extends StatelessWidget {
  const DeviceStatusButton({
    super.key,
    required this.devices,
    required this.onPressed,
  });
  final DevicePreviewModel devices;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: devices,
    builder: (context, _) => DeviceConnectionButton(
      onPressed: onPressed,
      label: devices.connectingDevice != null
          ? '连接中'
          : devices.connectedDevice == null
          ? '未连接'
          : '已连接',
    ),
  );
}

/// 面板拥有搜索动画；连接进度归 DevicePreviewModel，关面板后仍可完成连接。
class DevicesPage extends StatefulWidget {
  const DevicesPage({
    super.key,
    required this.devices,
    required this.taskModel,
  });
  final DevicePreviewModel devices;
  final DemoModel taskModel;
  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  bool _adding = false;
  bool _searching = false;
  Timer? _timer;
  String? _notice;
  // UI fixtures only. Names are not production device identities.
  static const _nearby = [
    'PillDispenser01',
    'PillDispenser02',
    'PillDispenser03',
    'USB 串口设备',
  ];
  String _transport(String name) => name.startsWith('USB') ? 'USB 串口' : '蓝牙串口';

  /// 取消上次搜索计时，再模拟一次搜索；回调前检查 mounted，避免销毁后 setState。
  void _scan() {
    _timer?.cancel();
    setState(() {
      _adding = true;
      _searching = true;
      _notice = null;
    });
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _searching = false);
    });
  }

  void _back() {
    _timer?.cancel();
    setState(() {
      _adding = false;
      _searching = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 所有会改变连接的UI操作先检查任务占用；弹窗返回后也必须经过这道检查。
  void _change(VoidCallback action) {
    if (widget.taskModel.busy) {
      setState(
        () => _notice = widget.taskModel.awaitingCollection
            ? '请先完成取盒，再更改设备连接。'
            : '请先完成或结束当前摆药，再更改设备连接。',
      );
      return;
    }
    setState(() => _notice = null);
    action();
  }

  Future<void> _remove(String name) async {
    if (widget.taskModel.busy) {
      _change(() {});
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除设备？'),
        content: Text('从我的设备中移除 $name，之后可重新添加。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (result == true && mounted) _change(() => widget.devices.remove(name));
  }

  @override
  Widget build(BuildContext context) => DevicePanel(
    title: _adding ? null : '我的设备',
    subtitle: _adding ? null : '请打开摆药机电源，通过蓝牙或 USB 连接。',
    onBack: _adding ? _back : null,
    body: _adding ? _searchBody() : _deviceList(),
    notice: _notice == null
        ? null
        : Text(
            _notice!,
            style: const TextStyle(fontSize: 12, color: Color(0xffa62929)),
          ),
    footer: _adding
        ? TextButton.icon(
            key: const ValueKey('rescan-devices'),
            onPressed: _searching ? null : _scan,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重新搜索'),
          )
        : OutlinedButton.icon(
            key: const ValueKey('add-device'),
            onPressed: _scan,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('添加新设备'),
          ),
    note: const Text(
      _previewNote,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: _muted),
    ),
  );
  Widget _deviceList() => ListenableBuilder(
    listenable: widget.devices,
    builder: (context, _) => widget.devices.devices.isEmpty
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DispenserIcon(size: 64, color: Color(0xffaaaaaa)),
                SizedBox(height: 20),
                Text('还没有添加设备', style: TextStyle(color: _muted, fontSize: 14)),
              ],
            ),
          )
        : ListView(
            children: [
              for (final name in widget.devices.devices) _row(name, false),
            ],
          ),
  );
  Widget _searchBody() => ListView(
    children: [
      DeviceSearchHeading(
        instructions: '蓝牙设备请靠近终端；USB 设备请插入数据线。',
        status: _searching ? '正在查找可用设备…' : '选择要添加的摆药机',
      ),
      if (_searching)
        const Center(
          child: SizedBox(
            width: 120,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        )
      else
        for (final name in _nearby) _row(name, true),
    ],
  );
  Widget _row(String name, bool discovery) {
    final connected = widget.devices.connectedDevice == name;
    final added = widget.devices.devices.contains(name);
    final connecting = widget.devices.connectingDevice == name;
    final failed = widget.devices.failedDevice == name;
    return DevicePanelRow(
      name: name,
      status: discovery
          ? _transport(name)
          : '${connecting
                ? "正在连接…"
                : connected
                ? "已连接"
                : failed
                ? "连接失败，请重试"
                : "未连接"} · ${_transport(name)}',
      actions: [
        TextButton(
          key: ValueKey(
            discovery
                ? 'add-$name'
                : '${connected ? "disconnect" : "connect"}-$name',
          ),
          onPressed: discovery
              ? (added
                    ? null
                    : () => _change(() {
                        widget.devices.add(name);
                        _back();
                      }))
              : connecting
              ? null
              : () => _change(
                  () => connected
                      ? widget.devices.disconnect()
                      : widget.devices.connect(name),
                ),
          child: Text(
            discovery
                ? (added ? '已添加' : '添加')
                : connecting
                ? '连接中'
                : connected
                ? '断开'
                : failed
                ? '重试'
                : '连接',
          ),
        ),
        if (!discovery)
          IconButton(
            key: ValueKey('remove-$name'),
            tooltip: '移除设备',
            onPressed: () => _remove(name),
            icon: const Icon(Icons.close_rounded, size: 16, color: _muted),
          ),
      ],
    );
  }
}
