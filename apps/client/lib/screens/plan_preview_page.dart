import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/backend_connection.dart';
import '../data/settings_controller.dart';
import '../data/terminal_controller.dart';
import 'prepare_execution_dialog.dart';
import 'terminal_device_dialog.dart';
import '../models/prescription_controller.dart';
import '../models/prescription_store.dart';
import '../theme/app_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/prescription_forms.dart' show formatDate;
import '../widgets/server_plan_pattern.dart';

/// Queue classification is supplied by the server, including actual coverage.
class PlanPreviewPage extends StatefulWidget {
  const PlanPreviewPage({
    super.key,
    required this.backend,
    required this.residents,
    required this.settings,
    this.terminal,
  });
  final BackendConnection backend;
  final PrescriptionController residents;
  final SettingsController settings;
  final TerminalController? terminal;
  @override
  State<PlanPreviewPage> createState() => _PlanPreviewPageState();
}

class _PlanPreviewPageState extends State<PlanPreviewPage>
    with WidgetsBindingObserver {
  List<api.PreparationItem> items = [];
  bool loading = true;
  bool early = false;
  String query = '';
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.residents.addListener(reload);
    widget.settings.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.residents.removeListener(reload);
    widget.settings.removeListener(reload);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) reload();
  }

  Future<void> reload() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.backend.request(
        api.PlanningApi(widget.backend.client).listPreparation(),
      );
      if (result == null) throw const SaveFailure('待摆清单读取失败，请重试。');
      if (mounted && request == generation) setState(() => items = result);
    } catch (failure) {
      if (mounted && request == generation) {
        setState(() => error = failure.toString());
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> prepare(api.PreparationItem item) async {
    await showDialog<void>(
      context: context,
      builder: (_) => ServerPlanDialog(
        backend: widget.backend,
        resident: Resident(
          id: item.residentId,
          name: item.name,
          bed: item.bed,
          medicines: [],
        ),
        residents: widget.residents,
        settings: widget.settings,
        terminal: widget.terminal,
      ),
    );
    if (mounted) reload();
  }

  @override
  Widget build(BuildContext context) {
    final visible = items
        .where(
          (item) =>
              item.early == early &&
              ('${item.name} ${item.bed}').toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    return Padding(
      padding: AppPage.insets(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final value in [false, true])
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff232323),
                    backgroundColor: early == value
                        ? const Color(0xffefeff1)
                        : Colors.transparent,
                  ),
                  onPressed: () => setState(() => early = value),
                  child: Text(
                    '${value ? "提前准备" : "待准备"}${loading || error != null ? "" : " ${items.where((item) => item.early == value).length}"}',
                  ),
                ),
              IconButton(
                tooltip: '刷新待摆清单',
                onPressed: loading ? null : reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (value) => setState(() => query = value.trim()),
            decoration: const InputDecoration(
              hintText: '搜索姓名或床位',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 20),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(error!, textAlign: TextAlign.center),
                        TextButton(
                          onPressed: reload,
                          child: const Text('重新加载'),
                        ),
                      ],
                    ),
                  )
                : loading
                ? const SizedBox()
                : visible.isEmpty
                ? Center(
                    child: Text(
                      query.isEmpty
                          ? '暂无需要${early ? "提前" : ""}准备的长者'
                          : '没有找到匹配的长者',
                    ),
                  )
                : Surface(
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 36),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        final detail =
                            item.issue ??
                            '${item.medicineCount} 种药'
                                '${item.dates.isEmpty ? "" : " · ${formatDate(item.dates.first)} — ${formatDate(item.dates.last)}"}';
                        final identity = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ResidentIdentity(name: item.name, bed: item.bed),
                            const SizedBox(height: 12),
                            Text(
                              detail,
                              style: TextStyle(
                                fontSize: 12,
                                color: item.issue == null
                                    ? const Color(0xff777777)
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        );
                        final action = OutlinedButton(
                          key: ValueKey('preview-${item.residentId}'),
                          onPressed: widget.terminal?.active == true
                              ? null
                              : () => prepare(item),
                          child: const Text('开始摆药'),
                        );
                        return LayoutBuilder(
                          builder: (context, bounds) => bounds.maxWidth < 450
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    identity,
                                    const SizedBox(height: 16),
                                    action,
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(child: identity),
                                    const SizedBox(width: 24),
                                    action,
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ServerPlanDialog extends StatefulWidget {
  const ServerPlanDialog({
    super.key,
    required this.backend,
    required this.resident,
    required this.residents,
    required this.settings,
    this.terminal,
  });
  final BackendConnection backend;
  final Resident resident;
  final PrescriptionController residents;
  final SettingsController settings;
  final TerminalController? terminal;
  @override
  State<ServerPlanDialog> createState() => _ServerPlanDialogState();
}

class _ServerPlanDialogState extends State<ServerPlanDialog>
    with WidgetsBindingObserver {
  api.PlanPreview? preview;
  bool loading = false;
  String? error;
  int? days;
  bool? split;
  int generation = 0;
  late final planning = api.PlanningApi(widget.backend.client);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.residents.addListener(_invalidate);
    widget.settings.addListener(_invalidate);
    _generate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.residents.removeListener(_invalidate);
    widget.settings.removeListener(_invalidate);
    super.dispose();
  }

  void _invalidate() {
    if (!mounted) return;
    generation++;
    setState(() {
      loading = false;
      preview = preview?.copyWith(current: false, message: '资料或设置已变化，请重新生成。');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && preview != null && !loading) {
      _checkVersion();
    }
  }

  Future<bool> _checkVersion() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.backend.request(
        planning.getPlanPreview(preview!.snapshot.id),
      );
      if (result == null) throw const SaveFailure('计划读取失败，请重新生成。');
      if (!mounted || request != generation) return false;
      setState(() => preview = result);
      return result.current;
    } catch (failure) {
      if (mounted && request == generation) {
        setState(() {
          error = failure.toString();
          preview = preview?.copyWith(current: false);
        });
      }
      return false;
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> _generate() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      preview = null;
    });
    try {
      final result = await widget.backend.request(
        planning.createPlanPreview(
          widget.resident.id,
          api.PreviewRequest(days: days, splitMeals: split),
        ),
      );
      if (result == null) throw const SaveFailure('计划响应不完整，请重新生成。');
      if (!mounted || request != generation) return;
      setState(() {
        preview = result;
        days = result.snapshot.requestedDays;
        split = result.snapshot.splitMeals;
      });
    } catch (failure) {
      if (mounted && request == generation) {
        setState(() => error = failure.toString());
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = preview?.snapshot;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 850, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('确认摆药信息', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 12),
              Text(
                '${snapshot?.residentName ?? widget.resident.name} · ${snapshot?.bed ?? widget.resident.bed}',
              ),
              const SizedBox(height: 16),
              AbsorbPointer(
                absorbing: loading,
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: 170,
                      child: AppSelect<int>(
                        key: const ValueKey('plan-days'),
                        value: days ?? widget.backend.settings!.preparationDays,
                        label: '本次天数',
                        showLabel: true,
                        options: [
                          for (var day = 1; day <= 7; day++)
                            AppSelectOption(day, '$day 天'),
                        ],
                        onChanged: (value) {
                          days = value;
                          _generate();
                        },
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('餐食分盘'),
                        Switch(
                          value: split ?? widget.backend.settings!.splitMeals,
                          onChanged: loading
                              ? null
                              : (value) {
                                  split = value;
                                  _generate();
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (loading) const LinearProgressIndicator(),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (snapshot != null) ...[
                Text(
                  '${formatDate(snapshot.dates.first)} — ${formatDate(snapshot.dates.last)}',
                ),
                const SizedBox(height: 8),
                if (!preview!.current) Text(preview!.message),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final tray in snapshot.trays) ...[
                          Text(
                            tray.purpose,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Surface(
                            child: Column(
                              children: [
                                for (final medicine in tray.medicines)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      medicine.prescription.data.medicineName,
                                    ),
                                    subtitle: Text(
                                      '${medicine.prescription.data.strength} · '
                                      '${medicine.prescription.data.feedForm == api.FeedForm.half ? "人工预切半片" : "整片／整粒"}\n'
                                      '${medicine.totalParticles} 颗 · 原片／粒等价量 ${medicine.originalUnits}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                  if (widget.terminal?.supported == true)
                    FilledButton(
                      onPressed:
                          snapshot == null ||
                              !preview!.current ||
                              loading ||
                              widget.terminal!.active
                          ? null
                          : () async {
                              if (!await _checkVersion() || !context.mounted) {
                                return;
                              }
                              final terminal = widget.terminal!;
                              if (!terminal.connected) {
                                await showDialog<void>(
                                  context: context,
                                  builder: (_) =>
                                      TerminalDeviceDialog(terminal: terminal),
                                );
                                return;
                              }
                              setState(() => loading = true);
                              await terminal.claim(preview!.snapshot);
                              if (!context.mounted) return;
                              if (terminal.task != null) {
                                Navigator.pop(context);
                              } else {
                                setState(() {
                                  loading = false;
                                  error = terminal.error;
                                });
                              }
                            },
                      child: const Text('开仓放入药盒'),
                    ),
                  if (widget.terminal?.supported == true &&
                      widget.terminal!.canMaintain)
                    TextButton(
                      onPressed:
                          snapshot == null ||
                              loading ||
                              !preview!.current ||
                              widget.terminal!.active
                          ? null
                          : () async {
                              if (!await _checkVersion() || !context.mounted) {
                                return;
                              }
                              final claimed = await showDialog<bool>(
                                context: context,
                                builder: (_) => PrepareExecutionDialog(
                                  terminal: widget.terminal!,
                                  plan: preview!.snapshot,
                                ),
                              );
                              if (claimed == true && context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                      child: const Text('药盒与出药设置'),
                    ),
                  OutlinedButton(
                    onPressed: loading ? null : _generate,
                    child: const Text('刷新计划'),
                  ),
                  OutlinedButton(
                    onPressed: snapshot == null || !preview!.current || loading
                        ? null
                        : () async {
                            if (!await _checkVersion() || !context.mounted) {
                              return;
                            }
                            await showDialog<void>(
                              context: context,
                              builder: (_) => ServerPlanPattern(
                                snapshot: preview!.snapshot,
                              ),
                            );
                          },
                    child: const Text('预览摆药图案'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
