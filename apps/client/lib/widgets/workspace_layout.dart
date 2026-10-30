import 'package:flutter/material.dart';

import 'workspace_sidebar.dart';

/// Navigation layout owns only its presentation; page and task state stay in the workspace.
class WorkspaceLayout extends StatefulWidget {
  const WorkspaceLayout({
    super.key,
    required this.selected,
    required this.narrow,
    required this.onSelect,
    required this.onSignOut,
    required this.child,
    this.displayName = '管理员',
    this.roleLabel = '管理员',
  });

  final int selected;
  final bool narrow;
  final ValueChanged<int> onSelect;
  final VoidCallback onSignOut;
  final Widget child;
  final String displayName;
  final String roleLabel;

  @override
  State<WorkspaceLayout> createState() => _WorkspaceLayoutState();
}

class _WorkspaceLayoutState extends State<WorkspaceLayout> {
  bool _collapsed = false;
  bool _narrowExpanded = false;

  void _toggle() => setState(() {
    if (widget.narrow) {
      _narrowExpanded = !_narrowExpanded;
    } else {
      _collapsed = !_collapsed;
    }
  });

  void _select(int page) {
    setState(() => _narrowExpanded = false);
    widget.onSelect(page);
  }

  Widget _sidebar(bool compact) => WorkspaceSidebar(
    selected: widget.selected,
    compact: compact,
    onToggle: _toggle,
    displayName: widget.displayName,
    roleLabel: widget.roleLabel,
    onSelect: _select,
    onSignOut: widget.onSignOut,
  );

  @override
  Widget build(BuildContext context) {
    final overlay = widget.narrow && _narrowExpanded;
    return Stack(
      children: [
        Row(
          children: [
            if (overlay)
              const SizedBox(width: 76)
            else
              _sidebar(widget.narrow || _collapsed),
            Expanded(child: widget.child),
          ],
        ),
        if (overlay) ...[
          Positioned.fill(
            child: ModalBarrier(
              color: const Color(0x14000000),
              semanticsLabel: '关闭侧栏',
              onDismiss: () => setState(() => _narrowExpanded = false),
            ),
          ),
          Positioned(left: 0, top: 0, bottom: 0, child: _sidebar(false)),
        ],
      ],
    );
  }
}
