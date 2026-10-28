import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CollectionBanner extends StatelessWidget {
  const CollectionBanner({
    super.key,
    required this.title,
    required this.message,
    required this.action,
  });
  final String title;
  final String message;
  final Widget action;
  @override
  Widget build(BuildContext context) => Surface(
    key: const ValueKey('collection-status'),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(fontSize: 12, color: Color(0xff777777)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        action,
      ],
    ),
  );
}
