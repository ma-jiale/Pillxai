import 'package:flutter/material.dart';

import 'dispenser_icon.dart';

class DeviceConnectionButton extends StatelessWidget {
  const DeviceConnectionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: '我的设备 · 蓝牙 / USB 串口',
    child: OutlinedButton.icon(
      key: const ValueKey('device-status'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xff333333),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xffe5e5e5)),
      ),
      onPressed: onPressed,
      icon: const DispenserIcon(size: 22),
      label: Text(label),
    ),
  );
}
