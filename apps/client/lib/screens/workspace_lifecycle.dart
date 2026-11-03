import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

mixin WorkspaceLifecycle on WidgetsBindingObserver {
  bool _wasHidden = false;

  void onWorkspaceResumed();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _wasHidden = true;
    } else if (state == AppLifecycleState.resumed) {
      // On Android the notification shade takes focus while the app stays visible.
      if (_wasHidden ||
          kIsWeb ||
          defaultTargetPlatform != TargetPlatform.android) {
        onWorkspaceResumed();
      }
      _wasHidden = false;
    }
  }
}
