import 'package:flutter/material.dart';

import 'dispenser_icon.dart';

class ConnectionActionLabel extends StatelessWidget {
  const ConnectionActionLabel(
    this.label, {
    super.key,
    required this.connecting,
  });
  final String label;
  final bool connecting;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Visibility(
        visible: !connecting,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: Text(label),
      ),
      if (connecting)
        const SizedBox.square(
          dimension: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: '正在连接',
          ),
        ),
    ],
  );
}

class DeviceConnectionButton extends StatelessWidget {
  const DeviceConnectionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.connecting = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool connecting;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: '我的设备',
    child: OutlinedButton.icon(
      key: const ValueKey('device-status'),
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xff333333),
        backgroundColor: Colors.white,
        side: const BorderSide(color: Color(0xffe5e5e5)),
      ),
      onPressed: onPressed,
      icon: connecting
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const DispenserIcon(size: 22),
      label: Text(connecting ? '连接中' : label),
    ),
  );
}
