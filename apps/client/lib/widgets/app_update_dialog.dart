import 'package:flutter/material.dart';

import '../data/app_update_controller.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({super.key, required this.updates});
  final AppUpdateController updates;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: updates,
    builder: (context, _) {
      final release = updates.release;
      return AlertDialog(
        title: const Text('应用更新'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('当前版本 ${updates.version}'),
                const SizedBox(height: 12),
                Text(updates.message),
                if (release != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${release.versionName} · ${(release.sizeBytes / 1048576).toStringAsFixed(1)} MB',
                  ),
                  const SizedBox(height: 8),
                  Text(release.notes),
                ],
                if (updates.downloading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: updates.progress),
                ],
                if (updates.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    updates.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (updates.installing) ...[
            TextButton(
              onPressed: updates.busy ? null : updates.cancelInstall,
              child: const Text('取消安装'),
            ),
            if (updates.device['confirmation_ready'] == true)
              FilledButton(
                onPressed: updates.busy ? null : updates.confirm,
                child: const Text('继续系统安装'),
              ),
          ] else if (updates.ready)
            FilledButton(
              onPressed: updates.busy || !updates.idle
                  ? null
                  : updates.canInstall
                  ? updates.install
                  : updates.permission,
              child: Text(updates.canInstall ? '安装更新' : '允许安装更新'),
            )
          else if (release != null && !updates.downloading)
            FilledButton(
              onPressed: updates.busy ? null : updates.download,
              child: const Text('下载更新'),
            )
          else if (!updates.downloading)
            OutlinedButton(
              onPressed: updates.busy ? null : updates.check,
              child: const Text('重新检查'),
            ),
        ],
      );
    },
  );
}
