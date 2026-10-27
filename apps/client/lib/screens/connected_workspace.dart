import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/backend_connection.dart';
import '../data/prescription_repository.dart';
import '../models/prescription_controller.dart';
import '../models/prescription_store.dart';
import '../data/settings_controller.dart';
import '../data/terminal_controller.dart';
import '../data/terminal_host.dart';
import '../theme/app_page.dart';
import '../widgets/workspace_sidebar.dart';
import '../widgets/dispenser_icon.dart';
import '../widgets/prescription_forms.dart';
import 'login_page.dart';
import 'prescriptions_page.dart';
import 'settings_page.dart';
import 'plan_preview_page.dart';
import 'terminal_device_dialog.dart';
import 'device_mapping_dialog.dart';
import 'terminal_execution_panel.dart';
import 'task_history_dialog.dart';

class ConnectedWorkspace extends StatefulWidget {
  const ConnectedWorkspace({
    super.key,
    required this.accent,
    required this.onAccentChanged,
    this.backend,
    this.terminalHost,
  });
  final Color accent;
  final ValueChanged<Color> onAccentChanged;
  final BackendConnection? backend;
  final TerminalHost? terminalHost;
  @override
  State<ConnectedWorkspace> createState() => _ConnectedWorkspaceState();
}

class _ConnectedWorkspaceState extends State<ConnectedWorkspace>
    with WidgetsBindingObserver {
  late final backend = widget.backend ?? BackendConnection();
  PrescriptionController? controller;
  SettingsController? settings;
  TerminalController? terminal;
  static const window = MethodChannel('pillxai/window');
  int page = 1;
  bool signingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    window.setMethodCallHandler((call) async {
      if (call.method == 'requestClose') await _requestClose();
    });
  }

  Future<void> _requestClose() async {
    final current = terminal;
    if (current != null && (current.active || current.busy)) {
      setState(() => page = 1);
      if (current.task != null &&
          current.connected &&
          !current.busy &&
          ![
            'awaitingSafeConfirmation',
            'cancelled',
            'completed',
            'deleting',
            'stopping',
          ].contains(current.phase)) {
        await current.action('stop');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本机任务仍在进行。请先停止、确认现场并结束任务，完成同步后再退出。')),
      );
      return;
    }
    try {
      await current?.shutdown();
      await window.invokeMethod<void>('close');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    settings?.dispose();
    terminal?.dispose();
    window.setMethodCallHandler(null);
    if (widget.backend == null) backend.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) terminal?.refreshAfterResume();
  }

  Future<void> _login(String username, String password) async {
    await backend.login(username, password);
    if (!mounted) return;
    controller?.dispose();
    settings?.dispose();
    setState(() {
      settings = SettingsController(
        backend,
        onSaved: () =>
            controller?.updateBedtime(backend.settings!.bedtimeEnabled),
      );
      page = 1;
      terminal ??= TerminalController(
        backend,
        widget.terminalHost ?? createTerminalHost(),
      );
      controller = PrescriptionController(
        PrescriptionRepository(backend),
        bedtime: backend.settings!.bedtimeEnabled,
        canEdit:
            backend.account!.role != api.Role.staff ||
            backend.account!.canMaintain,
      );
    });
    controller!.refresh();
    terminal!.initialize();
  }

  Future<void> _logout() async {
    if (signingOut) return;
    final retainTerminal =
        terminal?.active == true &&
        terminal?.ownTask == false &&
        terminal?.connected == false;
    if ((terminal?.active == true && !retainTerminal) ||
        terminal?.busy == true) {
      setState(() => page = 1);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先结束本机任务并完成同步，再退出登录。')));
      return;
    }
    setState(() => signingOut = true);
    try {
      await backend.logout();
      if (!retainTerminal) await terminal?.shutdown();
      if (!mounted) return;
      controller?.dispose();
      settings?.dispose();
      if (!retainTerminal) terminal?.dispose();
      setState(() {
        controller = null;
        settings = null;
        if (!retainTerminal) terminal = null;
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        window.invokeMethod<void>('background');
      } else {
        _requestClose();
      }
    },
    child: _buildWorkspace(context),
  );

  Widget _buildWorkspace(BuildContext context) {
    final account = backend.account;
    if (account == null) return LoginPage(onLogin: _login);
    final roleLabel = switch (account.role) {
      api.Role.admin => '管理员',
      api.Role.staff => '工作人员',
    };
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, bounds) => Row(
            children: [
              WorkspaceSidebar(
                selected: page,
                compact: bounds.maxWidth < 600,
                displayName: account.displayName,
                roleLabel: roleLabel,
                onSelect: (value) => setState(() => page = value),
                onSignOut: _logout,
              ),
              Expanded(
                child: Column(
                  children: [
                    if (page != 2)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListenableBuilder(
                                listenable: terminal!,
                                builder: (context, _) => PageTitle(
                                  page == 1 &&
                                          terminal!.active &&
                                          ![
                                            'collecting',
                                            'closing',
                                            'completed',
                                            'cancelled',
                                          ].contains(terminal!.phase)
                                      ? '正在分药'
                                      : ['处方管理', '摆药', '设置'][page],
                                ),
                              ),
                            ),
                            if (page == 0 && controller != null)
                              IconButton(
                                tooltip: '刷新资料',
                                onPressed: controller!.refresh,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                            if (page == 1 && terminal != null) ...[
                              IconButton(
                                tooltip: '执行记录',
                                icon: const Icon(Icons.history_rounded),
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      TaskHistoryDialog(terminal: terminal!),
                                ),
                              ),
                              ListenableBuilder(
                                listenable: terminal!,
                                builder: (context, _) => OutlinedButton.icon(
                                  label: Text(
                                    terminal!.connected ? '已连接' : '未连接',
                                  ),
                                  icon: const DispenserIcon(size: 22),
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (_) => TerminalDeviceDialog(
                                      terminal: terminal!,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: page,
                        children: [
                          _prescriptions(),
                          _execution(),
                          SettingsPage(
                            model: settings!,
                            accent: widget.accent,
                            onAccentChanged: widget.onAccentChanged,
                            onConfigureMapping: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  DeviceMappingDialog(terminal: terminal!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _execution() => ListenableBuilder(
    listenable: terminal!,
    builder: (context, _) =>
        terminal!.active &&
            [
              'collecting',
              'closing',
              'completed',
              'cancelled',
              'deleting',
            ].contains(terminal!.phase)
        ? Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .45,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: TerminalExecutionPanel(terminal: terminal!),
                ),
              ),
              Expanded(
                child: PlanPreviewPage(
                  backend: backend,
                  residents: controller!,
                  settings: settings!,
                  terminal: terminal,
                ),
              ),
            ],
          )
        : terminal!.active
        ? SingleChildScrollView(
            padding: AppPage.insets(context),
            child: TerminalExecutionPanel(terminal: terminal!),
          )
        : PlanPreviewPage(
            backend: backend,
            residents: controller!,
            settings: settings!,
            terminal: terminal,
          ),
  );

  Widget _prescriptions() {
    final current = controller;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListenableBuilder(
      listenable: current,
      builder: (context, _) {
        if (current.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(current.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: current.refresh,
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            ),
          );
        }
        return Stack(
          children: [
            PrescriptionsPage(
              key: ObjectKey(current),
              model: current,
              onVersions: (resident, medicine) =>
                  _versions(current.repository, resident, medicine),
            ),
            if (current.loading)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xeef7f7f6),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _versions(
    PrescriptionRepository repository,
    Resident resident,
    Medicine medicine,
  ) async {
    final future = repository.versions(resident.id, medicine.id);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${medicine.name} · 用药版本'),
        content: SizedBox(
          width: 560,
          height: 360,
          child: FutureBuilder(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(snapshot.error.toString());
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                children: snapshot.data!.map((row) {
                  final item = medicineFromApi(row);
                  return ListTile(
                    title: Text(
                      '版本 ${row.revision} · ${item.stopped ? "已停用" : "启用"}',
                    ),
                    subtitle: Text(
                      '${item.name} · ${item.strength} · ${item.form}\n'
                      '${item.schedule} · ${item.meal}\n${formatDate(item.startDate!)} — '
                      '${item.endDate == null ? "长期" : formatDate(item.endDate!)}\n'
                      '${row.updatedAt.toLocal()}',
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}
