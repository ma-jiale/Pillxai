import 'package:flutter/material.dart';

/// The approved workspace geometry is shared by live and fixture data.
class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    this.actions = const [],
  });
  final Widget title;
  final List<Widget> actions;

  Widget _slot(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 56),
    child: Align(
      alignment: Alignment.centerLeft,
      heightFactor: 1,
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('workspace-header'),
    color: Theme.of(context).scaffoldBackgroundColor,
    constraints: const BoxConstraints(minHeight: 88),
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 900 ? 20 : 32,
      vertical: 16,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _slot(title)),
        for (final action in actions) _slot(action),
      ],
    ),
  );
}
