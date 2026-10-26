import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/backend_connection.dart';
import '../data/prescription_repository.dart';
import '../models/prescription_controller.dart';
import '../models/prescription_store.dart';
import '../models/settings_store.dart';
import '../theme/app_page.dart';
import '../widgets/workspace_sidebar.dart';
import '../widgets/prescription_forms.dart';
import 'login_page.dart';
import 'prescriptions_page.dart';
import 'settings_page.dart';

class ConnectedWorkspace extends StatefulWidget {
  const ConnectedWorkspace({
    super.key,
    required this.accent,
    required this.onAccentChanged,
    this.backend,
  });
  final Color accent;
  final ValueChanged<Color> onAccentChanged;
  final BackendConnection? backend;
  @override
  State<ConnectedWorkspace> createState() => _ConnectedWorkspaceState();
}

class _ConnectedWorkspaceState extends State<ConnectedWorkspace> {
  late final backend = widget.backend ?? BackendConnection();
  PrescriptionController? controller;
  ReadOnlySettingsStore? settings;
  int page = 0;
  bool signingOut = false;

  @override
  void dispose() {
    controller?.dispose();
    settings?.dispose();
    if (widget.backend == null) backend.dispose();
    super.dispose();
  }

  Future<void> _login(String username, String password) async {
    await backend.login(username, password);
    if (!mounted) return;
    controller?.dispose();
    settings?.dispose();
    setState(() {
      settings = ReadOnlySettingsStore(
        bedtime: backend.settings!.bedtimeEnabled,
      );
      page = 0;
      controller = PrescriptionController(
        PrescriptionRepository(backend),
        bedtime: backend.settings!.bedtimeEnabled,
        canEdit:
            backend.account!.role != api.Role.staff ||
            backend.account!.canMaintain,
      );
    });
    controller!.refresh();
  }

  Future<void> _logout() async {
    if (signingOut) return;
    setState(() => signingOut = true);
    try {
      await backend.logout();
      if (!mounted) return;
      controller?.dispose();
      settings?.dispose();
      setState(() {
        controller = null;
        settings = null;
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
  Widget build(BuildContext context) {
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
                              child: PageTitle(['处方管理', '摆药', '设置'][page]),
                            ),
                            if (page == 0 && controller != null)
                              IconButton(
                                tooltip: '刷新资料',
                                onPressed: controller!.refresh,
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: IndexedStack(
                        index: page,
                        children: [
                          _prescriptions(),
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                '摆药执行尚未接通。\n请先在处方管理维护资料。',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          SettingsPage(
                            model: settings!,
                            accent: widget.accent,
                            onAccentChanged: widget.onAccentChanged,
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
