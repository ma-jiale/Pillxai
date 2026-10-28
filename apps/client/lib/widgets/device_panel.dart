import 'package:flutter/material.dart';

import 'dispenser_icon.dart';

/// Confirmed device panel layout, independent of discovery and connection state.
class DevicePanel extends StatelessWidget {
  const DevicePanel({
    super.key,
    required this.body,
    required this.footer,
    this.onBack,
    this.title = '我的设备',
    this.subtitle,
    this.notice,
    this.note,
  });
  final Widget body;
  final Widget footer;
  final VoidCallback? onBack;
  final String? title;
  final String? subtitle;
  final Widget? notice;
  final Widget? note;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Dialog(
      insetPadding: EdgeInsets.all(compact ? 12 : 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 820),
        child: Padding(
          padding: EdgeInsets.all(compact ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      tooltip: '返回我的设备',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    ),
                  const Spacer(),
                  IconButton(
                    tooltip: '关闭我的设备',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              if (title != null) ...[
                Text(
                  title!,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Color(0xff777777),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
              Expanded(child: body),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: notice,
                ),
              const SizedBox(height: 12),
              Center(child: footer),
              if (note != null) ...[const SizedBox(height: 12), note!],
            ],
          ),
        ),
      ),
    );
  }
}

class DevicePanelRow extends StatelessWidget {
  const DevicePanelRow({
    super.key,
    required this.name,
    required this.status,
    required this.actions,
  });
  final String name;
  final String status;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xffeeeeee))),
    ),
    child: Row(
      children: [
        const DispenserIcon(size: 38),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                status,
                style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
              ),
            ],
          ),
        ),
        ...actions,
      ],
    ),
  );
}

class DeviceSearchHeading extends StatelessWidget {
  const DeviceSearchHeading({
    super.key,
    required this.instructions,
    required this.status,
  });
  final String instructions;
  final String status;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 24),
      Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xfff5f5f5),
          border: Border.all(color: const Color(0xffe9e9e9)),
        ),
        child: const Center(child: DispenserIcon(size: 48)),
      ),
      const SizedBox(height: 28),
      const Text(
        '确保摆药机已开机',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Text(
        instructions,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xff777777),
          height: 1.6,
        ),
      ),
      const SizedBox(height: 20),
      Semantics(
        liveRegion: true,
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
        ),
      ),
      const SizedBox(height: 24),
    ],
  );
}
