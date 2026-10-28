import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'profile_avatar.dart';

class PreparationListEntry {
  const PreparationListEntry({
    required this.name,
    required this.bed,
    required this.details,
    required this.action,
    this.avatar,
    this.hasIssue = false,
  });
  final String name;
  final String bed;
  final String? avatar;
  final String details;
  final Widget action;
  final bool hasIssue;
}

/// A short list keeps its natural height; long lists scroll inside the available area.
class PreparationList extends StatelessWidget {
  const PreparationList({super.key, required this.entries});
  final List<PreparationListEntry> entries;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: Surface(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: index < entries.length - 1
                  ? const Border(bottom: BorderSide(color: Color(0xffe8e8e8)))
                  : null,
            ),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final identity = ResidentIdentity(
                  name: entry.name,
                  bed: entry.bed,
                  asset: entry.avatar,
                );
                final details = Text(
                  entry.details,
                  style: TextStyle(
                    fontSize: 12,
                    color: entry.hasIssue
                        ? Theme.of(context).colorScheme.error
                        : const Color(0xff737373),
                  ),
                );
                if (bounds.maxWidth < 470) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      identity,
                      const SizedBox(height: 8),
                      details,
                      const SizedBox(height: 12),
                      entry.action,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: identity),
                    Expanded(child: details),
                    entry.action,
                  ],
                );
              },
            ),
          );
        },
      ),
    ),
  );
}
