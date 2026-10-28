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
import '../widgets/preparation_confirmation.dart';
import '../widgets/app_menu.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/preparation_list.dart';
import 'task_history_dialog.dart';
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
    this.status,
  });
  final BackendConnection backend;
  final PrescriptionController residents;
  final SettingsController settings;
  final TerminalController? terminal;
  final Widget? status;
  @override
  State<PlanPreviewPage> createState() => _PlanPreviewPageState();
}

class _PlanPreviewPageState extends State<PlanPreviewPage>
    with WidgetsBindingObserver {
  List<api.PreparationItem> items = [];
  bool loading = true;
  bool early = false;
  bool history = false;
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
          avatarAsset: widget.residents.residents
              .where((r) => r.id == item.residentId)
              .firstOrNull
              ?.avatarAsset,
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
    if (history && widget.terminal != null) {
      return TaskHistoryDialog(
        terminal: widget.terminal!,
        onClose: () => setState(() => history = false),
      );
    }
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
              if (widget.terminal != null)
                TextButton.icon(
                  key: const ValueKey('open-history'),
                  onPressed: () => setState(() => history = true),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('历史记录'),
                ),
              IconButton(
                tooltip: '刷新待摆清单',
                onPressed: loading ? null : reload,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.status != null) ...[
            widget.status!,
            const SizedBox(height: 16),
          ],
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
                : PreparationList(
                    entries: [
                      for (final item in visible)
                        PreparationListEntry(
                          name: item.name,
                          bed: item.bed,
                          avatar: widget.residents.residents
                              .where((r) => r.id == item.residentId)
                              .firstOrNull
                              ?.avatarAsset,
                          hasIssue: item.issue != null,
                          details:
                              item.issue ??
                              '${early ? '可提前准备下一周期' : '待准备'}\n${item.medicineCount} 种药'
                                  '${item.dates.isEmpty ? '' : ' · ${formatDate(item.dates.first)} — ${formatDate(item.dates.last)}'}',
                          action: OutlinedButton(
                            key: ValueKey('preview-${item.residentId}'),
                            onPressed: widget.terminal?.active == true
                                ? null
                                : () => prepare(item),
                            child: const Text('开始摆药'),
                          ),
                        ),
                    ],
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
  int generation = 0;
  late final planning = api.PlanningApi(widget.backend.client);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.residents.addListener(_invalidate);
    widget.settings.addListener(_invalidate);
    widget.terminal?.addListener(_terminalChanged);
    _generate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.residents.removeListener(_invalidate);
    widget.settings.removeListener(_invalidate);
    widget.terminal?.removeListener(_terminalChanged);
    super.dispose();
  }

  bool get claimed =>
      preview != null && widget.terminal?.task?.planId == preview!.snapshot.id;

  void _terminalChanged() {
    if (mounted) setState(() {});
  }

  void _invalidate() {
    if (!mounted || claimed) return;
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
    if (claimed) return true;
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
    if (claimed) return;
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
          api.PreviewRequest(days: days),
        ),
      );
      if (result == null) throw const SaveFailure('计划响应不完整，请重新生成。');
      if (!mounted || request != generation) return;
      setState(() {
        preview = result;
        days = result.snapshot.requestedDays;
      });
    } catch (failure) {
      if (mounted && request == generation) {
        setState(() => error = failure.toString());
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> _openPattern() async {
    if (!await _checkVersion() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ServerPlanPattern(snapshot: preview!.snapshot),
    );
  }

  Future<void> _prepareBox() async {
    if (!await _checkVersion() || !mounted) return;
    final terminal = widget.terminal!;
    if (!terminal.connected) {
      await showDialog<void>(
        context: context,
        builder: (_) => TerminalDeviceDialog(terminal: terminal),
      );
      return;
    }
    setState(() => loading = true);
    await terminal.claim(preview!.snapshot);
    if (mounted) {
      setState(() {
        loading = false;
        error = terminal.error;
      });
    }
  }

  Future<void> _start() async {
    final terminal = widget.terminal!;
    await terminal.start();
    if (!mounted) return;
    if (terminal.error == null && terminal.state['permitted'] == true) {
      Navigator.pop(context);
    }
  }

  Future<void> _maintain() async {
    if (!await _checkVersion() || !mounted) return;
    await showDialog<bool>(
      context: context,
      builder: (_) => PrepareExecutionDialog(
        terminal: widget.terminal!,
        plan: preview!.snapshot,
        residentAvatar: widget.resident.avatarAsset,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = preview?.snapshot;
    final terminal = widget.terminal;
    final enabled = snapshot != null && preview!.current && !loading;
    final rows = <PreparationMedicineRow>[
      if (snapshot != null)
        for (final tray in snapshot.trays)
          for (final medicine in tray.medicines)
            PreparationMedicineRow(
              name: medicine.prescription.data.medicineName,
              description:
                  '${medicine.prescription.data.strength} · '
                  '${medicine.prescription.data.feedForm == api.FeedForm.half ? '人工预切半片' : '整片／整粒'}'
                  '${snapshot.trays.length > 1 ? ' · ${tray.purpose}' : ''}',
              doses: [
                for (final value in [
                  medicine.prescription.data.doses.morning,
                  medicine.prescription.data.doses.noon,
                  medicine.prescription.data.doses.evening,
                  if (snapshot.settings.bedtimeEnabled)
                    medicine.prescription.data.doses.night,
                ])
                  num.tryParse(value) == 0 ? '—' : value,
              ],
              total: '${medicine.totalParticles}颗',
              details:
                  '${medicine.totalParticles} 颗 · 原片／粒等价量 ${medicine.originalUnits}',
            ),
    ];
    return PreparationConfirmation(
      children: [
        const Text(
          '确认摆药信息',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        ResidentIdentity(
          asset: widget.resident.avatarAsset,
          name: snapshot?.residentName ?? widget.resident.name,
          bed: snapshot?.bed ?? widget.resident.bed,
          size: 44,
          nameSize: 18,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (snapshot != null)
              Text(
                '覆盖日期  ${formatDate(snapshot.dates.first)} — ${formatDate(snapshot.dates.last)}',
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('本次天数  '),
                SizedBox(
                  width: 94,
                  child: AppSelect<int>(
                    key: const ValueKey('plan-days'),
                    value: days ?? widget.backend.settings!.preparationDays,
                    label: '本次天数',
                    enabled: !loading && !claimed,
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
              ],
            ),
            Text(
              '餐食分盘  ${(snapshot?.splitMeals ?? widget.backend.settings!.splitMeals) ? "已开启" : "未开启"}',
            ),
          ],
        ),
        const Divider(),
        Row(
          children: [
            Expanded(child: Text('本次用药 · ${snapshot?.sources.length ?? 0} 种')),
            const SizedBox(width: 12),
            FilledButton.icon(
              key: const ValueKey('pattern-open'),
              onPressed: enabled ? _openPattern : null,
              icon: const Icon(Icons.grid_on_rounded, size: 18),
              label: const Text('预览摆药图案'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (loading) const LinearProgressIndicator(),
        if (snapshot != null)
          Flexible(
            child: PreparationMedicineTable(
              rows: rows,
              slots: [
                '早',
                '午',
                '晚',
                if (snapshot.settings.bedtimeEnabled) '睡前',
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (error != null || terminal?.error != null)
          Text(
            error ?? terminal!.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (preview != null && !preview!.current) Text(preview!.message),
        if (terminal?.supported == true)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xfff5f5f5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              claimed
                  ? terminal!.recognized
                        ? '药盒匹配，已确认 ${snapshot!.residentName}'
                        : terminal.state['message'] as String? ??
                              '请放入${widget.resident.name}的药盒'
                  : terminal!.connected
                  ? '核对后开仓，放入${widget.resident.name}的药盒'
                  : '摆药机未连接，请先连接设备',
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!claimed && (error != null || preview?.current != true))
              TextButton(
                onPressed: loading ? null : _generate,
                child: const Text('刷新计划'),
              ),
            if (terminal?.supported == true &&
                terminal!.canMaintain &&
                !claimed)
              AppActionMenu(
                tooltip: '更多准备操作',
                actions: [
                  AppMenuAction(
                    '药盒与出药设置',
                    enabled && !terminal.active ? _maintain : null,
                    icon: Icons.tune_rounded,
                  ),
                  AppMenuAction(
                    '刷新计划',
                    loading ? null : _generate,
                    icon: Icons.refresh_rounded,
                  ),
                ],
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
            if (terminal?.supported == true)
              FilledButton(
                key: const ValueKey('confirm-dispense'),
                onPressed: claimed
                    ? terminal!.phase == 'ready' &&
                              terminal.recognized &&
                              !terminal.busy &&
                              terminal.ownTask
                          ? _start
                          : null
                    : enabled && !terminal!.active && !terminal.busy
                    ? _prepareBox
                    : null,
                child: Text(claimed ? '开始摆药' : '开仓放入药盒'),
              ),
          ],
        ),
      ],
    );
  }
}
