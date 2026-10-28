import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'profile_avatar.dart';

class ResultDetailsSheet extends StatelessWidget {
  const ResultDetailsSheet({super.key, required this.body, this.footer});
  final Widget body;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Dialog(
    alignment: Alignment.centerRight,
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '结果详情',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '关闭结果详情',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: body,
            ),
          ),
          if (footer != null)
            Padding(padding: const EdgeInsets.all(20), child: footer),
        ],
      ),
    ),
  );
}

class HistoryRecordCard extends StatelessWidget {
  const HistoryRecordCard({
    super.key,
    required this.name,
    required this.bed,
    this.avatar,
    required this.badges,
    required this.facts,
    required this.caption,
    required this.onTap,
  });
  final String name;
  final String bed;
  final String? avatar;
  final List<Widget> badges;
  final List<String> facts;
  final String caption;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Surface(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final identity = ResidentIdentity(
            name: name,
            bed: bed,
            asset: avatar,
          );
          final result = Wrap(spacing: 8, runSpacing: 6, children: badges);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bounds.maxWidth < 560) ...[
                identity,
                const SizedBox(height: 12),
                result,
              ] else
                Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 16),
                    result,
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, color: Color(0xff999999)),
                  ],
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 20,
                runSpacing: 6,
                children: [for (final fact in facts) Text(fact)],
              ),
              const SizedBox(height: 8),
              Text(
                caption,
                style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class ResultBadge extends StatelessWidget {
  const ResultBadge(this.label, {super.key, this.attention = false});
  final String label;
  final bool attention;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: attention ? const Color(0xfffaf0df) : const Color(0xfff2f2f2),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        color: attention ? const Color(0xff8a5a1f) : const Color(0xff555555),
      ),
    ),
  );
}
