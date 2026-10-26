import 'package:flutter/material.dart';
import 'package:pillxai_api_client/api.dart' as api;

import '../data/backend_connection.dart';
import '../data/settings_controller.dart';
import '../models/prescription_controller.dart';
import '../models/prescription_store.dart';
import '../theme/app_page.dart';
import '../theme/app_theme.dart';
import '../widgets/app_menu.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/prescription_forms.dart' show formatDate;
import '../widgets/server_plan_pattern.dart';

/// Uses server snapshots only; there is no local schedule calculation or machine action.
class PlanPreviewPage extends StatelessWidget {
  const PlanPreviewPage({
    super.key,
    required this.backend,
    required this.residents,
    required this.settings,
  });
  final BackendConnection backend;
  final PrescriptionController residents;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: residents,
    builder: (context, _) => Padding(
      padding: AppPage.insets(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (residents.loading) const LinearProgressIndicator(),
          if (residents.error != null) Text(residents.error!),
          if (residents.residents.isEmpty && !residents.loading)
            const Expanded(child: Center(child: Text('请先在处方管理添加长者与用药。')))
          else
            Expanded(
              child: Surface(
                child: ListView.separated(
                  itemCount: residents.residents.length,
                  separatorBuilder: (_, _) => const Divider(height: 32),
                  itemBuilder: (context, index) {
                    final resident = residents.residents[index];
                    return LayoutBuilder(
                      builder: (context, bounds) {
                        final identity = ResidentIdentity(
                          name: resident.name,
                          bed: resident.bed,
                          asset: resident.avatarAsset,
                        );
                        final action = OutlinedButton(
                          key: ValueKey('preview-${resident.id}'),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => ServerPlanDialog(
                              backend: backend,
                              resident: resident,
                              residents: residents,
                              settings: settings,
                            ),
                          ),
                          child: const Text('预览计划'),
                        );
                        return bounds.maxWidth < 420
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  identity,
                                  const SizedBox(height: 12),
                                  action,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: identity),
                                  action,
                                ],
                              );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class ServerPlanDialog extends StatefulWidget {
  const ServerPlanDialog({
    super.key,
    required this.backend,
    required this.resident,
    required this.residents,
    required this.settings,
  });
  final BackendConnection backend;
  final Resident resident;
  final PrescriptionController residents;
  final SettingsController settings;
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
              const Text('摆药计划', style: TextStyle(fontSize: 20)),
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
                Text(
                  preview!.message,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
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
                  OutlinedButton(
                    onPressed: loading ? null : _generate,
                    child: const Text('重新生成'),
                  ),
                  FilledButton(
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
